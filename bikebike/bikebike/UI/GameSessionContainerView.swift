import SwiftUI
import RealityKit

private enum VisualRacePhase {
    case countdown
    case racing
    case finished
}

struct GameSessionContainerView: View {
    @EnvironmentObject private var container: AppDependencyContainer

    let mode: GameFlowMode
    let laps: Int

    @State private var steer: Float = 0
    @State private var isAccelerating = false
    @State private var isBraking = false
    @State private var boostTapped = false
    @State private var showSettings = false

    @State private var phase: VisualRacePhase = .countdown
    @State private var countdownSeconds: Int? = 3
    @State private var didNavigateToResults = false

    var body: some View {
        ZStack {
            ARPlacementContainer(
                track: .downtown,
                isPlaneDetected: .constant(true),
                canConfirm: .constant(true),
                onEntityReady: { _ in }
            )
            .ignoresSafeArea()

            if phase == .countdown {
                VisualCountdownOverlay(countdownSeconds: countdownSeconds)
            }

            if phase == .racing {
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
        .onAppear { startVisualCountdown() }
        .onChange(of: boostTapped) { _, tapped in
            if tapped {
                HapticManager.shared.boost()
                AudioManager.shared.playBoost()
                boostTapped = false
            }
        }
    }

    private func startVisualCountdown() {
        countdownSeconds = 3
        HapticManager.shared.countdownTick()
        AudioManager.shared.playCountdownTick()

        Task { @MainActor in
            for second in stride(from: 3, through: 1, by: -1) {
                countdownSeconds = second
                try? await Task.sleep(for: .seconds(1))
                if second > 1 {
                    HapticManager.shared.countdownTick()
                    AudioManager.shared.playCountdownTick()
                }
            }

            countdownSeconds = 0
            HapticManager.shared.raceStart()
            AudioManager.shared.playGoHorn()
            try? await Task.sleep(for: .milliseconds(500))

            countdownSeconds = nil
            phase = .racing

            try? await Task.sleep(for: .seconds(5))
            guard !didNavigateToResults else { return }
            didNavigateToResults = true
            phase = .finished
            AudioManager.shared.playFinish()
            container.path.append(AppRoute.foodDelivered(mode, laps: laps))
        }
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
