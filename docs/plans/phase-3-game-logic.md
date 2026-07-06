# Phase 3: Game Logic & Systems

## Overview

Implement the core game engine: physics tick, checkpoint/lap tracking, boost mechanics, star rating, and the state machine that orchestrates everything. Uses RealityKit `System` protocol for frame-by-frame processing. Testable via programmatic `RealityKit.Scene` — no 3D models or AR session required.

**iOS deployment target:** 18.4+
**Testing framework:** Swift Testing
**3D dependency:** None (uses procedural entities for testing)

---

## Decisions

| # | Decision | Answer |
|---|---|---|
| 1 | Component files | Keep BikeInputComponent, BikeStateComponent in `BikeEntityProtocol.swift` |
| 2 | Systems implementation | RealityKit `System` protocol (registered with scene) |
| 3 | Engine vs ViewModel | Two files: `RaceEngine` (actor) + `GameSessionViewModel` (@MainActor) |
| 4 | Game mode scope | Both solo + multiplayer |
| 5 | Physics approach | Apply forces/velocity via `PhysicsMotionComponent`; RealityKit engine integrates position |

---

## Architecture Overview

```
                         GameSessionViewModel (@MainActor)
                         ┌────────────────────────────┐
                         │  State machine              │
                         │  WAITING→COUNTDOWN→RACING   │
                         │  →FINISHED→RESULTS          │
                         │                            │
                         │  Coordinates:              │
                         │  RaceEngine + Networking   │
                         └─────────┬──────────────────┘
                                   │
                    ┌──────────────┼──────────────┐
                    ▼              ▼              ▼
              RaceEngine    HostSessionMgr  PeerSessionMgr
              (actor)       (actor)         (actor)
              ┌──────────┐
              │ Scene    │── RealityKit.Scene
              │ Systems  │── BikeMovementSystem
              │          │── BoostSystem
              │          │── CheckpointSystem
              │ Entities │── BikeEntity[]
              │          │── TrackEntity
              └──────────┘
```

### Tick flow (30 Hz, host-authoritative)

```
1. Host collects PlayerInput from all peers (via HostSessionManager)
2. RaceEngine.tick() is called
3. Systems run on the RealityKit scene:
   a. BikeMovementSystem — reads BikeInputComponent, applies forces
   b. BoostSystem — manages boost activation/cooldown
   c. CheckpointSystem — detects checkpoint crossings, updates lap tracking
4. RaceEngine reads updated entity states → constructs PlayerState[]
5. HostSessionManager broadcasts GameState to all peers

Peers receive GameState and interpolate entity positions locally.
Solo mode skips networking steps (steps 1, 5).
```

---

## Files to Create

```
bikebike/bikebike/
├── Entities/
│   ├── Components/
│   │   └── BoostComponent.swift
│   └── Systems/
│       ├── BikeMovementSystem.swift
│       ├── BoostSystem.swift
│       └── CheckpointSystem.swift
├── Game/
│   ├── RaceEngine.swift
│   ├── GameSessionViewModel.swift
│   └── StarRatingCalculator.swift

bikebikeTests/
    ├── RaceEngineTests.swift
    ├── GameSessionViewModelTests.swift
    ├── StarRatingCalculatorTests.swift
    └── SystemsTests.swift
```

---

## 1. `Entities/Components/BoostComponent.swift`

ECS component for boost state. Attached to bike entities alongside `BikeInputComponent`.

```swift
import RealityKit

struct BoostComponent: Component {
    var isActive = false
    var cooldownRemaining: TimeInterval = 0
    var boostTimeRemaining: TimeInterval = 0

    let cooldownDuration: TimeInterval = 10.0
    let boostDuration: TimeInterval = 2.5
    let speedMultiplier: Float = 1.5
}
```

**Design notes:**
- `isActive` — currently boosting (increased speed limit)
- `cooldownRemaining` — seconds until boost can be activated again
- `boostTimeRemaining` — seconds remaining in current boost
- `speedMultiplier` — applied to max speed when active
- Conforms to `Component` for RealityKit ECS integration

---

## 2. `Entities/Systems/BikeMovementSystem.swift`

