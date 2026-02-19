import AudioToolbox
import Foundation

/// Lightweight sound manager.
///
/// Refined for Hybrid Rip Interaction (Velocity-linked & Continuous).
final class SoundManager {

    static let shared = SoundManager()

    private init() {}

    /// Detailed rip sequence.
    /// - Parameters:
    ///   - isManual: Whether triggered by swipe.
    ///   - velocity: Relative velocity factor for pitch/intensity.
    func playRipSequence(isManual: Bool, velocity: Double = 1.0) {
        if !isManual {
            // Auto-rip sequence (Standard)
            AudioServicesPlaySystemSound(1104) // Press
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                AudioServicesPlaySystemSound(1105) // Tension
            }
            
            let timeline: [Double] = [0.18, 0.22, 0.26, 0.30, 0.34, 0.38]
            for delay in timeline {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    AudioServicesPlaySystemSound(1104)
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                AudioServicesPlaySystemSound(1105) // Final Snap
            }
        } else {
            // Manual pulse (Triggered by drag thresholds)
            AudioServicesPlaySystemSound(1104)
        }
    }
    
    func playSnap() {
        AudioServicesPlaySystemSound(1105)
    }
    
    func playTension() {
        AudioServicesPlaySystemSound(1104)
    }

    func playTapSound() {
        AudioServicesPlaySystemSound(1104)
    }
}
