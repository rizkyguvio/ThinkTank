import UIKit

/// Centralized haptic feedback manager.
///
/// Refined for Hybrid Rip Interaction (Interactive & Velocity-linked).
final class HapticManager {

    static let shared = HapticManager()

    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private let softGenerator = UIImpactFeedbackGenerator(style: .soft)
    private let selectionGenerator = UISelectionFeedbackGenerator()

    private init() {
        prepareAll()
    }

    private func prepareAll() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        heavyGenerator.prepare()
        rigidGenerator.prepare()
        softGenerator.prepare()
        selectionGenerator.prepare()
    }

    func ripItPress() {
        // Soft tactile compression
        lightGenerator.impactOccurred(intensity: 0.3)
        lightGenerator.prepare()
    }
    
    /// Micro-pulses during manual drag.
    /// - Parameter velocity: Normalized velocity for pulse intensity.
    func dragPulse(intensity: CGFloat) {
        softGenerator.impactOccurred(intensity: intensity)
    }

    /// Master rip sequence for detachment ceremony.
    func ripItSuccess() {
        // Final Bottom Snap (Satisfaction)
        mediumGenerator.impactOccurred(intensity: 1.0)
        mediumGenerator.prepare()
    }
    
    func cancelRip() {
        selectionGenerator.selectionChanged()
    }

    func softTap() {
        softGenerator.impactOccurred(intensity: 0.4)
        softGenerator.prepare()
    }

    func lightTap() {
        lightGenerator.impactOccurred(intensity: 0.5)
        lightGenerator.prepare()
    }
    func triggerMediumImpact() {
        mediumGenerator.impactOccurred(intensity: 0.7)
        mediumGenerator.prepare()
    }

    func heavyImpact() {
        heavyGenerator.impactOccurred(intensity: 1.0)
        heavyGenerator.prepare()
    }

    func selectionTick() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    // MARK: - New additions

    /// Double-knock warning for obsession detection
    func warningPulse() {
        rigidGenerator.impactOccurred(intensity: 0.9)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [self] in
            rigidGenerator.impactOccurred(intensity: 0.5)
            rigidGenerator.prepare()
        }
    }

    /// Single heavy thud when drag crosses commit threshold
    func lockIn() {
        heavyGenerator.impactOccurred(intensity: 1.0)
        heavyGenerator.prepare()
    }

    /// Snap-on feel for adding a tag
    func tagAdded() {
        selectionGenerator.selectionChanged()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [self] in
            softGenerator.impactOccurred(intensity: 0.3)
            softGenerator.prepare()
        }
    }

    /// Clean snap-off for removing a tag
    func tagRemoved() {
        rigidGenerator.impactOccurred(intensity: 0.4)
        rigidGenerator.prepare()
    }

    /// Snap-off for filter pill dismissal
    func snapOff() {
        rigidGenerator.impactOccurred(intensity: 0.35)
        rigidGenerator.prepare()
    }

    /// Thud + settle for archiving
    func archivePulse() {
        mediumGenerator.impactOccurred(intensity: 0.6)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [self] in
            softGenerator.impactOccurred(intensity: 0.3)
            softGenerator.prepare()
        }
    }

    /// Slow-build reveal for Brain Synthesis panel
    func synthesisReveal() {
        softGenerator.impactOccurred(intensity: 0.3)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [self] in
            softGenerator.impactOccurred(intensity: 0.5)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) { [self] in
            mediumGenerator.impactOccurred(intensity: 0.8)
            mediumGenerator.prepare()
        }
    }
}
