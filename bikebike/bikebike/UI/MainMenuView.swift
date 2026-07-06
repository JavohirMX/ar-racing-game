import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject private var container: AppDependencyContainer

    var body: some View {
        ZStack {
            ScenicBackground()
            HStack {
                Spacer()
                VStack(alignment: .trailing, spacing: 20) {
                    HStack {
                        Spacer()
                        SettingsGearButton {
                            container.path.append(AppRoute.settings)
                        }
                    }

                    Text("Bikebike")
                        .font(GameTypography.title(42))
                        .foregroundStyle(GameColors.titleWhite)
                        .gameTitleShadow()
                        .padding(.bottom, 8)

                    MenuButton(color: GameColors.soloYellow, icon: "person.fill", title: "SOLO") {
                        container.path.append(AppRoute.lapCount(.solo))
                    }

                    MenuButton(color: GameColors.multiBlue, icon: "person.3.fill", title: "MULTIPLAYER") {
                        container.path.append(AppRoute.multiplayerMenu)
                    }
                }
                .padding(.trailing, 48)
            }
        }
        .navigationBarHidden(true)
    }
}

struct MultiplayerMenuView: View {
    @EnvironmentObject private var container: AppDependencyContainer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScreenChrome(title: "Multiplayer", onBack: { dismiss() }) {
            HStack {
                Spacer()
                VStack(spacing: 20) {
                    Spacer()
                    MenuButton(color: GameColors.createOrange, icon: "plus.circle.fill", title: "CREATE GAME") {
                        container.path.append(AppRoute.lapCount(.multiplayerHost))
                    }
                    MenuButton(color: GameColors.joinBlue, icon: "qrcode", title: "JOIN GAME") {
                        container.path.append(AppRoute.letsPlay)
                    }
                    Spacer()
                }
                .padding(.trailing, 48)
            }
        }
        .navigationBarHidden(true)
    }
}

struct LapCountView: View {
    @EnvironmentObject private var container: AppDependencyContainer
    @Environment(\.dismiss) private var dismiss

    let mode: GameFlowMode
    @State private var laps: Int = 3

    private var title: String {
        switch mode {
        case .solo: "Singleplayer"
        case .multiplayerHost, .multiplayerPeer: "Lap Count"
        }
    }

    var body: some View {
        ScreenChrome(
            title: title,
            onBack: { dismiss() },
            backgroundImage: mode == .solo ? "SinglePlayerBackground" : "MultiplayerBackground"
        ) {
            HStack {
                Spacer()
                CreamPanel {
                    VStack(spacing: 28) {
                        Text("LAP COUNT")
                            .font(GameTypography.buttonLabel(16))
                            .foregroundStyle(GameColors.darkBrown)

                        LapStepper(value: $laps, range: Track.downtown.minLaps...Track.downtown.maxLaps)

                        OrangeCTAButton(title: "PLACE TRACK") {
                            container.selectedLaps = laps
                            container.path.append(AppRoute.surfaceScan(mode, laps: laps))
                        }
                    }
                    .frame(width: 280)
                }
                .padding(.trailing, 48)
            }
            .frame(maxHeight: .infinity)
        }
        .navigationBarHidden(true)
    }
}

struct LetsPlayView: View {
    @EnvironmentObject private var container: AppDependencyContainer
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""

    var body: some View {
        ZStack {
            ScenicBackground()
                .blur(radius: 6)
                .overlay(Color.black.opacity(0.35))

            VStack(spacing: 0) {
                HStack {
                    BackButton { dismiss() }
                    Spacer()
                }
                .padding(24)

                Spacer()

                VStack(spacing: 32) {
                    Text("Let's Play")
                        .font(GameTypography.title(40))
                        .foregroundStyle(GameColors.creamButton)
                        .gameTitleShadow()

                    VStack(spacing: 8) {
                        TextField("Enter your name", text: $name)
                            .multilineTextAlignment(.center)
                            .font(GameTypography.body(18))
                            .foregroundStyle(.white)
                            .textFieldStyle(.plain)

                        Rectangle()
                            .fill(GameColors.inputUnderline)
                            .frame(width: 220, height: 3)
                    }

                    Button {
                        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        container.nickname = trimmed
                        container.path.append(AppRoute.qrScanner(nickname: trimmed))
                    } label: {
                        Text("READY")
                            .font(GameTypography.buttonLabel(20))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 48)
                            .padding(.vertical, 14)
                            .background(
                                Capsule()
                                    .fill(GameColors.readyOrange)
                                    .shadow(color: .black.opacity(0.2), radius: 6, y: 4)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
                }

                Spacer()
            }
        }
        .navigationBarHidden(true)
    }
}