Runs each frame. Reads `BikeInputComponent` from each bike entity, applies forces and velocity updates via `PhysicsMotionComponent`. RealityKit physics engine integrates position/rotation from these values.

```swift
import RealityKit

struct BikeMovementSystem: System {
    static var dependencies: [any Component.Type] {
        [BikeInputComponent.self]
    }

    static let query = EntityQuery(where: .has(BikeInputComponent.self))

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = Float(context.deltaTime)
        let bikes = context.scene.performQuery(Self.query)

        for bike in bikes {
            guard let input = bike.components[BikeInputComponent.self] else { continue }

            if bike.components[PhysicsMotionComponent.self] == nil {
                bike.components.set(PhysicsMotionComponent())
            }
            var motion = bike.components[PhysicsMotionComponent.self]!

            // Acceleration
            if input.isAccelerating {
                let rotation = bike.transform.rotation
                let forward = rotation.act(SIMD3<Float>(0, 0, -1))
                motion.linearVelocity += forward * 15.0 * dt
            }

            // Speed limit (respects boost multiplier)
            let maxSpeed: Float = input.boostRequested ? 7.5 : 5.0
            let speed = length(motion.linearVelocity)
            if speed > maxSpeed {
                motion.linearVelocity = (motion.linearVelocity / speed) * maxSpeed
            }

            // Linear damping (natural deceleration)
            motion.linearVelocity *= (1.0 - 0.3 * dt)

            // Steering (angular velocity around Y axis)
            if input.steerDirection != 0 {
                let turnRate: Float = 120.0 * (.pi / 180.0)
                motion.angularVelocity = SIMD3<Float>(0, input.steerDirection * turnRate * dt, 0)
            } else {
                // Angular damping (snap to straight)
                motion.angularVelocity *= (1.0 - 0.95 * dt)
            }

            bike.components.set(motion)
        }
    }
}
```

**Physics tuning constants (from TECH_DESIGN.md):**

| Constant | Value | In code |
|---|---|---|
| Max speed (normal) | 5.0 m/s | `maxSpeed` when not boosting |
| Max speed (boost) | 7.5 m/s | `maxSpeed` when `boostRequested` |
| Acceleration | 15.0 m/s² | `forward * 15.0 * dt` |
| Linear damping | 0.3 | `velocity *= (1 - 0.3 * dt)` |
| Angular damping | 0.95 | `angularVelocity *= (1 - 0.95 * dt)` |
| Turn rate | 120°/s | `120 * π/180 * dt` |

**Design notes:**
- Creates `PhysicsMotionComponent` if missing (first frame)
- `maxSpeed` checks `input.boostRequested` — BoostSystem sets this flag
- Uses `rotation.act(forward)` to compute world-space forward direction from entity orientation
- Steering applies angular velocity; damping auto-centers when no input

---

## 3. `Entities/Systems/BoostSystem.swift`

Runs each frame. Reads `BikeInputComponent.boostRequested` and `BoostComponent`. When boost is requested and cooldown is zero, activates boost. Counts down boost duration and cooldown.

```swift
import RealityKit

struct BoostSystem: System {
    static var dependencies: [any Component.Type] {
        [BikeInputComponent.self, BoostComponent.self]
    }

    static let query = EntityQuery(where: .has(BikeInputComponent.self) && .has(BoostComponent.self))

    init(scene: RealityKit.Scene) {}

    func update(context: SceneUpdateContext) {
        let dt = context.deltaTime
        let bikes = context.scene.performQuery(Self.query)

        for bike in bikes {
            guard var input = bike.components[BikeInputComponent.self],
                  var boost = bike.components[BoostComponent.self] else { continue }

            // Process boost activation request
            if input.boostRequested && !boost.isActive && boost.cooldownRemaining <= 0 {
                boost.isActive = true
                boost.boostTimeRemaining = boost.boostDuration
                boost.cooldownRemaining = 0
                input.boostRequested = false
            }

            // Countdown active boost
            if boost.isActive {
                boost.boostTimeRemaining -= dt
                if boost.boostTimeRemaining <= 0 {
                    boost.isActive = false
                    boost.cooldownRemaining = boost.cooldownDuration
                }
            }

            // Countdown cooldown
            if boost.cooldownRemaining > 0 && !boost.isActive {
                boost.cooldownRemaining = max(0, boost.cooldownRemaining - dt)
            }

            // Propagate boost state to input for speed limiting
            input.boostRequested = boost.isActive

            bike.components.set(input)
            bike.components.set(boost)
        }
    }
}
```

