import SwiftUI
import Combine
import Network

@MainActor
final class MultiplayerSession: ObservableObject {
    @Published var lobbyPlayers: [LobbySlotPresentation] = []
    @Published var qrImage: UIImage?
    @Published var endpointInfo: QREndpointInfo?
    @Published var discoveredHosts: [DiscoveredHost] = []
    @Published var joinError: String?
    @Published var remotePhase: GamePhase = .waiting
    @Published var shouldNavigateToRace = false

    private(set) var hostManager: HostSessionManager?
    private(set) var peerManager: PeerSessionManager?
  private(set) var sessionID = UUID()
    private var hostPlayerID: UUID?
    private var browseTask: Task<Void, Never>?
    private var stateTask: Task<Void, Never>?
    private var localNickname = "Player"

    var existingHostManager: HostSessionManager? { hostManager }
    var existingPeerManager: PeerSessionManager? { peerManager }

    func reset() {
        browseTask?.cancel()
        stateTask?.cancel()
        Task {
            await hostManager?.stop()
            await peerManager?.disconnect()
        }
        hostManager = nil
        peerManager = nil
        lobbyPlayers = []
        qrImage = nil
        endpointInfo = nil
        discoveredHosts = []
        joinError = nil
        remotePhase = .waiting
        shouldNavigateToRace = false
        hostPlayerID = nil
        sessionID = UUID()
    }

    func startHosting(nickname: String, laps: Int) {
        localNickname = nickname
        reset()
        sessionID = UUID()

        let host = HostSessionManager(nickname: nickname, maxPlayers: 6, sessionID: sessionID)
        hostManager = host
        hostPlayerID = UUID()

        updateLobbySlots(hostNickname: nickname, connected: [(hostPlayerID!, nickname)])

        Task {
            await host.setOnPlayerJoined { [weak self] playerID, name in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    var connected = await host.connectedPlayers
                    if let hostID = self.hostPlayerID,
                       !connected.contains(where: { $0.0 == hostID }) {
                        connected.insert((hostID, nickname), at: 0)
                    }
                    self.updateLobbySlots(hostNickname: nickname, connected: connected)
                }
            }

            await host.setOnPlayerLeft { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    var connected = await host.connectedPlayers
                    if let hostID = self.hostPlayerID,
                       !connected.contains(where: { $0.0 == hostID }) {
                        connected.insert((hostID, nickname), at: 0)
                    }
                    self.updateLobbySlots(hostNickname: nickname, connected: connected)
                }
            }

            do {
                try await host.start()
                if let hostID = hostPlayerID {
                    await host.setLobbyHostPlayer((hostID, nickname))
                }
                try await Task.sleep(for: .milliseconds(300))
                await refreshQRCode(host: host, nickname: nickname)
            } catch {
                joinError = "Failed to start host session."
            }
        }
    }

    func startBrowsing() {
        browseTask?.cancel()
        let peer = PeerSessionManager(nickname: localNickname)
        peerManager = peer

        browseTask = Task {
            for await host in await peer.startBrowsing() {
                await MainActor.run {
                    if !discoveredHosts.contains(where: { $0.id == host.id }) {
                        discoveredHosts.append(host)
                    }
                }
            }
        }
    }

    func join(endpoint: QREndpointInfo, nickname: String) {
        localNickname = nickname
        joinError = nil
        browseTask?.cancel()

        let peer = PeerSessionManager(nickname: nickname)
        peerManager = peer

        Task {
            await peer.setOnDisconnected { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.joinError = "Disconnected from host."
                }
            }

            do {
                let result = try await peer.join(endpoint: endpoint)
                guard result.accepted else {
                    joinError = result.rejectionReason == .nameTaken ? "Name already taken." : "Lobby is full."
                    return
                }
                await listenForPeerState(peer)
            } catch {
                joinError = "Could not join game."
            }
        }
    }

    func join(host: DiscoveredHost, nickname: String) {
        localNickname = nickname
        joinError = nil
        browseTask?.cancel()

        let peer = PeerSessionManager(nickname: nickname)
        peerManager = peer

        Task {
            await peer.setOnDisconnected { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.joinError = "Disconnected from host."
                }
            }

            do {
                let result = try await peer.join(host: host)
                guard result.accepted else {
                    joinError = result.rejectionReason == .nameTaken ? "Name already taken." : "Lobby is full."
                    return
                }
                await listenForPeerState(peer)
            } catch {
                joinError = "Could not join game."
            }
        }
    }

    func broadcastLobby(laps: Int) async {
        guard let host = hostManager, let hostID = hostPlayerID else { return }
        var connected = await host.connectedPlayers
        if !connected.contains(where: { $0.0 == hostID }) {
            connected.insert((hostID, localNickname), at: 0)
        }
        await host.broadcastToLobby(players: connected, totalLaps: laps)
    }

    private func listenForPeerState(_ peer: PeerSessionManager) async {
        stateTask?.cancel()
        stateTask = Task {
            for await state in await peer.stateStream() {
                await MainActor.run {
                    self.remotePhase = state.phase
                    self.updateLobbyFromGameState(state)
                    if state.phase == .countdown || state.phase == .racing {
                        self.shouldNavigateToRace = true
                    }
                }
            }
        }
    }

    private func updateLobbyFromGameState(_ state: GameState) {
        lobbyPlayers = (0..<6).map { index in
            if index < state.players.count {
                let player = state.players[index]
                let driver = Driver(rawValue: index % Driver.allCases.count) ?? .green
                return LobbySlotPresentation(
                    id: index,
                    driver: driver,
                    nickname: player.nickname,
                    subtitle: "Ready",
                    isHost: index == 0,
                    isOccupied: true
                )
            }
            return LobbySlotPresentation(
                id: index,
                driver: Driver.allCases[index % Driver.allCases.count],
                nickname: nil,
                subtitle: "Open slot",
                isHost: false,
                isOccupied: false
            )
        }
    }

    private func updateLobbySlots(hostNickname: String, connected: [(UUID, String)]) {
        lobbyPlayers = (0..<6).map { index in
            if index < connected.count {
                let (_, name) = connected[index]
                let isYou = index == 0
                return LobbySlotPresentation(
                    id: index,
                    driver: Driver.allCases[index % Driver.allCases.count],
                    nickname: isYou ? "\(name) (You)" : name,
                    subtitle: index == 0 ? "Host" : "Ready",
                    isHost: index == 0,
                    isOccupied: true
                )
            }
            return LobbySlotPresentation(
                id: index,
                driver: Driver.allCases[index % Driver.allCases.count],
                nickname: nil,
                subtitle: "Open slot",
                isHost: false,
                isOccupied: false
            )
        }
    }

    private func refreshQRCode(host: HostSessionManager, nickname: String) async {
        guard let info = await host.endpointInfo() else { return }
        endpointInfo = info
        qrImage = QRCodeGenerator().generate(from: info)
    }
}
