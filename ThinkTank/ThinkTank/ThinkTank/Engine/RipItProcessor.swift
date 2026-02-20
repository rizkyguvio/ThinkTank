import Combine
import Foundation
import SwiftData
import WidgetKit

/// Orchestrates the background processing pipeline triggered by every
/// "Rip It" action.
///
/// Pipeline steps (all off-main-actor):
/// 1. Extract keywords (NLTagger)
/// 2. Compute TF-IDF vector against corpus
/// 3. Assign theme tags (top-3 keywords)
/// 4. Update Theme frequency models
/// 5. Compute edges to recent ideas (bounded to 200)
/// 6. Notify main actor to refresh analytics
@MainActor
final class RipItProcessor: ObservableObject {
    static var shared: RipItProcessor!

    private let container: ModelContainer

    @Published var isProcessing: Bool = false
    @Published var lastObsessions: [ObsessionEngine.Signal] = []

    init(container: ModelContainer) {
        self.container = container
    }

    /// Process a newly captured idea.
    func process(content: String, in context: ModelContext) {
        let idea = Idea(content: content)
        
        context.insert(idea)
        do {
            try context.save()
        } catch {
            print("❌ [RipItProcessor] Failed to save initial idea to context: \(error)")
            return // Can't proceed — background task won't find this idea
        }

        isProcessing = true

        Task.detached(priority: .utility) { [weak self, container] in
            guard let self = self else { return }
            let bgContext = ModelContext(container)
            
            // Re-fetch aggregate data for current corpus state
            let meta = await self.fetchPipelineMetadata(in: bgContext)
            
            // Run pipeline for this single idea
            await self.runPipeline(for: idea.id, in: bgContext, meta: meta)
            
            await MainActor.run {
                self.isProcessing = false
                NotificationCenter.default.post(name: .graphDidUpdate, object: nil)
            }
        }
    }

    /// Full migration pass: Reprocesses every note in the library.
    /// Re-extracts keywords, regenerates embeddings, and rebuilds the graph.
    func reprocessAll() {
        isProcessing = true
        
        Task.detached(priority: .utility) { [weak self, container] in
            guard let self = self else { return }
            let bgContext = ModelContext(container)
            
            do {
                // 1. Clear established analytical data
                try bgContext.delete(model: GraphEdge.self)
                try bgContext.delete(model: Theme.self)
                try bgContext.save()
                
                // 2. Fetch all ideas
                let allIdeas = try bgContext.fetch(FetchDescriptor<Idea>(sortBy: [SortDescriptor(\.createdAt)]))
                let totalCount = allIdeas.count
                
                // 3. Pre-load metadata for the pipeline
                let meta = await self.fetchPipelineMetadata(in: bgContext)
                
                // 4. Batch re-run pipeline
                for idea in allIdeas {
                    await self.runPipeline(for: idea.id, in: bgContext, meta: meta)
                }
                
                try bgContext.save()
                WidgetCenter.shared.reloadAllTimelines()
                
                // Final obsession sweep
                let detectedObsessions = ObsessionEngine.detectObsessions(in: allIdeas)
                
                await MainActor.run {
                    self.lastObsessions = detectedObsessions
                    self.isProcessing = false
                    NotificationCenter.default.post(name: .graphDidUpdate, object: nil)
                }
            } catch {
                print("❌ [RipItProcessor] Migration failed: \(error)")
                await MainActor.run { self.isProcessing = false }
            }
        }
    }

    // MARK: - Pipeline Internals

    private struct PipelineMetadata {
        let totalIdeasCount: Int
        let themeMap: [String: Theme]
    }