**Timing (from GAME_DESIGN.md):**

| Constant | Value |
|---|---|
| Boost duration | 2.5 seconds |
| Cooldown | 10 seconds |
| Speed increase | 50% (1.5× via `speedMultiplier`) |

**Design notes:**
- `boostRequested` is a rising-edge flag — consumed once, auto-cleared
- `boostRequested` is reused as `isActive` signal for `BikeMovementSystem` to adjust speed limit
- `cooldownRemaining` counts down only when not boosting
- All timers use `context.deltaTime` (frame time) for frame-rate independence

---

## 4. `Entities/Systems/CheckpointSystem.swift`

Runs each frame. Checks each bike's position against checkpoint trigger zones. Tracks lap progression. Detects race completion.

```swift
import RealityKit

struct CheckpointSystem: System {
    static var dependencies: [any Component.Type] {
        [BikeStateComponent.self]
    }

    static let bikeQuery = EntityQuery(where: .has(BikeStateComponent.self))

    private let checkpoints: [SIMD3<Float>]
    private let checkpointRadii: [Float]
    private let totalLaps: Int

    init(scene: RealityKit.Scene, track: Track) {
        self.checkpoints = track.checkpoints.map { $0.position }
        self.checkpointRadii = track.checkpoints.map { $0.radius }
        self.totalLaps = track.defaultLaps
    }

    func update(context: SceneUpdateContext) {
        let bikes = context.scene.performQuery(Self.bikeQuery)

        for bike in bikes {
            guard var state = bike.components[BikeStateComponent.self] else { continue }
            guard !state.hasFinished else { continue }

            let pos = bike.position

            // Check each checkpoint
            for (index, cpPos) in checkpoints.enumerated() {
                let distance = length(pos - cpPos)
                guard distance <= checkpointRadii[index] else { continue }

                // Must hit checkpoints in order
                guard !state.checkpointsHit.contains(index) else { continue }

                let expectedNext = state.checkpointsHit.count
                guard index == expectedNext else { continue }

                state.checkpointsHit.append(index)

                // Completed a full lap (all checkpoints hit)
                if state.checkpointsHit.count == checkpoints.count {
                    state.currentLap += 1
                    state.checkpointsHit = []

                    if state.currentLap >= totalLaps {
                        state.hasFinished = true
                        // finishTime set by RaceEngine
                    }
                }
            }

            bike.components.set(state)
        }
    }
}
```

**Design notes:**
- Checkpoints must be hit in order (0 → 1 → 0 → 1 → ...)
- When all checkpoints are hit, lap increments and checkpoint list resets
- When `currentLap >= totalLaps`, `hasFinished` is set
- `finishTime` is set by `RaceEngine` (which has access to the race clock)
- `init(scene:track:)` accepts `Track` to configure checkpoint positions

---

## 5. `Game/RaceEngine.swift`

Actor that owns the RealityKit scene and coordinates all systems. The authoritative source of game state for the host. Receives player input, calls scene update, reads resulting entity states, and constructs `PlayerState[]` for broadcast.

