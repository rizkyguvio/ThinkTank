import AudioToolbox

/// Lightweight sound manager using system sounds (no bundled audio files needed).
///
/// Falls back gracefully — if the user has sounds disabled, these are silent.
final class SoundManager {

    static let shared = SoundManager()

    private init() {}

    // MARK: - Rip It

    /// Plays a bright, positive tone for the Rip It celebration.
    ///
    /// System sound 1025 is a short, cheerful ascending tone.
    func playRipItSound() {
        AudioServicesPlaySystemSound(1025)
    }

    /// Plays a subtle tick for node taps and minor interactions.
    ///
    /// System sound 1104 is a quiet, crisp tap.
    func playTapSound() {
        AudioServicesPlaySystemSound(1104)
    }
}
