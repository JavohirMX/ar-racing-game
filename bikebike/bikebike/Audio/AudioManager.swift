import AVFoundation
import UIKit
import Combine

@MainActor
final class AudioManager: ObservableObject {
    static let shared = AudioManager()

    @Published var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled") }
    }

    @Published var musicEnabled: Bool {
        didSet { UserDefaults.standard.set(musicEnabled, forKey: "musicEnabled") }
    }

    private var players: [String: AVAudioPlayer] = [:]

    private init() {
        soundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
        musicEnabled = UserDefaults.standard.object(forKey: "musicEnabled") as? Bool ?? true
    }

    func playButtonTap() {
        playSystemSound(1104)
    }

    func playCountdownTick() {
        playSystemSound(1057)
    }

    func playGoHorn() {
        playSystemSound(1016)
    }

    func playBoost() {
        playSystemSound(1110)
    }

    func playFinish() {
        playSystemSound(1025)
    }

    private func playSystemSound(_ soundID: SystemSoundID) {
        guard soundEnabled else { return }
        AudioServicesPlaySystemSound(soundID)
    }
}
