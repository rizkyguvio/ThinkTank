import UIKit

/// Centralized haptic feedback manager inspired by Duolingo's tactile design.
///
/// Pre-warms generators on init for zero-latency response.
/// All methods are safe to call from the main thread.
final class HapticManager {

    static let shared = HapticManager()

    // MARK: - Generators (pre-warmed)

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()

    private init() {
        prepareAll()
    }

    /// Pre-warm all generators so the first trigger is instant.
    private func prepareAll() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        rigidImpact.prepare()
        softImpact.prepare()
        notification.prepare()
        selection.prepare()
    }

    // MARK: - Rip It Feedback

    /// Sharp tap when the Rip It button is first pressed down.
    func ripItPress() {
        mediumImpact.impactOccurred(intensity: 0.7)
        mediumImpact.prepare()
    }

    /// Duolingo-style crescendo haptic sequence on successful rip.
    ///
    /// Pattern: light → medium → rigid → success notification
    /// Total duration: ~180ms — feels like a quick power-up ramp.
    func ripItSuccess() {
        // Beat 1: light tap
        lightImpact.impactOccurred(intensity: 0.5)
        lightImpact.prepare()

        // Beat 2: medium tap (60ms later)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [self] in
            mediumImpact.impactOccurred(intensity: 0.8)
            mediumImpact.prepare()
        }

        // Beat 3: rigid punch (120ms later)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [self] in
            rigidImpact.impactOccurred(intensity: 1.0)
            rigidImpact.prepare()
        }

        // Beat 4: success notification (180ms later) — the "ding"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [self] in
            notification.notificationOccurred(.success)
            notification.prepare()
        }
    }

    // MARK: - Subtle Interactions

    /// Gentle tap for node interactions, tab switches, etc.
    func softTap() {
        softImpact.impactOccurred(intensity: 0.4)
        softImpact.prepare()
    }

    /// Selection tick for scrolling, minor state changes.
    func selectionTick() {
        selection.selectionChanged()
        selection.prepare()
    }

    /// Light tap for sheet presentation, navigation.
    func lightTap() {
        lightImpact.impactOccurred(intensity: 0.5)
        lightImpact.prepare()
    }
}
