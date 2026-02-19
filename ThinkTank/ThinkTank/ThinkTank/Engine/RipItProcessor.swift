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
    }
}

// MARK: - Notification

extension Notification.Name {
    nonisolated static let graphDidUpdate = Notification.Name("ThinkTank.graphDidUpdate")
}