```swift
import RealityKit

actor RaceEngine {
    let track: Track
    let totalLaps: Int
    let scene: RealityKit.Scene

    private var playerEntities: [UUID: Entity] = [:]
    private var playerMeta: [UUID: PlayerMeta] = [:]
    private var tick: UInt32 = 0
    private var raceStartTime: Date?
    private var isRunning = false

    private struct PlayerMeta {
        let nickname: String
        var finishTime: TimeInterval?
    }

    init(track: Track) {
        self.track = track
        self.totalLaps = track.defaultLaps
        self.scene = RealityKit.Scene()

        let checkpointSystem = CheckpointSystem(scene: scene, track: track)

        scene.systems.register(BikeMovementSystem.self)
        scene.systems.register(BoostSystem.self)
        scene.systems.register(checkpointSystem)
    }

    func addPlayer(playerID: UUID, nickname: String, entity: Entity) {
        playerEntities[playerID] = entity
        playerMeta[playerID] = PlayerMeta(nickname: nickname)
        scene.addEntity(entity)
    }

    func removePlayer(playerID: UUID) {
        playerEntities[playerID]?.removeFromParent()
        playerEntities.removeValue(forKey: playerID)
        playerMeta.removeValue(forKey: playerID)
        players.removeValue(forKey: playerID)
    }

    func startRace() {
        isRunning = true
        tick = 0
        raceStartTime = Date()

        for (playerID, entity) in playerEntities {
            entity.position = track.startPosition
            let rotation = simd_quatf(angle: track.startRotation, axis: [0, 1, 0])
            entity.transform.rotation = rotation

            if var state = entity.components[BikeStateComponent.self] {
                state.currentLap = 0
                state.checkpointsHit = []
                state.hasFinished = false
                state.finishTime = nil
                entity.components.set(state)
            }

            if var input = entity.components[BikeInputComponent.self] {
                input.steerDirection = 0
                input.isAccelerating = false
                input.boostRequested = false
                entity.components.set(input)
            }
        }
    }

    func applyInput(playerID: UUID, input: PlayerInput) {
        guard let entity = playerEntities[playerID] else { return }
        guard var comp = entity.components[BikeInputComponent.self] else { return }

        comp.steerDirection = input.steerDirection
        comp.isAccelerating = input.accelerate
        comp.boostRequested = input.boostActivated || comp.boostRequested

        entity.components.set(comp)
    }

    func tick() -> (state: GameState, raceFinished: Bool) {
        tick += 1

        // Run RealityKit systems (physics + boost + checkpoints)
        scene.update(deltaTime: 1.0 / 30.0)

        // Read resulting entity states
        let players = playerEntities.map { (id, entity) in
            let motion = entity.components[PhysicsMotionComponent.self] ?? PhysicsMotionComponent()
            let state = entity.components[BikeStateComponent.self] ??
                BikeStateComponent(playerID: id, nickname: playerMeta[id]?.nickname ?? "")

            if state.hasFinished && playerMeta[id]?.finishTime == nil, let start = raceStartTime {
                playerMeta[id]?.finishTime = Date().timeIntervalSince(start)
            }

            let boost = entity.components[BoostComponent.self]

            return PlayerState(
                playerID: id,
                nickname: playerMeta[id]?.nickname ?? "",
                position: entity.position,
                rotation: atan2(entity.transform.rotation.imag.y, entity.transform.rotation.real),
                speed: length(motion.linearVelocity),
                lap: state.currentLap,
                checkpointsHit: state.checkpointsHit,
                boostAvailable: boost?.cooldownRemaining == 0 ?? true,
                boostActive: boost?.isActive ?? false,
                finished: state.hasFinished,
                finishTime: playerMeta[id]?.finishTime
            )
        }

        // Determine phase and results
        let allFinished = players.allSatisfy { $0.finished }
        let raceFinished = allFinished

        let results = raceFinished
            ? buildResults(from: players)
            : nil

        let state = GameState(
            sessionID: UUID(), // Set by GameSessionViewModel
            tick: tick,
            phase: raceFinished ? .finished : .racing,
            countdownSeconds: nil,
            totalLaps: totalLaps,
            players: Array(players),
            results: results
        )

        return (state, raceFinished)
    }

    func stop() {
        isRunning = false
    }

    private func buildResults(from players: [PlayerState]) -> [RaceResult] {
        let ranked = players.sorted { p1, p2 in
            if p1.finished && p2.finished {
                return (p1.finishTime ?? .infinity) < (p2.finishTime ?? .infinity)
            }
            if p1.finished { return true }
            if p2.finished { return false }
            return p1.lap > p2.lap
        }

        return ranked.enumerated().map { (index, player) in
            let position = index + 1
            return RaceResult(
                playerID: player.playerID,
                nickname: player.nickname,
                position: position,
                totalTime: player.finishTime,
                bestLapTime: nil, // Future: track best lap
                stars: StarRatingCalculator.stars(for: position),
                didFinish: player.finished
            )
        }
    }
}
```

