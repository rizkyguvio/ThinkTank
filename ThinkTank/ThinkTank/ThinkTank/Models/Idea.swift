import Foundation
import SwiftData

/// Status lifecycle for a captured idea.
enum IdeaStatus: String, Codable, CaseIterable {
    case active   = "active"
    case resolved = "resolved"
    case archived = "archived"

    var label: String {
        switch self {
        case .active:   return "Active"
        case .resolved: return "Resolved"
        case .archived: return "Archived"
        }
    }

    var icon: String {
        switch self {
        case .active:   return "lightbulb.fill"
        case .resolved: return "checkmark.circle.fill"
        case .archived: return "archivebox.fill"
        }
    }
}

/// A single captured idea — the atomic unit of the Think Tank graph.
@Model
final class Idea {
    @Attribute(.unique) var id: UUID
    var content: String
    var createdAt: Date
    var extractedKeywords: [String]
    var themeTags: [String]

    /// Lifecycle status: active → resolved → archived.
    var statusRaw: String

    /// JSON-encoded `[String: Float]` — keyword → TF-IDF weight at creation time.
    var similarityVector: Data

    /// High-dimensional semantic embedding for NaturalLanguage understanding.
    var embedding: [Double]?

    @Relationship(deleteRule: .cascade, inverse: \GraphEdge.sourceIdea)
    var outgoingEdges: [GraphEdge]

    /// Computed status property.
    var status: IdeaStatus {
        get { IdeaStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    init(content: String) {
        self.id = UUID()
        self.content = content
        self.createdAt = .now
        self.extractedKeywords = []
        self.themeTags = []
        self.statusRaw = IdeaStatus.active.rawValue
        self.similarityVector = Data()
        self.embedding = nil
        self.outgoingEdges = []
    }

    // MARK: - Vector helpers

    func decodedVector() -> [String: Float] {
        guard !similarityVector.isEmpty else { return [:] }
        return (try? JSONDecoder().decode([String: Float].self, from: similarityVector)) ?? [:]
    }

    func encodeVector(_ vector: [String: Float]) {
        similarityVector = (try? JSONEncoder().encode(vector)) ?? Data()
    }
}
