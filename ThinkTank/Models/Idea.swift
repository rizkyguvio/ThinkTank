import Foundation
import SwiftData

/// A single captured idea — the atomic unit of the Think Tank graph.
@Model
final class Idea {
    @Attribute(.unique) var id: UUID
    var content: String
    var createdAt: Date
    var extractedKeywords: [String]
    var themeTags: [String]

    /// JSON-encoded `[String: Float]` — keyword → TF-IDF weight at creation time.
    /// Stored as raw `Data` because SwiftData does not natively persist dictionaries.
    var similarityVector: Data

    @Relationship(deleteRule: .cascade, inverse: \GraphEdge.sourceIdea)
    var outgoingEdges: [GraphEdge]

    init(content: String) {
        self.id = UUID()
        self.content = content
        self.createdAt = .now
        self.extractedKeywords = []
        self.themeTags = []
        self.similarityVector = Data()
        self.outgoingEdges = []
    }

    // MARK: - Vector helpers

    /// Decode the stored similarity vector into a usable dictionary.
    func decodedVector() -> [String: Float] {
        guard !similarityVector.isEmpty else { return [:] }
        return (try? JSONDecoder().decode([String: Float].self, from: similarityVector)) ?? [:]
    }

    /// Encode a keyword-weight dictionary and store it.
    func encodeVector(_ vector: [String: Float]) {
        similarityVector = (try? JSONEncoder().encode(vector)) ?? Data()
    }
}
