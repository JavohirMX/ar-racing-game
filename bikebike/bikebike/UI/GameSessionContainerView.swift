import SwiftUI
import RealityKit

struct GameSessionContainerView: View {
    @EnvironmentObject private var container: AppDependencyContainer
    @StateObject private var viewModel: GameSessionViewModel

    let mode: GameFlowMode
    let laps: Int

    @State private var steer: Float = 0
    @State private var isAccelerating = false
    @State private var isBraking = false
    @State private var boostTapped = false
    @State private var showSettings = false
    @State private var isARLoading = true
    @State private var didNavigateToResults = false

    init(mode: GameFlowMode, laps: Int) {
        self.mode = mode
        self.laps = laps
        let container = AppDependencyContainer.shared
        let gameMode: GameMode = switch mode {
        case .solo: .solo
        case .multiplayerHost: .multiplayerHost
        case .multiplayerPeer: .multiplayerPeer
        }
        _viewModel = StateObject(wrappedValue: GameSessionViewModel(
            mode: gameMode,
            track: container.sessionTrack,
            laps: laps,
            nickname: container.nickname,
            sessionID: container.multiplayerSession.sessionID,
            hostManager: gameMode == .multiplayerHost ? container.multiplayerSession.existingHostManager : nil,
            peerManager: gameMode == .multiplayerPeer ? container.multiplayerSession.existingPeerManager : nil
        ))
    }

    var body: some View {
        ZStack {
            ARRaceSceneContainer(
                track: container.sessionTrack,
                players: viewModel.players,
                placementWorldTransform: container.placementWorldTransform,
                isLoading: $isARLoading
            )
            .ignoresSafeArea()

            if isARLoading {
                ProgressView("Loading track...")
                    .tint(.white)
                    .foregroundStyle(.white)
            }

            if viewModel.phase == .countdown {
                VisualCountdownOverlay(countdownSeconds: viewModel.countdownSeconds)
            }

            if viewModel.phase == .racing {
                HUDView(
                    steer: $steer,
                    isAccelerating: $isAccelerating,
                    isBraking: $isBraking,
                    boostTapped: $boostTapped,
                    onSettings: { showSettings = true }
                )
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(container)
        }
        .onAppear {
            viewModel.setup()
            if mode == .solo || mode == .multiplayerHost {
                viewModel.startRace()
            }
        }
        .onDisappear {
            viewModel.cleanup()
        }
        .onChange(of: steer) { _, _ in sendInput() }
        .onChange(of: isAccelerating) { _, _ in sendInput() }
        .onChange(of: isBraking) { _, _ in sendInput() }
        .onChange(of: boostTapped) { _, tapped in
            if tapped {
                HapticManager.shared.boost()
                AudioManager.shared.playBoost()
                sendInput(boost: true)
                boostTapped = false
            }
        }
        .onChange(of: viewModel.phase) { _, phase in
            guard phase == .results, !didNavigateToResults else { return }
            didNavigateToResults = true
            AudioManager.shared.playFinish()
            let results = viewModel.results ?? []
            container.lastRaceResults = results
            container.path.append(AppRoute.foodDelivered(mode, laps: laps))
        }
    }

    private func sendInput(boost: Bool = false) {
        let accelerate = isAccelerating && !isBraking
        viewModel.updateInput(steer: steer, accelerate: accelerate, boost: boost)
    }
}

private struct VisualCountdownOverlay: View {
    let countdownSeconds: Int?

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            if let seconds = countdownSeconds {
                if seconds > 0 {
                    Text("\(seconds)")
                        .font(GameTypography.countdown())
                        .foregroundStyle(.white)
                        .gameTitleShadow()
                        .transition(.scale)
                } else {
                    Text("GO!")
                        .font(GameTypography.countdown(56))
                        .foregroundStyle(GameColors.qrGreen)
                        .gameTitleShadow()
                }
            }
        }
        .animation(.spring(response: 0.4), value: countdownSeconds)
    }
}

struct HUDView: View {
    @Binding var steer: Float
    @Binding var isAccelerating: Bool
    @Binding var isBraking: Bool
    @Binding var boostTapped: Bool
    let onSettings: () -> Void

    var body: some View {
        VStack {
            HStack {
                SettingsGearButton(action: onSettings)
                Spacer()
            }
            .padding(24)

            Spacer()

            HStack(alignment: .bottom) {
                HStack(spacing: 16) {
                    VStack(spacing: 12) {
                        HUDActionButton("BOOST", isPressed: false) {
                            boostTapped = true
                        }
                        HStack(spacing: 16) {
                            HUDActionButton("Gas", isPressed: isAccelerating, action: {
                                isAccelerating = true
                            }, onRelease: {
                                isAccelerating = false
                            })
                            HUDActionButton("", systemImage: "hand.raised.fill", isPressed: isBraking, action: {
                                isBraking = true
                            }, onRelease: {
                                isBraking = false
                            })
                        }
                    }
                }
                .padding(.leading, 24)

                Spacer()

                VirtualJoystick(steer: $steer)
                    .padding(.trailing, 24)
            }
            .padding(.bottom, 32)
        }
    }
}
