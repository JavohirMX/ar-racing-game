import SwiftUI
import Combine
import simd

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
    @Published var sessionTrack: Track = .downtown
    @Published var trackScale: Float = 1.0
    @Published var placementWorldTransform: simd_float4x4?
    @Published var lastRaceResults: [RaceResult] = []

    let audioManager = AudioManager.shared
    let hapticManager = HapticManager.shared
    let multiplayerSession = MultiplayerSession()

    static let shared = AppDependencyContainer()

    private init() {}

    func goToMainMenu() {
        multiplayerSession.reset()
        placementWorldTransform = nil
        path = NavigationPath()
    }

    func applyTrackPlacement(_ result: TrackPlacementResult) {
        sessionTrack = result.calibratedTrack
        trackScale = 1.0
        placementWorldTransform = result.worldTransform
    }
}
