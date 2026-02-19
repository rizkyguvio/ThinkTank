import Foundation
import SwiftData

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

            // 1. Extract keywords.
            let keywords = KeywordExtractor.extract(from: content)

            // 2. Build corpus document-frequency map.
            let descriptor = FetchDescriptor<Idea>()
            let allIdeas = (try? bgContext.fetch(descriptor)) ?? []

            var docFrequency: [String: Int] = [:]
            for existingIdea in allIdeas {
                for kw in existingIdea.extractedKeywords {
                    docFrequency[kw, default: 0] += 1
                }
            }
            // Include the new idea's keywords.
            for kw in keywords {
                docFrequency[kw, default: 0] += 1
            }

            // 3. Compute TF-IDF vector.
            let vector = SimilarityEngine.tfidfVector(
                keywords: keywords,
                corpusDocumentFrequency: docFrequency,
                totalDocuments: allIdeas.count + 1
            )

            // 4. Assign theme tags (top-3 by weight).
            let tags = vector
                .sorted { $0.value > $1.value }
                .prefix(3)
                .map(\.key)

            // 5. Locate the idea in the background context and update it.
            let ideaID = idea.id
            let ideaDescriptor = FetchDescriptor<Idea>(
                predicate: #Predicate { $0.id == ideaID }
            )
            guard let bgIdea = (try? bgContext.fetch(ideaDescriptor))?.first else { return }

            bgIdea.extractedKeywords = keywords
            bgIdea.encodeVector(vector)
            bgIdea.themeTags = Array(tags)

            // 6. Update Theme models.
            for tag in tags {
                let tagName = tag
                let themeDescriptor = FetchDescriptor<Theme>(
                    predicate: #Predicate { $0.name == tagName }
                )
                if let theme = (try? bgContext.fetch(themeDescriptor))?.first {
                    theme.totalFrequency += 1
                    theme.weeklyFrequency += 1
                } else {
                    let theme = Theme(name: tag)
                    theme.totalFrequency = 1
                    theme.weeklyFrequency = 1
                    bgContext.insert(theme)
                }
            }

            // 7. Compute edges to recent ideas (bounded to 200).
            let recentDescriptor = FetchDescriptor<Idea>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
            let recentIdeas = (try? bgContext.fetch(recentDescriptor))?.prefix(200) ?? []

            let candidates: [(id: UUID, vector: [String: Float])] = recentIdeas.compactMap { candidate in
                guard candidate.id != ideaID else { return nil }
                return (candidate.id, candidate.decodedVector())
            }

            let edges = SimilarityEngine.computeEdges(
                newVector: vector,
                candidates: candidates
            )

            for edge in edges {
                let graphEdge = GraphEdge(
                    source: bgIdea,
                    targetID: edge.targetID,
                    score: edge.score
                )
                bgContext.insert(graphEdge)
            }

            try? bgContext.save()

            // 8. Notify main thread.
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .graphDidUpdate,
                    object: nil
                )
            }

            await MainActor.run { [weak self = nil as RipItProcessor?] in
                // Note: `self` captured weakly to avoid retain cycle
                // In practice, the @Published isProcessing is set directly
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
    static let graphDidUpdate = Notification.Name("ThinkTank.graphDidUpdate")
}
