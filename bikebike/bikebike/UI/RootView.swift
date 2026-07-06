import SwiftUI

struct RootView: View {
    @StateObject private var container = AppDependencyContainer.shared

    var body: some View {
        NavigationStack(path: $container.path) {
            MainMenuView()
                .navigationDestination(for: AppRoute.self) { route in
                    destination(for: route)
                }
        }
        .environmentObject(container)
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .mainMenu:
            MainMenuView()
        case .settings:
            SettingsView()
        case .multiplayerMenu:
            MultiplayerMenuView()
        case .lapCount(let mode):
            LapCountView(mode: mode)
        case .surfaceScan(let mode, let laps):
            SurfaceScanView(mode: mode, laps: laps)
        case .hostLobby(let laps, let isHost):
            HostLobbyView(laps: laps, isHost: isHost)
        case .letsPlay:
            LetsPlayView()
        case .qrScanner(let nickname):
            QRScannerView(nickname: nickname)
        case .gameSession(let mode, let laps):
            GameSessionContainerView(mode: mode, laps: laps)
        case .foodDelivered(let mode, let laps):
            FoodDeliveredView(mode: mode, laps: laps)
        }
    }
}

#Preview {
    RootView()
}
