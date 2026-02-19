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
///   momentum ≥ 1.2  AND  window_recent ≥ 3  AND  totalFrequency ≥ 5
nonisolated enum EmergingSignals {

    /// A single emerging signal ready for display.
    struct Signal: Identifiable {
        let id = UUID()
        let themeName: String
        let momentum: Float
    }

    /// Detect up to 3 emerging themes.
    ///
    /// Optimized: Pre-computes tag→idea mappings in a single pass over ideas,
    /// avoiding O(themes × ideas) repeated filtering.
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
        let totalIdeas = ideas.count
        
        // Adaptive Sensitivity: Scale gates based on corpus size.
        let minFrequency: Int
        let minRecent: Int
        let momentumThreshold: Float
        
        switch totalIdeas {
        case ..<10:
            minFrequency = 1; minRecent = 1; momentumThreshold = 0.1
        case 10..<25:
            minFrequency = 2; minRecent = 1; momentumThreshold = 0.3
        case 25..<50:
            minFrequency = 3; minRecent = 2; momentumThreshold = 0.8
        default:
            minFrequency = 5; minRecent = 3; momentumThreshold = 1.2
        }

        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: now)!
        let cooldownCutoff = fourteenDaysAgo

        // Single-pass: bucket ideas by theme tag into recent/prior windows.
        // This replaces O(T × I) nested filtering with O(I × avgTags) + O(T) lookups.
        var recentByTag: [String: [Idea]] = [:]
        var priorByTag: [String: [Idea]] = [:]
        
        for idea in ideas {
            let isRecent = idea.createdAt >= sevenDaysAgo
            let isPrior = idea.createdAt >= fourteenDaysAgo && idea.createdAt < sevenDaysAgo
            
            guard isRecent || isPrior else { continue }
            
            for tag in idea.themeTags {
                if isRecent {
                    recentByTag[tag, default: []].append(idea)
                } else {
                    priorByTag[tag, default: []].append(idea)
                }
            }
        }

        var signals: [Signal] = []

        for theme in themes {
            // Noise gate: minimum corpus presence (Scaled).
            guard theme.totalFrequency >= minFrequency else { continue }

            // Cooldown: don't resurface within 14 days.
            if let lastShown = theme.lastEmergingDate, lastShown >= cooldownCutoff {
                continue
            }

            let themeRecent = recentByTag[theme.name] ?? []
            let themePrior = priorByTag[theme.name] ?? []
            
            // Skip themes with insufficient recent activity (Scaled)
            guard themeRecent.count >= minRecent else { continue }
            
            let densityRecent = GraphEngine.semanticDensity(clusterNodeIDs: themeRecent.map(\.id), ideas: themeRecent)
            let densityPrior = GraphEngine.semanticDensity(clusterNodeIDs: themePrior.map(\.id), ideas: themePrior)

            // Momentum is the growth in semantic density
            let baselineDensity = max(densityPrior, 0.1)
            let momentum = Float(densityRecent / baselineDensity)

            guard momentum >= momentumThreshold else { continue }

            signals.append(Signal(themeName: theme.name, momentum: momentum))
        }

        // Sort descending, take top 3.
        signals.sort { $0.momentum > $1.momentum }
        return Array(signals.prefix(3))
    }
    
    /// Detect themes that were dominant but are now losing activity.
    ///
    /// Optimized: Uses the same single-pass bucketing approach.
    static func detectFading(
        themes: [Theme],
        ideas: [Idea],
        now: Date = .now
    ) -> [Signal] {
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        let fourteenDaysAgo = calendar.date(byAdding: .day, value: -14, to: now)!
        
        // Single-pass bucketing
        var recentCountByTag: [String: Int] = [:]
        var priorCountByTag: [String: Int] = [:]
        
        for idea in ideas {
            let isRecent = idea.createdAt >= sevenDaysAgo
            let isPrior = idea.createdAt >= fourteenDaysAgo && idea.createdAt < sevenDaysAgo
            
            guard isRecent || isPrior else { continue }
            
            for tag in idea.themeTags {
                if isRecent {
                    recentCountByTag[tag, default: 0] += 1
                } else {
                    priorCountByTag[tag, default: 0] += 1
                }
            }
        }
        
        var fading: [Signal] = []
        for theme in themes {
            guard theme.totalFrequency >= 10 else { continue } // Only high-frequency cores
            
            let countRecent = recentCountByTag[theme.name] ?? 0
            let countPrior = priorCountByTag[theme.name] ?? 0
            
            // Fading if activity dropped by > 70% vs prior week
            if countPrior >= 4 && countRecent <= 1 {
                let dropRatio = Float(countRecent) / Float(countPrior)
                fading.append(Signal(themeName: theme.name, momentum: dropRatio))
            }
        }
        return fading.sorted(by: { $0.momentum < $1.momentum })
    }
}