**Design notes:**
- `init(track:)` registers all three systems on the scene
- `startRace()` resets all bike positions/rotations to track start, clears lap/checkpoint state
- `applyInput()` directly writes to the entity's `BikeInputComponent` — Systems read it next frame
- `tick()` calls `scene.update(deltaTime:)` which runs all registered systems, then reads entity states
- `buildResults()` ranks players: finished first (by time), then by lap count, then by position
- `finishTime` is timestamped once when `hasFinished` transitions to true

---

## 6. `Game/GameSessionViewModel.swift`

`@MainActor` class, `ObservableObject`. Owns the game state machine. Coordinates `RaceEngine` with `HostSessionManager` / `PeerSessionManager`. Exposes `@Published` properties for SwiftUI binding.

```swift
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

    private let mode: GameMode
    private let track: Track
    private let sessionID: UUID
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
        self.raceEngine = RaceEngine(track: track)
    }

    // MARK: - Lifecycle

    func setup() async {
        switch mode {
        case .solo:
            phase = .waiting
            addLocalPlayer()

        case .multiplayerHost:
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
        hostManager?.stop()
        peerManager?.disconnect()
    }

    // MARK: - Input

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
            Task { await raceEngine.applyInput(playerID: localID, input: input) }
        case .multiplayerPeer:
            Task { await peerManager?.sendInput(input) }
        }
    }

    // MARK: - Private

    private func addLocalPlayer() {
        let playerID = UUID()
        localPlayerID = playerID
        let mockBike = MockBikeEntity(
            playerID: playerID,
            nickname: "Player",
            position: track.startPosition
        )
        Task { await raceEngine.addPlayer(playerID: playerID, nickname: "Player", entity: mockBike.entity) }
        playerCount = 1
    }

    private func setupAsHost() {
        let host = HostSessionManager(nickname: UIDevice.current.name, maxPlayers: 6, sessionID: sessionID)
        hostManager = host

        // Host is also a local player
        addLocalPlayer()

        host.onPlayerJoined = { [weak self] playerID, nickname in
            guard let self else { return }
            Task { @MainActor in
                let mockBike = MockBikeEntity(
                    playerID: playerID,
                    nickname: nickname,
                    position: self.track.startPosition
                )
                await self.raceEngine.addPlayer(playerID: playerID, nickname: nickname, entity: mockBike.entity)
                self.playerCount = await self.raceEngine.playerCount
            }
        }

        host.onPlayerLeft = { [weak self] playerID in
            Task { @MainActor [weak self] in
                await self?.raceEngine.removePlayer(playerID: playerID)
                self?.playerCount = await self?.raceEngine.playerCount ?? 0
            }
        }

        Task {
            try? await host.start()
            await processHostInputs()
        }
    }

    private func processHostInputs() async {
        guard let host = hostManager else { return }
        for await (playerID, input) in host.inputStream() {
            await raceEngine.applyInput(playerID: playerID, input: input)
        }
    }

    private func setupAsPeer() {
        let peer = PeerSessionManager(nickname: UIDevice.current.name)
        peerManager = peer

        peer.onDisconnected = { [weak self] error in
            Task { @MainActor [weak self] in
                self?.phase = .finished
            }
        }

        Task {
            for await host in peer.startBrowsing() {
                do {
                    let result = try await peer.join(host: host)
                    if result.accepted, let playerID = result.playerID {
                        self.localPlayerID = playerID
                        self.phase = .waiting
                        await processPeerState(peer)
                    }
                } catch {
                    // Retry or show error
                }
            }
        }
    }

    private func processPeerState(_ peer: PeerSessionManager) async {
        for await state in peer.stateStream() {
            await MainActor.run {
                self.updateFromGameState(state)
            }
        }
    }

    private func updateFromGameState(_ state: GameState) {
        phase = state.phase
        players = state.players
        results = state.results
        playerCount = state.players.count

        if state.phase == .countdown {
            countdownSeconds = state.countdownSeconds
        }
    }

    private func beginCountdown() {
        phase = .countdown
        countdownSeconds = 3

        Task {
            for _ in 1...3 {
                try? await Task.sleep(for: .seconds(1))
                countdownSeconds? -= 1
            }

            phase = .racing
            countdownSeconds = nil
            await raceEngine.startRace()
            startTickLoop()
        }
    }

    private func startTickLoop() {
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task {
                let (state, raceFinished) = await self.raceEngine.tick()

                await MainActor.run {
                    self.players = state.players

                    if raceFinished {
                        self.phase = .finished
                        self.results = state.results
                        self.tickTimer?.invalidate()
                    }
                }

                // Host broadcasts state to peers
                if self.mode == .multiplayerHost {
                    await self.hostManager?.broadcast(state)
                }
            }
        }
    }
}
```

