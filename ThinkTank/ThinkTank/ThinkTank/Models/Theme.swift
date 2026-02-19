import Foundation
import SwiftData

/// Aggregate statistics for a recurring keyword/theme across all ideas.
@Model
final class Theme {
    @Attribute(.unique) var name: String
    var totalFrequency: Int
    var weeklyFrequency: Int

    /// Fraction of weeks (since first idea) in which this theme appeared.
    /// Range [0, 1]. Updated on every Rip It action.
    var persistenceScore: Float

    /// Tracks the last time this theme was shown as "emerging" to enforce
    /// the 14-day cooldown (see §3.3 in the design doc).
    var lastEmergingDate: Date?

    init(name: String) {
        self.name = name
        self.totalFrequency = 0
        self.weeklyFrequency = 0
        self.persistenceScore = 0
        self.lastEmergingDate = nil
    }
}
