import SwiftUI
import UIKit

struct SurfaceScanView: View {
    @EnvironmentObject private var container: AppDependencyContainer
    @Environment(\.dismiss) private var dismiss

    let mode: GameFlowMode
    let laps: Int

    @State private var isPlaneDetected = false
    @State private var canConfirm = false

    var body: some View {
        ZStack {
            ARPlacementContainer(
                track: .downtown,
                isPlaneDetected: $isPlaneDetected,
                canConfirm: $canConfirm,
                onEntityReady: { _ in }
            )
            .ignoresSafeArea()

            VStack {
                if !isPlaneDetected {
                    Text("Move your device slowly over a flat surface")
                        .font(GameTypography.body())
                        .foregroundStyle(.white)
                        .padding()
                        .background(.black.opacity(0.6))
                        .cornerRadius(12)
                        .padding(.top, 80)
                }

                Spacer()

                if canConfirm {
                    OrangeCTAButton(title: "CONFIRM PLACE") {
                        confirmAndContinue()
                    }
                    .padding(.horizontal, 48)
                    .padding(.bottom, 40)
                }
            }

            VStack {
                HStack {
                    BackButton { dismiss() }
                    Spacer()
                }
                .padding(24)
                Spacer()
            }
        }
        .navigationBarHidden(true)
    }

    private func confirmAndContinue() {
        switch mode {
        case .solo:
            container.path.append(AppRoute.gameSession(.solo, laps: laps))
        case .multiplayerHost:
            container.path.append(AppRoute.hostLobby(laps: laps, isHost: true))
        case .multiplayerPeer:
            break
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var container: AppDependencyContainer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScreenChrome(title: "Settings", onBack: { dismiss() }) {
            CreamPanel {
                VStack(alignment: .leading, spacing: 20) {
                    Toggle("Sound Effects", isOn: Binding(
                        get: { container.audioManager.soundEnabled },
                        set: { container.audioManager.soundEnabled = $0 }
                    ))
                    .font(GameTypography.body())
                    .foregroundStyle(GameColors.darkBrown)

                    Toggle("Music", isOn: Binding(
                        get: { container.audioManager.musicEnabled },
                        set: { container.audioManager.musicEnabled = $0 }
                    ))
                    .font(GameTypography.body())
                    .foregroundStyle(GameColors.darkBrown)
                }
                .frame(width: 300)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationBarHidden(true)
    }
}

struct FoodDeliveredView: View {
    @EnvironmentObject private var container: AppDependencyContainer

    let mode: GameFlowMode
    let laps: Int

    var body: some View {
        ZStack {
            ScenicBackground()
            VStack(spacing: 20) {
                Text("Food Delivered")
                    .font(GameTypography.title(36))
                    .foregroundStyle(.white)
                    .gameTitleShadow()
                    .padding(.top, 24)

                VStack(spacing: 0) {
                    HStack {
                        Text("#").frame(width: 40)
                        Text("Player").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Rating").frame(width: 90)
                        Text("Time").frame(width: 80, alignment: .trailing)
                    }
                    .font(GameTypography.body(13).weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(GameColors.leaderboardHeader)
                            .roundedCorners(16, corners: [.topLeft, .topRight])
                    )

                    VStack(spacing: 0) {
                        ForEach(Array(FoodDeliveredRow.sampleRows.enumerated()), id: \.element.id) { index, row in
                            LeaderboardRow(
                                rank: row.rank,
                                nickname: row.nickname,
                                stars: row.stars,
                                time: row.time
                            )
                            if index < FoodDeliveredRow.sampleRows.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(GameColors.creamPanel)
                            .roundedCorners(16, corners: [.bottomLeft, .bottomRight])
                    )
                }
                .frame(maxWidth: 520)
                .padding(.horizontal, 32)

                HStack(spacing: 24) {
                    Button {
                        container.goToMainMenu()
                    } label: {
                        Text("EXIT")
                            .font(GameTypography.buttonLabel(18))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Capsule().fill(GameColors.exitYellow))
                    }
                    .buttonStyle(.plain)

                    Button {
                        container.path.append(AppRoute.lapCount(mode))
                    } label: {
                        Text("PLAY AGAIN")
                            .font(GameTypography.buttonLabel(18))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Capsule().fill(GameColors.playAgainBlue))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 48)
                .padding(.bottom, 24)
            }
        }
        .navigationBarHidden(true)
    }
}

private extension View {
    func roundedCorners(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}

private struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: UIRectCorner

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
