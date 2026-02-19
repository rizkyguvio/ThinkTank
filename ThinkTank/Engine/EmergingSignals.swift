import Foundation
import SwiftData

/// Detects themes with rising momentum over a sliding time window.
///
/// Momentum formula (from design §3):
/// ```
/// window_recent  = ideas tagged T in last 7 days
/// window_prior   = ideas tagged T in days 8–14
/// baseline       = total ideas tagged T / (total_weeks)
/// momentum(T)    = (window_recent − window_prior) / max(baseline, 1)
/// ```
///
/// A theme qualifies as "emerging" when:
///   momentum ≥ 1.5  AND  window_recent ≥ 3  AND  totalFrequency ≥ 5
enum EmergingSignals {

    /// A single emerging signal ready for display.
    struct Signal: Identifiable {
        let id = UUID()
        let themeName: String
        let momentum: Float
    }

    /// Detect up to 3 emerging themes.
    ///
    /// - Parameters:
    ///   - themes: All persisted `Theme` objects.
    ///   - ideas: All persisted `Idea` objects (used for windowed counting).
    ///   - now: Current date (injectable for testing).
    /// - Returns: Between 0 and 3 `Signal` values, sorted by momentum descending.
    static func detect(
        themes: [Theme],
        ideas: [Idea],
        now: Date = .now
    ) -> [Signal] {
        let calendar = Calendar.current

        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: now)!
        let cooldownCutoff = calendar.date(byAdding: .day, value: -14, to: now)!

        // Pre-compute idea date ranges.
        let recentIdeas = ideas.filter { $0.createdAt >= sevenDaysAgo }
        let priorIdeas = ideas.filter { $0.createdAt >= fourteenDaysAgo && $0.createdAt < sevenDaysAgo }

        // Total weeks since the earliest idea.
        let earliestDate = ideas.map(\.createdAt).min() ?? now
        let totalWeeks = max(
            Float(calendar.dateComponents([.weekOfYear], from: earliestDate, to: now).weekOfYear ?? 1),
            1
        )

        var signals: [Signal] = []

        for theme in themes {
            // Noise gate: minimum corpus presence.
            guard theme.totalFrequency >= 5 else { continue }

            // Cooldown: don't resurface within 14 days.
            if let lastShown = theme.lastEmergingDate, lastShown >= cooldownCutoff {
                continue
            }

            let windowRecent = Float(recentIdeas.filter { $0.themeTags.contains(theme.name) }.count)
            var windowPrior = Float(priorIdeas.filter { $0.themeTags.contains(theme.name) }.count)

            // Laplace smoothing to avoid division artifacts.
            if windowPrior == 0 { windowPrior = 0.5 }

            let baseline = max(Float(theme.totalFrequency) / totalWeeks, 1)
            let momentum = (windowRecent - windowPrior) / baseline

            // Threshold check.
            guard momentum >= 1.5, windowRecent >= 3 else { continue }

            signals.append(Signal(themeName: theme.name, momentum: momentum))
        }

        // Sort descending, take top 3.
        signals.sort { $0.momentum > $1.momentum }
        return Array(signals.prefix(3))
    }
}