**State machine flow:**

```
WAITING ──(start button)──> COUNTDOWN ──(3 seconds)──> RACING ──(all finished)──> FINISHED ──> RESULTS
```

**Game mode differences:**

| Aspect | Solo | Host | Peer |
|---|---|---|---|
| Networking | None | `HostSessionManager` | `PeerSessionManager` |
| Physics | Local only | Authoritative (runs engine) | Receives `GameState` from host |
| Input | → `RaceEngine.applyInput()` | → `RaceEngine.applyInput()` | → `PeerSessionManager.sendInput()` |
| State | From `RaceEngine.tick()` | From `RaceEngine.tick()` + broadcast | From `PeerSessionManager.stateStream()` |

---

## 7. `Game/StarRatingCalculator.swift`

Pure function mapping race position to star rating (1–5).

```swift
enum StarRatingCalculator {
    static func stars(for position: Int) -> Int {
        max(1, min(5, 6 - position))
    }
}
```

| Position | Stars |
|---|---|
| 1st | 5 ★★★★★ |
| 2nd | 4 ★★★★☆ |
| 3rd | 3 ★★★☆☆ |
| 4th | 2 ★★☆☆☆ |
| 5th+ | 1 ★☆☆☆☆ |

---

## 8. Test Files

### `RaceEngineTests.swift`

```swift
import Testing
import RealityKit
@testable import bikebike

@Suite struct RaceEngineTests {

    @Test func engineInitializesWithTrack() async {
        let engine = RaceEngine(track: .downtown)
        #expect(engine.track.id == "downtown")
    }

    @Test func addingPlayerCreatesEntity() async {
        let engine = RaceEngine(track: .downtown)
        let mockBike = MockBikeEntity(
            playerID: UUID(), nickname: "Test",
            position: SIMD3<Float>.zero
        )
        await engine.addPlayer(
            playerID: UUID(),
            nickname: "Test",
            entity: mockBike.entity
        )
    }

    @Test func startRaceResetsPositions() async {
        let engine = RaceEngine(track: .downtown)
        let playerID = UUID()
        let mockBike = MockBikeEntity(
            playerID: playerID, nickname: "Test",
            position: SIMD3<Float>(5, 0, 5)
        )

        await engine.addPlayer(playerID: playerID, nickname: "Test", entity: mockBike.entity)
        await engine.startRace()

        let (state, _) = await engine.tick()
        #expect(state.players.count == 1)
    }

    @Test func tickGeneratesGameState() async {
        let engine = RaceEngine(track: .downtown)
        let playerID = UUID()
        let mockBike = MockBikeEntity(
            playerID: playerID, nickname: "Test",
            position: .downtown.startPosition
        )

        await engine.addPlayer(playerID: playerID, nickname: "Test", entity: mockBike.entity)
        await engine.startRace()

        let (state, _) = await engine.tick()

        #expect(state.phase == .racing)
        #expect(state.players.count == 1)
        #expect(state.tick > 0)
    }
}
```

### `GameSessionViewModelTests.swift`

```swift
import Testing
@testable import bikebike

@Suite struct GameSessionViewModelTests {

    @Test func initialPhaseIsWaiting() {
        let vm = GameSessionViewModel(mode: .solo, track: .downtown)
        #expect(vm.phase == .waiting)
    }

    @Test func soloModeHasOnePlayer() async {
        let vm = GameSessionViewModel(mode: .solo, track: .downtown)
        await vm.setup()
        #expect(vm.playerCount == 1)
    }

    @Test func startRaceBeginsCountdown() {
        let vm = GameSessionViewModel(mode: .solo, track: .downtown)
        vm.startRace()
        #expect(vm.phase == .countdown)
        #expect(vm.countdownSeconds == 3)
    }
}
```

### `StarRatingCalculatorTests.swift`

