import SwiftUI
import Combine

enum GameMode {
    case solo
    case multiplayerHost
    case multiplayerPeer
}

@MainActor
final class GameSessionViewModel: ObservableObject {
    @Published var phase: GamePhase = .waiting
    @Published var countdownSeconds: Int?
    @Published var playerCount: Int = 0

    let mode: GameMode
    let track: Track
    let sessionID: UUID

    private let raceEngine: RaceEngine
    private var hostManager: HostSessionManager?
    private var peerManager: PeerSessionManager?
    private var localPlayerID: UUID?
    private var tickTimer: Timer?
    private var stateTask: Task<Void, Never>?

    init(mode: GameMode, track: Track) {
        self.mode = mode
        self.track = track
        self.sessionID = UUID()
        self.raceEngine = RaceEngine(track: track, sessionID: sessionID)
    }

    func setup() {
        switch mode {
        case .solo:
            addLocalPlayer()
        case .multiplayerHost:
            addLocalPlayer()
            setupAsHost()
        case .multiplayerPeer:
            setupAsPeer()
        }
    }

    func startRace() {
        guard phase == .waiting else { return }
        beginCountdown()
    }

    func cleanup() {
        tickTimer?.invalidate()
        stateTask?.cancel()
        Task {
            await hostManager?.stop()
            await peerManager?.disconnect()
        }
    }

    func updateInput(steer: Float, accelerate: Bool, boost: Bool) {
        guard phase == .racing, let localID = localPlayerID else { return }
        let input = PlayerInput(
            tick: 0,
            steerDirection: steer,
            accelerate: accelerate,
            boostActivated: boost
        )

        switch mode {
        case .solo:
            raceEngine.applyInput(playerID: localID, input: input)
        case .multiplayerHost:
            raceEngine.applyInput(playerID: localID, input: input)
        case .multiplayerPeer:
            Task { await peerManager?.sendInput(input) }
        }
    }

    private func addLocalPlayer() {
        let playerID = UUID()
        localPlayerID = playerID
        raceEngine.addPlayer(playerID: playerID, nickname: "Player")
        playerCount = raceEngine.playerCount
    }

    private func setupAsHost() {
        let host = HostSessionManager(nickname: "Host", maxPlayers: 6, sessionID: sessionID)
        hostManager = host

        Task {
            await host.setOnPlayerJoined { [weak self] playerID, nickname in
                guard let self else { return }
                Task { @MainActor in
                    self.raceEngine.addPlayer(playerID: playerID, nickname: nickname)
                    self.playerCount = self.raceEngine.playerCount
                }
            }

            await host.setOnPlayerLeft { [weak self] playerID in
                guard let self else { return }
                Task { @MainActor in
                    self.raceEngine.removePlayer(playerID: playerID)
                    self.playerCount = self.raceEngine.playerCount
                }
            }

            try? await host.start()
            await processHostInputs()
        }
    }

    private func processHostInputs() async {
        guard let host = hostManager else { return }
        for await (playerID, input) in await host.inputStream() {
            await MainActor.run { [weak self] in
                self?.raceEngine.applyInput(playerID: playerID, input: input)
            }
        }
    }

    private func setupAsPeer() {
        let peer = PeerSessionManager(nickname: "Player")
        peerManager = peer

        Task {
            await peer.setOnDisconnected { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.phase = .finished
                }
            }

            for await host in await peer.startBrowsing() {
                do {
                    let result = try await peer.join(host: host)
                    if result.accepted, let playerID = result.playerID {
                        self.localPlayerID = playerID
                        self.phase = .waiting
                        await processPeerState(peer)
                        break
                    }
                } catch {
                    // Retry next discovered host
                }
            }
        }
    }

    private func processPeerState(_ peer: PeerSessionManager) async {
        for await state in await peer.stateStream() {
            await MainActor.run { [weak self] in
                self?.update(from: state)
            }
        }
    }

    private func update(from state: GameState) {
        phase = state.phase
        playerCount = state.players.count

        if state.phase == .countdown {
            countdownSeconds = state.countdownSeconds
        }
        if state.phase == .finished || state.phase == .results {
            tickTimer?.invalidate()
        }
    }

    private func beginCountdown() {
        phase = .countdown
        countdownSeconds = 3

        Task { @MainActor in
            for _ in 1...3 {
                try? await Task.sleep(for: .seconds(1))
                countdownSeconds? -= 1
            }

            phase = .racing
            countdownSeconds = nil
            raceEngine.startRace()
            startTickLoop()
        }
    }

    private func startTickLoop() {
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let (state, raceFinished) = self.raceEngine.tick()

                if raceFinished {
                    self.tickTimer?.invalidate()
                }

                if self.mode == .multiplayerHost {
                    Task { await self.hostManager?.broadcast(state) }
                }
            }
        }
    }
}
