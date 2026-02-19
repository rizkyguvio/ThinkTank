import Foundation
import NaturalLanguage

/// Elevates raw text into high-level semantic categories (Intents).
/// This allows the app to understand that "eggs + milk" = #Grocery.
nonisolated enum IntentEngine {
    
    /// Representative concepts that the app "understands" out of the box.
    /// Each concept is defined by its semantic center (DNA).
    enum Concept: String, CaseIterable {
        case groceries = "Milk, eggs, bread, grocery list, shopping, food, produce, meat, supermarket, supplies, potatoes, chicken"
        case work = "Work, project, meeting, task, professional, office, deadline, business, colleague"
        case health = "Health, fitness, exercise, medical, doctor, wellbeing, gym, workout, symptoms"
        case finance = "Finance, money, budget, banking, expense, payment, tax, investment"
        case creative = "Creative, idea, inspiration, art, writing, design, project, music"
        case home = "Home, family, chore, household, renovation, lifestyle, garden"
        case tech = "Technology, coding, software, gadgets, computer, programming, ai"
        case plans = "Plans, schedule, travel, calendar, event, meeting, appointment, trip"
        case learning = "Learning, study, research, book, course, knowledge, student"
        
        var tag: String {
            switch self {
            case .groceries: return "Grocery"
            case .work:      return "Work"
            case .health:    return "Health"
            case .finance:   return "Finance"
            case .creative:  return "Creative"
            case .home:      return "Home"
            case .tech:      return "Tech"
            case .plans:     return "Plans"
            case .learning:  return "Learning"
            }
        }
    }
    
    /// The confidence threshold for elevating a concept to a tag.
    /// Lowered to 0.70 to better catch sparse lists and specific items.
    static let elevationThreshold: Double = 0.70

    /// List of all official intent tags for mapping/obsession checks.
    static let allIntentTags: [String] = Concept.allCases.map { $0.tag }

    /// Pre-computed concept embeddings — generated once and cached for the process lifetime.
    /// Eliminates redundant NLEmbedding lookups on every single Rip It action.
    private static let conceptEmbeddings: [(tag: String, embedding: [Double])] = {
        Concept.allCases.compactMap { concept in
            guard let emb = SemanticProcessor.generateEmbedding(for: concept.rawValue) else { return nil }
            return (concept.tag, emb)
        }
    }()

    /// Analyzes an embedding to see if it closely matches any core concepts.
    /// Uses cached concept embeddings for O(1) lookup instead of regenerating them each time.
    static func detectIntents(for embedding: [Double]) -> [String] {
        conceptEmbeddings.compactMap { concept in
            let similarity = SemanticProcessor.cosineSimilarity(embedding, concept.embedding)
            return similarity >= elevationThreshold ? concept.tag : nil
        }
    }
}
