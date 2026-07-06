import Foundation

@MainActor
final class RaceEngine {
    let track: Track
    let totalLaps: Int
    let sessionID: UUID

    private var playerMeta: [UUID: PlayerMeta] = [:]
    private var positions: [UUID: SIMD3<Float>] = [:]
    private var rotations: [UUID: Float] = [:]
    private var velocities: [UUID: SIMD3<Float>] = [:]
    private var angularVelocities: [UUID: Float] = [:]
    private var bikeInputs: [UUID: BikeInputComponent] = [:]
    private var bikeStates: [UUID: BikeStateComponent] = [:]
    private var bikeBoosts: [UUID: BoostComponent] = [:]

    private var tickNumber: UInt32 = 0
    private var raceStartTime: Date?
    private var isRunning = false

    private struct PlayerMeta {
        let nickname: String
        var finishTime: TimeInterval?
    }

    init(track: Track, sessionID: UUID) {
        self.track = track
        self.totalLaps = track.defaultLaps
        self.sessionID = sessionID
    }

    var playerCount: Int { playerMeta.count }

    func addPlayer(playerID: UUID, nickname: String) {
        playerMeta[playerID] = PlayerMeta(nickname: nickname)
        positions[playerID] = track.startPosition
        rotations[playerID] = track.startRotation
        velocities[playerID] = .zero
        angularVelocities[playerID] = 0
        bikeInputs[playerID] = BikeInputComponent()
        bikeStates[playerID] = BikeStateComponent(playerID: playerID, nickname: nickname)
        bikeBoosts[playerID] = BoostComponent()
    }

    func removePlayer(playerID: UUID) {
        playerMeta.removeValue(forKey: playerID)
        positions.removeValue(forKey: playerID)
        rotations.removeValue(forKey: playerID)
        velocities.removeValue(forKey: playerID)
        angularVelocities.removeValue(forKey: playerID)
        bikeInputs.removeValue(forKey: playerID)
        bikeStates.removeValue(forKey: playerID)
        bikeBoosts.removeValue(forKey: playerID)
    }

    func startRace() {
        isRunning = true
        tickNumber = 0
        raceStartTime = Date()

        for playerID in playerMeta.keys {
            positions[playerID] = track.startPosition
            rotations[playerID] = track.startRotation
            velocities[playerID] = .zero
            angularVelocities[playerID] = 0

            bikeInputs[playerID] = BikeInputComponent()

            var state = bikeStates[playerID] ?? BikeStateComponent(playerID: playerID, nickname: "")
            state.currentLap = 0
            state.checkpointsHit = []
            state.hasFinished = false
            state.finishTime = nil
            bikeStates[playerID] = state

            bikeBoosts[playerID] = BoostComponent()
        }
    }

    func applyInput(playerID: UUID, input: PlayerInput) {
        guard var comp = bikeInputs[playerID] else { return }
        comp.steerDirection = input.steerDirection
        comp.isAccelerating = input.accelerate
        if input.boostActivated {
            comp.boostRequested = true
        }
        bikeInputs[playerID] = comp
    }

    func tick() -> (state: GameState, raceFinished: Bool) {
        tickNumber += 1
        let dt: Float = 1.0 / 30.0

        processMovement(dt: dt)
        processBoost(dt: dt)
        processCheckpoints()

        let playerStates = buildPlayerStates()
        let allFinished = !playerStates.isEmpty && playerStates.allSatisfy { $0.finished }
        let raceFinished = allFinished

        let results = raceFinished ? buildResults(from: playerStates) : nil

        let state = GameState(
            sessionID: sessionID,
            tick: tickNumber,
            phase: raceFinished ? .finished : .racing,
            countdownSeconds: nil,
            totalLaps: totalLaps,
            players: Array(playerStates),
            results: results
        )

        return (state, raceFinished)
    }

    func stop() {
        isRunning = false
    }

    // MARK: - Physics