    private func fetchPipelineMetadata(in context: ModelContext) async -> PipelineMetadata {
        do {
            let total = try context.fetchCount(FetchDescriptor<Idea>())
            let themes = try context.fetch(FetchDescriptor<Theme>())
            let map = Dictionary(themes.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
            return PipelineMetadata(totalIdeasCount: total, themeMap: map)
        } catch {
            return PipelineMetadata(totalIdeasCount: 0, themeMap: [:])
        }
    }

    private func runPipeline(for ideaID: UUID, in bgContext: ModelContext, meta: PipelineMetadata) async {
        let ideaDescriptor = FetchDescriptor<Idea>(predicate: #Predicate { $0.id == ideaID })
        guard let bgIdea = (try? bgContext.fetch(ideaDescriptor))?.first else { return }
        
        let content = bgIdea.content
        let preprocessedContent = SemanticProcessor.preprocess(content)
        let keywords = KeywordExtractor.extract(from: preprocessedContent)
        let embedding = SemanticProcessor.generateEmbedding(for: content)

        // Lexical Vector
        var docFrequency: [String: Int] = [:]
        for kw in keywords {
            docFrequency[kw] = meta.themeMap[kw]?.totalFrequency ?? 0
        }
        
        let lexicalVector = SimilarityEngine.tfidfVector(
            keywords: keywords,
            corpusDocumentFrequency: docFrequency,
            totalDocuments: meta.totalIdeasCount + 1
        )

        // Tags & Intents
        var rawTags = lexicalVector.sorted { $0.value > $1.value }.prefix(3).map(\.key)
        if let emb = embedding {
            let intents = IntentEngine.detectIntents(for: emb)
            for intent in intents {
                if !rawTags.contains(where: { $0.localizedCaseInsensitiveCompare(intent) == .orderedSame }) {
                    rawTags.insert(intent, at: 0)
                }
            }
        }

        var uniqueTags: [String] = []
        var seen = Set<String>()
        for t in rawTags {
            let normalized = t.localizedCapitalized
            if seen.insert(normalized).inserted { uniqueTags.append(normalized) }
        }

        // Apply metadata updates
        bgIdea.extractedKeywords = keywords
        bgIdea.encodeVector(lexicalVector)
        bgIdea.embedding = embedding
        bgIdea.themeTags = Array(uniqueTags.prefix(5))

        // Update Theme frequencies
        for tag in uniqueTags {
            if let theme = meta.themeMap[tag] {
                theme.totalFrequency += 1
                theme.weeklyFrequency += 1
            } else {
                let theme = Theme(name: tag)
                theme.totalFrequency = 1
                theme.weeklyFrequency = 1
                bgContext.insert(theme)
            }
        }

        // Compute Edges to recent cluster
        let recentDescriptor = FetchDescriptor<Idea>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let recentIdeas = (try? bgContext.fetch(recentDescriptor))?.prefix(200) ?? []

        var lexicalCandidates: [(id: UUID, vector: [String: Float])] = []
        var semanticCandidates: [(id: UUID, embedding: [Double])] = []
        
        for candidate in recentIdeas {
            if candidate.id == ideaID { continue }
            lexicalCandidates.append((candidate.id, candidate.decodedVector()))
            if let emb = candidate.embedding {
                semanticCandidates.append((candidate.id, emb))
            }
        }

        let lexicalEdges = SimilarityEngine.computeLexicalEdges(newVector: lexicalVector, candidates: lexicalCandidates)
        var semanticEdges: [(targetID: UUID, score: Float)] = []
        if let emb = embedding {
            semanticEdges = SimilarityEngine.computeSemanticEdges(newEmbedding: emb, candidates: semanticCandidates)
        }

        var edgeMap: [UUID: Float] = [:]
        for e in lexicalEdges { edgeMap[e.targetID] = e.score }
        for e in semanticEdges { edgeMap[e.targetID] = max(edgeMap[e.targetID] ?? 0, e.score) }

        for (id, score) in edgeMap {
            let graphEdge = GraphEdge(source: bgIdea, targetID: id, score: score)
            bgContext.insert(graphEdge)
        }

        // Context-Aware Notifications
        if let futureDate = DateExtractor.extractFutureDate(from: content) {
            bgIdea.hasReminder = true
            
            // Pick an emoji based on the tags we just detected
            let emoji = bgIdea.themeTags.compactMap { IntentEngine.emoji(for: $0) }.first
            
            NotificationEngine.shared.scheduleNotification(
                for: bgIdea.id,
                contentText: content,
                at: futureDate,
                emoji: emoji
            )
        }

        // Persist all pipeline changes (tags, edges, hasReminder)
        try? bgContext.save()
    }
}

// MARK: - Notification

extension Notification.Name {
    nonisolated static let graphDidUpdate = Notification.Name("ThinkTank.graphDidUpdate")
}

import UserNotifications

public final class NotificationEngine {
    public static let shared = NotificationEngine()
    
    private init() {}
    
    public func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notification auth: \(error.localizedDescription)")
            }
        }
    }
    
    public func scheduleNotification(for ideaId: UUID, contentText: String, at date: Date, emoji: String? = nil) {
        let content = UNMutableNotificationContent()
        let emojiPrefix = emoji != nil ? "\(emoji!) " : ""
        content.title = "\(emojiPrefix)A Thought Returns"
        content.body = contentText
        content.sound = .default
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: ideaId.uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("Successfully scheduled notification for idea \(ideaId) at \(date)")
            }
        }
    }
    
    public func cancelNotification(for ideaID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [ideaID.uuidString])
    }
}

public struct DateExtractor {
    /// Extracts the first future date found in the given text.
    public static func extractFutureDate(from text: String) -> Date? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return nil
        }
        
        let matches = detector.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
        let now = Date()
        
        for match in matches {
            if let date = match.date, date > now {
                // Return the first future date found
                return date
            }
        }
        
        return nil
    }
}
