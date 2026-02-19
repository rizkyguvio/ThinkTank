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

    private let container: ModelContainer

    @Published var isProcessing: Bool = false
    @Published var lastObsessions: [ObsessionEngine.Signal] = []

    init(container: ModelContainer) {
        self.container = container
    }

    /// Process a newly captured idea.
    ///
    /// The idea is inserted and saved immediately (UI remains responsive).
    /// All heavy computation runs on a background task.
    func process(content: String, in context: ModelContext) {
        let idea = Idea(content: content)
        context.insert(idea)
        try? context.save()

        isProcessing = true

        Task.detached(priority: .utility) { [container] in
            let bgContext = ModelContext(container)

            // 1. Semantic Preprocessing & Lemmatization.
            let preprocessedContent = SemanticProcessor.preprocess(content)
            let keywords = KeywordExtractor.extract(from: preprocessedContent)
            let embedding = SemanticProcessor.generateEmbedding(for: content)

            // 2. Build corpus document-frequency map using batch fetch.
            // Previously: N individual FetchDescriptor queries (one per keyword).
            // Now: Single fetch of ALL themes, then dictionary lookup.
            let totalIdeasCount = (try? bgContext.fetchCount(FetchDescriptor<Idea>())) ?? 0
            
            let allThemeDescriptor = FetchDescriptor<Theme>()
            let allThemes = (try? bgContext.fetch(allThemeDescriptor)) ?? []
            let themeMap: [String: Theme] = Dictionary(
                allThemes.map { ($0.name, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            
            var docFrequency: [String: Int] = [:]
            docFrequency.reserveCapacity(keywords.count)
            for kw in keywords {
                docFrequency[kw] = themeMap[kw]?.totalFrequency ?? 0
            }

            // 3. Compute Hybrid Vectors.
            let lexicalVector = SimilarityEngine.tfidfVector(
                keywords: keywords,
                corpusDocumentFrequency: docFrequency,
                totalDocuments: totalIdeasCount + 1
            )

            // 4. Assign theme tags (top-3 by weight) + Semantic Intents.
            var rawTags = lexicalVector
                .sorted { $0.value > $1.value }
                .prefix(3)
                .map(\.key)
            
            // "Elevate" the idea by detecting high-level conceptual intents.
            if let emb = embedding {
                let intents = IntentEngine.detectIntents(for: emb)
                for intent in intents {
                    // Case-insensitive check to avoid "grocery" + "Grocery"
                    if !rawTags.contains(where: { $0.localizedCaseInsensitiveCompare(intent) == .orderedSame }) {
                        rawTags.insert(intent, at: 0) // Prioritize intents at the start
                    }
                }
            }

            // Normalize all tags to Title Case (e.g. "milk" -> "Milk")
            var uniqueTags: [String] = []
            var seen = Set<String>()
            for t in rawTags {
                let normalized = t.localizedCapitalized
                if seen.insert(normalized).inserted {
                    uniqueTags.append(normalized)
                }
            }

            // 5. Locate the idea in the background context and update it.
            let ideaID = idea.id
            let ideaDescriptor = FetchDescriptor<Idea>(
                predicate: #Predicate { $0.id == ideaID }
            )
            guard let bgIdea = (try? bgContext.fetch(ideaDescriptor))?.first else { return }

            bgIdea.extractedKeywords = keywords
            bgIdea.encodeVector(lexicalVector)
            bgIdea.embedding = embedding
            bgIdea.themeTags = Array(uniqueTags.prefix(5)) // Cap at 5 total curated tags

            // 6. Update Theme models (batch via themeMap).
            // Previously: N individual FetchDescriptor queries.
            // Now: O(1) dictionary lookups using the already-fetched themeMap.
            for tag in uniqueTags {
                if let theme = themeMap[tag] {
                    theme.totalFrequency += 1
                    theme.weeklyFrequency += 1
                } else {
                    let theme = Theme(name: tag)
                    theme.totalFrequency = 1
                    theme.weeklyFrequency = 1
                    bgContext.insert(theme)
                }
            }

            // 7. Compute Hybrid Edges (Lexical + Semantic).
            let recentDescriptor = FetchDescriptor<Idea>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            let recentIdeas = (try? bgContext.fetch(recentDescriptor))?.prefix(200) ?? []

            // Build candidate arrays in a single pass instead of two separate compactMap iterations
            var lexicalCandidates: [(id: UUID, vector: [String: Float])] = []
            var semanticCandidates: [(id: UUID, embedding: [Double])] = []
            lexicalCandidates.reserveCapacity(recentIdeas.count)
            semanticCandidates.reserveCapacity(recentIdeas.count)
            
            for candidate in recentIdeas {
                guard candidate.id != ideaID else { continue }
                lexicalCandidates.append((candidate.id, candidate.decodedVector()))
                if let emb = candidate.embedding {
                    semanticCandidates.append((candidate.id, emb))
                }
            }

            let lexicalEdges = SimilarityEngine.computeLexicalEdges(
                newVector: lexicalVector,
                candidates: lexicalCandidates
            )

            var semanticEdges: [(targetID: UUID, score: Float)] = []
            if let emb = embedding {
                semanticEdges = SimilarityEngine.computeSemanticEdges(
                    newEmbedding: emb,
                    candidates: semanticCandidates
                )
            }

            // Combine and Dedup Edges
            var edgeMap: [UUID: Float] = [:]
            edgeMap.reserveCapacity(lexicalEdges.count + semanticEdges.count)
            for e in lexicalEdges { edgeMap[e.targetID] = e.score }
            for e in semanticEdges { edgeMap[e.targetID] = max(edgeMap[e.targetID] ?? 0, e.score) }

            for (id, score) in edgeMap {
                let graphEdge = GraphEdge(source: bgIdea, targetID: id, score: score)
                bgContext.insert(graphEdge)
            }

            try? bgContext.save()
            WidgetCenter.shared.reloadAllTimelines()

            // 8. Detect Obsessions
            let allDescriptor = FetchDescriptor<Idea>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
            let allRecent = (try? bgContext.fetch(allDescriptor)) ?? []
            let obsessions = ObsessionEngine.detectObsessions(in: allRecent)

            // 9. Notify main thread.
            await MainActor.run {
                self.lastObsessions = obsessions
                NotificationCenter.default.post(
                    name: .graphDidUpdate,
                    object: nil
                )
            }
        }

        // Reset processing flag after a short delay (processing is fast
        // for typical idea lengths; this avoids flicker).
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            isProcessing = false
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    nonisolated static let graphDidUpdate = Notification.Name("ThinkTank.graphDidUpdate")
}