```swift
import Testing
@testable import bikebike

@Suite struct StarRatingCalculatorTests {

    @Test func firstPlaceGetsFiveStars() {
        #expect(StarRatingCalculator.stars(for: 1) == 5)
    }

    @Test func sixthPlaceGetsOneStar() {
        #expect(StarRatingCalculator.stars(for: 6) == 1)
    }

    @Test func ratingInRange() {
        for position in 1...20 {
            let stars = StarRatingCalculator.stars(for: position)
            #expect(stars >= 1 && stars <= 5)
        }
    }
}
```

### `SystemsTests.swift`

```swift
import Testing
import RealityKit
@testable import bikebike

@Suite struct SystemsTests {

    @Test func bikeMovementSystemHasCorrectDependencies() {
        let deps = BikeMovementSystem.dependencies
        #expect(deps.contains(where: { $0 == BikeInputComponent.self }))
    }

    @Test func boostSystemHasCorrectDependencies() {
        let deps = BoostSystem.dependencies
        #expect(deps.contains(where: { $0 == BikeInputComponent.self }))
        #expect(deps.contains(where: { $0 == BoostComponent.self }))
    }

    @Test func sceneRegistersSystems() {
        let track = Track.downtown
        let engine = RaceEngine(track: track)
        // Scene is initialized with all systems registered
    }

    @Test func movementSystemAcceleratesBike() async {
        let scene = RealityKit.Scene()
        scene.systems.register(BikeMovementSystem.self)

        let entity = Entity()
        entity.position = .zero
        var input = BikeInputComponent()
        input.isAccelerating = true
        entity.components.set(input)
        entity.components.set(PhysicsMotionComponent())
        scene.addEntity(entity)

        scene.update(deltaTime: 1.0 / 30.0)

        let motion = entity.components[PhysicsMotionComponent.self]
        #expect(motion != nil)
    }

    @Test func boostActivatesAndDeactivates() async {
        let scene = RealityKit.Scene()
        scene.systems.register(BoostSystem.self)

        let entity = Entity()
        var input = BikeInputComponent()
        input.boostRequested = true
        entity.components.set(input)
        entity.components.set(BoostComponent())
        scene.addEntity(entity)

        scene.update(deltaTime: 0.016)

        let boost = entity.components[BoostComponent.self]
        #expect(boost?.isActive == true)
    }
}
```

---

## Dependency Graph

```
BikeEntityProtocol  ──┐ (BikeInputComponent, BikeStateComponent)
BoostComponent ────────┤
Track ─────────────────┤
                       ├──► BikeMovementSystem ──┐
                       ├──► BoostSystem ─────────┤
                       ├──► CheckpointSystem ────┼──► RaceEngine ──► RaceEngineTests
                       │                         │
RaceResult ────────────┤                         │
                       ├──► StarRatingCalculator  │
                       │                         │
PlayerInput ───────────┤                         │
GameState ─────────────┤                         │
HostSessionManager ────┤                         │
PeerSessionManager ────┼──► GameSessionViewModel ──► VM Tests
                       │
StarRatingCalculator ──┴──► StarRatingTests
```

---

## Acceptance Criteria

- [ ] All 7 source files compile in Xcode
- [ ] `BoostComponent` conforms to `RealityKit.Component`
- [ ] All three systems conform to `RealityKit.System` with correct dependencies
- [ ] `BikeMovementSystem` accelerates entity when `isAccelerating` is true
- [ ] `BikeMovementSystem` caps speed at 5.0 (normal) and 7.5 (boosted)
- [ ] `BoostSystem` activates on `boostRequested`, counts down 2.5s, enters 10s cooldown
- [ ] `CheckpointSystem` tracks checkpoint order and increments lap count
- [ ] `RaceEngine.tick()` produces valid `GameState` with correct player positions
- [ ] `RaceEngine.startRace()` resets all entity positions to track start
- [ ] `GameSessionViewModel` correctly transitions through all 5 phases
- [ ] `StarRatingCalculator.stars(for:)` returns correct values for positions 1–6
- [ ] Systems can be tested with a programmatic `RealityKit.Scene`
- [ ] All test files pass
- [ ] No Swift 6 concurrency warnings
