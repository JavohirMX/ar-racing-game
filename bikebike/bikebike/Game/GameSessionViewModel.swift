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
    @Published var players: [PlayerState] = []
    @Published var results: [RaceResult]?
    @Published var playerCount: Int = 0

    let mode: GameMode
    let track: Track
    let laps: Int
    let sessionID: UUID
    let nickname: String

    private let raceEngine: RaceEngine
    private var hostManager: HostSessionManager?
    private var peerManager: PeerSessionManager?
    private var localPlayerID: UUID?
    private var tickTimer: Timer?
    private var stateTask: Task<Void, Never>?
    private var inputTask: Task<Void, Never>?

    init(
        mode: GameMode,
        track: Track,
        laps: Int,
        nickname: String,
        sessionID: UUID,
        hostManager: HostSessionManager? = nil,
        peerManager: PeerSessionManager? = nil,
        localPlayerID: UUID? = nil
    ) {
        self.mode = mode
        self.track = track
        self.laps = laps
        self.nickname = nickname
        self.sessionID = sessionID
        self.hostManager = hostManager
        self.peerManager = peerManager
        self.localPlayerID = localPlayerID
        self.raceEngine = RaceEngine(track: track, sessionID: sessionID, totalLaps: laps)
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
        inputTask?.cancel()
        Task {
            if mode != .multiplayerHost {
                await hostManager?.stop()
            }
            if mode != .multiplayerPeer {
                await peerManager?.disconnect()
            }
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
        case .solo, .multiplayerHost:
            raceEngine.applyInput(playerID: localID, input: input)
        case .multiplayerPeer:
            Task { await peerManager?.sendInput(input) }
        }
    }

    private func addLocalPlayer() {
        let playerID = localPlayerID ?? UUID()
        localPlayerID = playerID
        raceEngine.addPlayer(playerID: playerID, nickname: nickname)
        playerCount = raceEngine.playerCount
        players = raceEngine.currentPlayerStates()
    }

    private func setupAsHost() {
        guard let host = hostManager else { return }

        Task {
            await host.setOnPlayerJoined { [weak self] playerID, name in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.raceEngine.addPlayer(playerID: playerID, nickname: name)
                    self.playerCount = self.raceEngine.playerCount
                    self.players = self.raceEngine.currentPlayerStates()
                }
            }

            await host.setOnPlayerLeft { [weak self] playerID in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.raceEngine.removePlayer(playerID: playerID)
                    self.playerCount = self.raceEngine.playerCount
                    self.players = self.raceEngine.currentPlayerStates()
                }
            }
        }

        inputTask = Task {
            for await (playerID, input) in await host.inputStream() {
                await MainActor.run { [weak self] in
                    self?.raceEngine.applyInput(playerID: playerID, input: input)
                }
            }
        }
    }

    private func setupAsPeer() {
        guard let peer = peerManager else { return }

        stateTask = Task {
            for await state in await peer.stateStream() {
                await MainActor.run { [weak self] in
                    self?.applyRemoteState(state)
                }
            }
        }
    }

    private func applyRemoteState(_ state: GameState) {
        phase = state.phase
        players = state.players
        playerCount = state.players.count
        countdownSeconds = state.countdownSeconds
        results = state.results

        if state.phase == .finished || state.phase == .results {
            tickTimer?.invalidate()
            phase = .results
        }
    }

    private func beginCountdown() {
        phase = .countdown
        countdownSeconds = 3
        broadcastPhase()

        Task { @MainActor in
            for second in stride(from: 3, through: 1, by: -1) {
                countdownSeconds = second
                broadcastPhase()
                HapticManager.shared.countdownTick()
                AudioManager.shared.playCountdownTick()
                try? await Task.sleep(for: .seconds(1))
            }

            countdownSeconds = 0
            broadcastPhase()
            HapticManager.shared.raceStart()
            AudioManager.shared.playGoHorn()
            try? await Task.sleep(for: .milliseconds(500))

            countdownSeconds = nil
            phase = .racing
            raceEngine.startRace()
            players = raceEngine.currentPlayerStates()
            broadcastPhase()
            startTickLoop()
        }
    }

    private func broadcastPhase() {
        guard mode == .multiplayerHost, let host = hostManager else { return }
        let state = GameState(
            sessionID: sessionID,
            tick: 0,
            phase: phase,
            countdownSeconds: countdownSeconds,
            totalLaps: laps,
            players: raceEngine.currentPlayerStates(),
            results: nil
        )
        Task { await host.broadcast(state) }
    }

    private func startTickLoop() {
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let (state, raceFinished) = self.raceEngine.tick()
                self.players = state.players

                if self.mode == .multiplayerHost {
                    Task { await self.hostManager?.broadcast(state) }
                }

                if raceFinished {
                    self.tickTimer?.invalidate()
                    self.phase = .results
                    self.results = state.results
                }
            }
        }
    }
}
