import UIKit

@MainActor
final class HapticManager {
    static let shared = HapticManager()

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)

    private init() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
    }

    func buttonTap() {
        lightImpact.impactOccurred()
    }

    func countdownTick() {
        lightImpact.impactOccurred()
    }

    func raceStart() {
        heavyImpact.impactOccurred()
    }

    func boost() {
        mediumImpact.impactOccurred()
    }
}
