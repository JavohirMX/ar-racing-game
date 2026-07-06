import SwiftUI

struct QRScannerView: View {
    @EnvironmentObject private var container: AppDependencyContainer
    @Environment(\.dismiss) private var dismiss

    let nickname: String
    @StateObject private var scanner = QRCodeScanner()

    var body: some View {
        ZStack {
            CameraPreview(session: scanner.session)
                .ignoresSafeArea()

            VStack {
                HStack {
                    BackButton { dismiss() }
                    Spacer()
                }
                .padding(24)

                Spacer()
                QRViewfinder()
                Spacer()
            }

            if scanner.permissionDenied {
                Text("Camera access is required to scan QR codes.")
                    .font(GameTypography.body())
                    .foregroundStyle(.white)
                    .padding()
                    .background(.black.opacity(0.6))
                    .cornerRadius(12)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            container.nickname = nickname
            scanner.start()
        }
        .onDisappear { scanner.stop() }
        .onChange(of: scanner.scanCompleted) { _, completed in
            guard completed else { return }
            container.path.append(AppRoute.hostLobby(laps: container.selectedLaps, isHost: false))
        }
    }
}

struct HostLobbyView: View {
    @EnvironmentObject private var container: AppDependencyContainer
    @Environment(\.dismiss) private var dismiss

    let laps: Int
    let isHost: Bool

    private var lobbySlots: [LobbySlotPresentation] {
        LobbySlotPresentation.demo(hostNickname: container.nickname)
    }

    var body: some View {
        ScreenChrome(title: isHost ? "Host Game" : "Race Lobby", onBack: { dismiss() }) {
            HStack(alignment: .top, spacing: 24) {
                TornPaperPanel {
                    VStack(alignment: .leading, spacing: 16) {
                        if isHost {
                            VStack(spacing: 8) {
                                Text("Room QR")
                                    .font(GameTypography.body(14).weight(.bold))
                                    .foregroundStyle(GameColors.darkBrown)
                                if let qrImage = MockQRCode.image() {
                                    Image(uiImage: qrImage)
                                        .interpolation(.none)
                                        .resizable()
                                        .frame(width: 140, height: 140)
                                }
                                Text("Scan to join the game")
                                    .font(GameTypography.body(12))
                                    .foregroundStyle(GameColors.darkBrown.opacity(0.7))
                            }
                            Divider()
                        }

                        let occupied = lobbySlots.filter(\.isOccupied).count
                        Text("Players (\(occupied)/6)")
                            .font(GameTypography.body(14).weight(.bold))
                            .foregroundStyle(GameColors.darkBrown)

                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(lobbySlots) { slot in
                                    PlayerSlotRow(slot: slot)
                                }
                            }
                        }
                        .frame(maxHeight: 220)
                    }
                }
                .frame(width: 280)

                Spacer()

                VStack(alignment: .trailing, spacing: 20) {
                    Text("Laps - \(laps)")
                        .font(GameTypography.screenTitle(24))
                        .foregroundStyle(.white)
                        .gameTitleShadow()

                    TrackMapOutline()
                        .frame(width: 200, height: 140)

                    Spacer()

                    if isHost {
                        Button {
                            container.path.append(
                                AppRoute.gameSession(.multiplayerHost, laps: laps)
                            )
                        } label: {
                            Text("START RACE")
                                .font(GameTypography.buttonLabel(18))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(
                                            LinearGradient(
                                                colors: [GameColors.startRaceYellow, GameColors.primaryOrange],
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("Waiting for host to start...")
                            .font(GameTypography.body())
                            .foregroundStyle(.white)
                            .gameTitleShadow()
                    }
                }
                .padding(.trailing, 32)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
        .navigationBarHidden(true)
    }
}

private struct TrackMapOutline: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: size.width * 0.2, y: size.height * 0.5))
            path.addCurve(
                to: CGPoint(x: size.width * 0.8, y: size.height * 0.5),
                control1: CGPoint(x: size.width * 0.2, y: size.height * 0.1),
                control2: CGPoint(x: size.width * 0.8, y: size.height * 0.9)
            )
            path.addCurve(
                to: CGPoint(x: size.width * 0.2, y: size.height * 0.5),
                control1: CGPoint(x: size.width * 0.8, y: size.height * 0.1),
                control2: CGPoint(x: size.width * 0.2, y: size.height * 0.9)
            )
            context.stroke(path, with: .color(.white), lineWidth: 3)
        }
        .shadow(color: .white.opacity(0.4), radius: 8)
    }
}