    private func processMovement(dt: Float) {
        for playerID in playerMeta.keys {
            guard let input = bikeInputs[playerID] else { continue }
            guard var velocity = velocities[playerID] else { continue }
            guard var position = positions[playerID] else { continue }
            guard var rotation = rotations[playerID] else { continue }
            guard var angularVel = angularVelocities[playerID] else { continue }

            let boost = bikeBoosts[playerID]
            let isBoosted = boost?.isActive ?? false

            if input.isAccelerating {
                let angle = rotation
                let forward = SIMD3<Float>(-sin(angle), 0, -cos(angle))
                velocity += forward * 15.0 * dt
            }

            let maxSpeed: Float = isBoosted ? 7.5 : 5.0
            let speed = sqrt(velocity.x * velocity.x + velocity.y * velocity.y + velocity.z * velocity.z)
            if speed > maxSpeed {
                velocity = (velocity / speed) * maxSpeed
            }

            velocity *= (1.0 - 0.3 * dt)
            position += velocity * dt

            if input.steerDirection != 0 {
                let turnRate: Float = 120.0 * (.pi / 180.0)
                angularVel = input.steerDirection * turnRate * dt
            } else {
                angularVel *= (1.0 - 0.95 * dt)
            }
            rotation += angularVel

            velocities[playerID] = velocity
            positions[playerID] = position
            rotations[playerID] = rotation
            angularVelocities[playerID] = angularVel
        }
    }

    private func processBoost(dt: Float) {
        let frameDt = TimeInterval(dt)

        for playerID in playerMeta.keys {
            guard var input = bikeInputs[playerID],
                  var boost = bikeBoosts[playerID] else { continue }

            if input.boostRequested, !boost.isActive, boost.cooldownRemaining <= 0 {
                boost.isActive = true
                boost.boostTimeRemaining = boost.boostDuration
                boost.cooldownRemaining = 0
                input.boostRequested = false
            }

            if boost.isActive {
                boost.boostTimeRemaining -= frameDt
                if boost.boostTimeRemaining <= 0 {
                    boost.isActive = false
                    boost.cooldownRemaining = boost.cooldownDuration
                }
            }

            if boost.cooldownRemaining > 0, !boost.isActive {
                boost.cooldownRemaining = max(0, boost.cooldownRemaining - frameDt)
            }

            input.boostRequested = boost.isActive

            bikeInputs[playerID] = input
            bikeBoosts[playerID] = boost
        }
    }

    private func processCheckpoints() {
        for playerID in playerMeta.keys {
            guard var state = bikeStates[playerID] else { continue }
            guard !state.hasFinished else { continue }
            guard let pos = positions[playerID] else { continue }

            for (index, cp) in track.checkpoints.enumerated() {
                let distance = sqrt(
                    (pos.x - cp.position.x) * (pos.x - cp.position.x) +
                    (pos.y - cp.position.y) * (pos.y - cp.position.y) +
                    (pos.z - cp.position.z) * (pos.z - cp.position.z)
                )
                guard distance <= cp.radius else { continue }
                guard !state.checkpointsHit.contains(index) else { continue }

                let expectedNext = state.checkpointsHit.count
                guard index == expectedNext else { continue }

                state.checkpointsHit.append(index)

                if state.checkpointsHit.count == track.checkpoints.count {
                    state.currentLap += 1
                    state.checkpointsHit = []

                    if state.currentLap >= totalLaps {
                        state.hasFinished = true
                    }
                }
            }

            bikeStates[playerID] = state
        }
    }

    // MARK: - State building

    private func buildPlayerStates() -> [PlayerState] {
        var result: [PlayerState] = []
        for (id, meta) in playerMeta {
            guard let state = bikeStates[id] else { continue }

            let boost = bikeBoosts[id]
            let vel = velocities[id] ?? .zero
            let speed = sqrt(vel.x * vel.x + vel.y * vel.y + vel.z * vel.z)

            if state.hasFinished, meta.finishTime == nil, let start = raceStartTime {
                playerMeta[id]?.finishTime = Date().timeIntervalSince(start)
            }

            result.append(PlayerState(
                playerID: id,
                nickname: meta.nickname,
                position: positions[id] ?? .zero,
                rotation: rotations[id] ?? 0,
                speed: speed,
                lap: state.currentLap,
                checkpointsHit: state.checkpointsHit,
                boostAvailable: (boost?.cooldownRemaining ?? 1) <= 0,
                boostActive: boost?.isActive ?? false,
                finished: state.hasFinished,
                finishTime: playerMeta[id]?.finishTime
            ))
        }
        return result
    }

    private func buildResults(from players: [PlayerState]) -> [RaceResult] {
        let ranked = players.sorted { p1, p2 in
            if p1.finished, p2.finished {
                return (p1.finishTime ?? .infinity) < (p2.finishTime ?? .infinity)
            }
            if p1.finished { return true }
            if p2.finished { return false }
            return p1.lap > p2.lap
        }

        return ranked.enumerated().map { (index, player) in
            RaceResult(
                playerID: player.playerID,
                nickname: player.nickname,
                position: index + 1,
                totalTime: player.finishTime,
                bestLapTime: nil,
                stars: StarRatingCalculator.stars(for: index + 1),
                didFinish: player.finished
            )
        }
    }
}
