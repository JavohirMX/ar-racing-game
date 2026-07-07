import Foundation
import Network

actor HostSessionManager {
    nonisolated let nickname: String
    nonisolated let maxPlayers: Int
    nonisolated let sessionID: UUID

    private var listener: NWListener?
    private var pendingConnections: [UUID: PendingContext] = [:]
    private var activeConnections: [UUID: ActiveContext] = [:]
    private var inputContinuation: AsyncStream<(UUID, PlayerInput)>.Continuation?
    private var inputStreamStarted = false

    private var onPlayerJoined: (@Sendable (UUID, String) -> Void)?
    private var onPlayerLeft: (@Sendable (UUID) -> Void)?
    private var lobbyHostPlayer: (UUID, String)?

    func setOnPlayerJoined(_ handler: @escaping @Sendable (UUID, String) -> Void) { onPlayerJoined = handler }
    func setOnPlayerLeft(_ handler: @escaping @Sendable (UUID) -> Void) { onPlayerLeft = handler }
    func setLobbyHostPlayer(_ player: (UUID, String)?) { lobbyHostPlayer = player }

    private struct PendingContext {
        let connection: any NetworkConnectionProtocol
    }

    private struct ActiveContext {
        let connection: any NetworkConnectionProtocol
        let nickname: String
        let connectionID: UUID
    }

    init(nickname: String, maxPlayers: Int = 6, sessionID: UUID = UUID()) {
        self.nickname = nickname
        self.maxPlayers = maxPlayers
        self.sessionID = sessionID
    }

    func start() async throws {
        let listener = try NWListener(using: .tcp)
        listener.service = NWListener.Service(
            name: nickname,
            type: "_bikebike._tcp",
            domain: "local."
        )

        listener.stateUpdateHandler = { _ in }

        listener.newConnectionHandler = { [weak self] nwConnection in
            guard let self else { return }
            let connectionID = UUID()
            let conn = RealNetworkConnection(connection: nwConnection)

            Task { await self.registerPending(connectionID: connectionID, connection: conn) }

            conn.onStateUpdate = { @Sendable state in
                if case .failed = state {
                    Task { await self.handleDisconnect(connectionID: connectionID) }
                }
                if case .cancelled = state {
                    Task { await self.handleDisconnect(connectionID: connectionID) }
                }
            }

            conn.onReceive = { @Sendable data in
                Task { await self.handleMessage(data, connectionID: connectionID) }
            }

            conn.start(queue: .global())
        }

        listener.start(queue: .global())
        self.listener = listener
    }

    func stop() {
        for (_, ctx) in activeConnections { ctx.connection.cancel() }
        for (_, ctx) in pendingConnections { ctx.connection.cancel() }
        activeConnections.removeAll()
        pendingConnections.removeAll()
        listener?.cancel()
        listener = nil
        inputContinuation?.finish()
    }

    func broadcast(_ state: GameState) {
        guard let data = try? JSONEncoder().encode(WireMessage.gameState(state)) else { return }
        for (_, ctx) in activeConnections {
            ctx.connection.send(data: data)
        }
    }

    func broadcastToLobby(players: [(UUID, String)], totalLaps: Int = 0) {
        var allPlayers = players
        if let host = lobbyHostPlayer, !allPlayers.contains(where: { $0.0 == host.0 }) {
            allPlayers.insert(host, at: 0)
        }
        let states = allPlayers.map { (id, name) in
            PlayerState(
                playerID: id, nickname: name,
                position: .zero, rotation: 0, speed: 0,
                lap: 0, checkpointsHit: [],
                boostAvailable: true, boostActive: false,
                finished: false, finishTime: nil
            )
        }
        let lobbyState = GameState(
            sessionID: sessionID, tick: 0, phase: .waiting,
            countdownSeconds: nil, totalLaps: totalLaps,
            players: states, results: nil
        )
        broadcast(lobbyState)
    }

    func endpointInfo() -> QREndpointInfo? {
        guard let port = listener?.port?.rawValue,
              let host = LocalNetworkAddress.wifiIPv4Address() else { return nil }
        return QREndpointInfo(
            name: nickname,
            host: host,
            port: port,
            service: "_bikebike._tcp"
        )
    }

    func inputStream() -> AsyncStream<(UUID, PlayerInput)> {
        guard !inputStreamStarted else {
            fatalError("inputStream can only be called once")
        }
        inputStreamStarted = true
        return AsyncStream { continuation in
            self.inputContinuation = continuation
        }
    }

    var connectedPlayerCount: Int { activeConnections.count }

    var connectedPlayers: [(UUID, String)] {
        activeConnections.map { ($0.key, $0.value.nickname) }
    }

    private func registerPending(connectionID: UUID, connection: any NetworkConnectionProtocol) {
        pendingConnections[connectionID] = PendingContext(connection: connection)
    }

    private func handleMessage(_ data: Data, connectionID: UUID) async {
        guard let message = try? JSONDecoder().decode(WireMessage.self, from: data) else {
            if let playerID = playerID(for: connectionID) {
                removePlayer(playerID)
            } else {
                pendingConnections[connectionID]?.connection.cancel()
                pendingConnections.removeValue(forKey: connectionID)
            }
            return
        }

        if let playerID = playerID(for: connectionID) {
            if case .playerInput(let input) = message {
                inputContinuation?.yield((playerID, input))
            }
        } else if pendingConnections[connectionID] != nil {
            if case .joinRequest(let request) = message {
                await processJoinRequest(request, connectionID: connectionID)
            }
        }
    }

    private func processJoinRequest(_ request: JoinRequest, connectionID: UUID) async {
        guard let ctx = pendingConnections[connectionID] else { return }

        guard activeConnections.count < maxPlayers else {
            sendRejection(.lobbyFull, to: ctx.connection)
            ctx.connection.cancel()
            pendingConnections.removeValue(forKey: connectionID)
            return
        }

        let namesTaken = activeConnections.values.map { $0.nickname }
        guard !namesTaken.contains(request.nickname) else {
            sendRejection(.nameTaken, to: ctx.connection)
            ctx.connection.cancel()
            pendingConnections.removeValue(forKey: connectionID)
            return
        }

        let playerID = UUID()
        let driverIndex = activeConnections.count % Driver.allCases.count

        let response = JoinResponse(
            accepted: true,
            playerID: playerID,
            rejectionReason: nil,
            assignedDriverIndex: driverIndex
        )
        if let data = try? JSONEncoder().encode(WireMessage.joinResponse(response)) {
            ctx.connection.send(data: data)
        }

        pendingConnections.removeValue(forKey: connectionID)
        activeConnections[playerID] = ActiveContext(
            connection: ctx.connection,
            nickname: request.nickname,
            connectionID: connectionID
        )

        onPlayerJoined?(playerID, request.nickname)

        let players = activeConnections.map { ($0.key, $0.value.nickname) }
        broadcastToLobby(players: players)
    }

    private func sendRejection(_ reason: JoinResponse.RejectionReason, to connection: any NetworkConnectionProtocol) {
        let response = JoinResponse(
            accepted: false,
            playerID: nil,
            rejectionReason: reason,
            assignedDriverIndex: nil
        )
        if let data = try? JSONEncoder().encode(WireMessage.joinResponse(response)) {
            connection.send(data: data)
        }
    }

    private func handleDisconnect(connectionID: UUID) {
        if let playerID = playerID(for: connectionID) {
            removePlayer(playerID)
        } else {
            pendingConnections[connectionID]?.connection.cancel()
            pendingConnections.removeValue(forKey: connectionID)
        }
    }

    private func removePlayer(_ playerID: UUID) {
        guard let ctx = activeConnections[playerID] else { return }
        ctx.connection.cancel()
        activeConnections.removeValue(forKey: playerID)
        onPlayerLeft?(playerID)

        let disconnect = PlayerDisconnected(playerID: playerID)
        if let data = try? JSONEncoder().encode(WireMessage.playerDisconnected(disconnect)) {
            for (_, otherCtx) in activeConnections {
                otherCtx.connection.send(data: data)
            }
        }
    }

    private func playerID(for connectionID: UUID) -> UUID? {
        activeConnections.first(where: { $0.value.connectionID == connectionID })?.key
    }
}
