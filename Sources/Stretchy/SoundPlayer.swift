import AppKit

final class SoundPlayer {
    static let shared = SoundPlayer()

    /// Âm thanh có sẵn của macOS (/System/Library/Sounds)
    static let names = ["Glass", "Ping", "Hero", "Submarine", "Funk", "Tink",
                        "Pop", "Purr", "Bottle", "Blow", "Frog", "Morse", "Sosumi", "Basso"]

    private var current: NSSound?

    func play(name: String? = nil) {
        let s = AppSettings.shared
        guard let sound = NSSound(named: NSSound.Name(name ?? s.soundName)) else { return }
        sound.volume = Float(s.soundVolume)
        current?.stop()
        current = sound
        sound.play()
    }

    func playIfEnabled() {
        if AppSettings.shared.soundEnabled { play() }
    }

    /// Âm "thưởng" nhỏ khi người dùng bấm hoàn thành
    func playDone() {
        if AppSettings.shared.soundEnabled { play(name: "Pop") }
    }
}
