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

                if !container.multiplayerSession.discoveredHosts.isEmpty {
                    hostListPanel
                        .padding(.horizontal, 24)
                }

                Spacer()
                QRViewfinder()
                Text("Scan host QR code or pick a nearby game")
                    .font(GameTypography.body(14))
                    .foregroundStyle(.white)
                    .gameTitleShadow()
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

            if let error = container.multiplayerSession.joinError {
                Text(error)
                    .font(GameTypography.body(14))
                    .foregroundStyle(.white)
                    .padding()
                    .background(.black.opacity(0.7))
                    .cornerRadius(12)
                    .padding()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            container.nickname = nickname
            scanner.start()
            container.multiplayerSession.startBrowsing()
        }
        .onDisappear {
            scanner.stop()
        }
        .onChange(of: scanner.scannedEndpoint) { _, endpoint in
            guard let endpoint else { return }
            container.multiplayerSession.join(endpoint: endpoint, nickname: nickname)
            container.path.append(AppRoute.hostLobby(laps: container.selectedLaps, isHost: false))
        }
    }

    private var hostListPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nearby Games")
                .font(GameTypography.body(14).weight(.bold))
                .foregroundStyle(.white)

            ForEach(container.multiplayerSession.discoveredHosts) { host in
                Button {
                    container.multiplayerSession.join(host: host, nickname: nickname)
                    container.path.append(AppRoute.hostLobby(laps: container.selectedLaps, isHost: false))
                } label: {
                    HStack {
                        Text(host.name)
                            .font(GameTypography.body(14))
                        Spacer()
                        Text("Join")
                            .font(GameTypography.body(13).weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.5)))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct HostLobbyView: View {
    @EnvironmentObject private var container: AppDependencyContainer
    @Environment(\.dismiss) private var dismiss

    let laps: Int
    let isHost: Bool

    private var lobbySlots: [LobbySlotPresentation] {
        container.multiplayerSession.lobbyPlayers.isEmpty
            ? LobbySlotPresentation.demo(hostNickname: container.nickname)
            : container.multiplayerSession.lobbyPlayers
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
                                if let qrImage = container.multiplayerSession.qrImage {
                                    Image(uiImage: qrImage)
                                        .interpolation(.none)
                                        .resizable()
                                        .frame(width: 140, height: 140)
                                } else {
                                    ProgressView()
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
                            Task {
                                await container.multiplayerSession.broadcastLobby(laps: laps)
                            }
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
        .onAppear {
            if isHost, container.multiplayerSession.existingHostManager == nil {
                container.multiplayerSession.startHosting(nickname: container.nickname, laps: laps)
            }
        }
        .onChange(of: container.multiplayerSession.shouldNavigateToRace) { _, shouldNavigate in
            guard !isHost, shouldNavigate else { return }
            container.path.append(AppRoute.gameSession(.multiplayerPeer, laps: laps))
        }
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
