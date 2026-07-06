import SwiftUI
import Combine

enum AppRoute: Hashable {
    case mainMenu
    case settings
    case multiplayerMenu
    case lapCount(GameFlowMode)
    case surfaceScan(GameFlowMode, laps: Int)
    case hostLobby(laps: Int, isHost: Bool)
    case letsPlay
    case qrScanner(nickname: String)
    case gameSession(GameFlowMode, laps: Int)
    case foodDelivered(GameFlowMode, laps: Int)
}

@MainActor
final class AppDependencyContainer: ObservableObject {
    @Published var path = NavigationPath()
    @Published var nickname = "Player"
    @Published var selectedLaps = 3

    let audioManager = AudioManager.shared
    let hapticManager = HapticManager.shared

    static let shared = AppDependencyContainer()

    private init() {}

    func goToMainMenu() {
        path = NavigationPath()
    }
}
