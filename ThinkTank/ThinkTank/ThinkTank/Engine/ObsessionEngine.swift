import Foundation
import SwiftData

/// Detects "Obsessions" — recurring semantic themes in recent thoughts.
/// This alerts the user when they are "cycling" on a specific intent.
nonisolated enum ObsessionEngine {
    
    struct Signal: Identifiable {
        let id = UUID()
        let intent: String
        let count: Int
        let ideas: [Idea]
    }
    
    /// Pre-computed lowercased intent set for O(1) membership testing.
    private static let intentTagsLower: [String: String] = {
        var map: [String: String] = [:]
        for tag in IntentEngine.allIntentTags {
            map[tag.lowercased()] = tag
        }
        return map
    }()
    
    /// Checks the last N ideas for recurring intents.
    /// Returns a list of intense signals (3+ occurrences in recent history).
    ///
    /// Optimized: Uses a lowercased dictionary for O(1) intent matching
    /// instead of iterating allIntentTags with localizedCaseInsensitiveCompare.
    static func detectObsessions(in ideas: [Idea]) -> [Signal] {
        let recent = ideas.prefix(15)
        var intentCounts: [String: [Idea]] = [:]
        
        for idea in recent {
            for tag in idea.themeTags {
                if let intent = intentTagsLower[tag.lowercased()] {
                    intentCounts[intent, default: []].append(idea)
                }
            }
        }
        
        return intentCounts.compactMap { intent, occurrences in
            occurrences.count >= 3 ? Signal(intent: intent, count: occurrences.count, ideas: occurrences) : nil
        }
        .sorted { $0.count > $1.count }
    }
}
