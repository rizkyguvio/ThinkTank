import Foundation
import SwiftData

/// A weighted, undirected edge between two ideas in the idea web.
///
/// Only one `GraphEdge` is stored per pair (source → target). The graph engine
/// treats edges as undirected when building adjacency lists.
@Model
final class GraphEdge {
    var id: UUID
    var sourceIdea: Idea?
    var targetIdeaID: UUID
    var similarityScore: Float

    init(source: Idea, targetID: UUID, score: Float) {
        self.id = UUID()
        self.sourceIdea = source
        self.targetIdeaID = targetID
        self.similarityScore = score
    }
}
