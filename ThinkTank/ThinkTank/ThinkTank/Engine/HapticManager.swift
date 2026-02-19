import UIKit

/// Centralized haptic feedback manager.
///
/// Refined for Hybrid Rip Interaction (Interactive & Velocity-linked).
final class HapticManager {

    static let shared = HapticManager()

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let selection = UISelectionFeedbackGenerator()

    private init() {
        prepareAll()
    }

    private func prepareAll() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        rigidImpact.prepare()
        softImpact.prepare()
        selection.prepare()
    }

    func ripItPress() {
        // Soft tactile compression
        lightImpact.impactOccurred(intensity: 0.3)
        lightImpact.prepare()
    }
    
    /// Micro-pulses during manual drag.
    /// - Parameter velocity: Normalized velocity for pulse intensity.
    func dragPulse(intensity: CGFloat) {
        softImpact.impactOccurred(intensity: intensity)
    }

    /// Master rip sequence for detachment ceremony.
    func ripItSuccess() {
        // Final Bottom Snap (Satisfaction)
        mediumImpact.impactOccurred(intensity: 1.0)
        mediumImpact.prepare()
    }
    
    func cancelRip() {
        selection.selectionChanged()
    }

    func softTap() {
        softImpact.impactOccurred(intensity: 0.4)
        softImpact.prepare()
    }

    func lightTap() {
        lightImpact.impactOccurred(intensity: 0.5)
        lightImpact.prepare()
    }
    func triggerMediumImpact() {
        mediumImpact.impactOccurred(intensity: 0.7)
        mediumImpact.prepare()
    }
}
