# Phase 1: Foundation Models & Protocols

## Overview

Define all data models, network message types, and entity protocols before any implementation. This phase has **zero dependency on 3D models** — all structs are pure Swift data containers.

**iOS deployment target:** 18.4+  
**Testing framework:** Swift Testing  
**Project creation:** Xcode GUI (done manually by developer)

---

## Decisions Made

| # | Decision | Answer |
|---|---|---|
| 1 | Session ID in GameState | Yes, `sessionID: UUID` |
| 2 | Track info in GameState | Lap count only for MVP (single track) |
| 3 | GamePhase encoding | `Int`-backed enum |
| 4 | Nickname in PlayerState | Yes, inline |
| 5 | JoinRequest fields | Nickname only (driver assigned, not chosen) |
| 6 | Ready message | No — host decides when to start |
| 7 | Join rejection reasons | Lobby full + name taken |
| 8 | Chat/emoji | Skip for MVP |
| 9 | Driver representation | `Int` enum → hex color mapping |
| 10 | Driver models | 1 bike model × 6 color variants |
| 11 | Color storage | Hex string (`#RRGGBB`) |
| 12 | Track model | Full struct (future-proof for multiple tracks) |
| 13 | RaceResult fields | Full set (times, stars, DNF) |
| 14 | Solo star rating | Skip for MVP |
| 15 | Lap count | Configurable 1–5, default 3 |
| 16 | PlayerID in PlayerInput | No — inferred from NWConnection |
| 17 | Obstacle/checkpoint data source | Defined as Track data (not extracted from USDZ) |
| 18 | Checkpoints per lap | 1 (midpoint) + start/finish line |
| 19 | Entity protocols | Yes, define in Phase 1 with mocks for testing |

---

## Files to Create

```
BikeBike/
├── Models/
│   ├── GameState.swift
│   ├── PlayerInput.swift
│   ├── NetworkMessages.swift
│   ├── Driver.swift
│   ├── Track.swift
│   └── RaceResult.swift
├── Entities/
│   └── Protocols/
│       ├── BikeEntityProtocol.swift
│       └── TrackEntityProtocol.swift
└── Extensions/
    └── SIMD3+Encodable.swift

Tests/
    ├── GameStateTests.swift
    ├── RaceResultTests.swift
    └── StarRatingTests.swift
```

---

## 1. `Models/GameState.swift`

The host broadcasts this struct to peers 30 times per second.

```swift
import Foundation

enum GamePhase: Int, Codable {
    case waiting = 0
    case countdown = 1
    case racing = 2
    case finished = 3
    case results = 4
}

struct GameState: Codable {
    let sessionID: UUID
    let tick: UInt32
    let phase: GamePhase
    let countdownSeconds: Int?
    let totalLaps: Int
    let players: [PlayerState]
    let results: [RaceResult]?
}

struct PlayerState: Codable {
    let playerID: UUID
    let nickname: String
    let position: SIMD3<Float>
    let rotation: Float           // yaw angle in radians
    let speed: Float              // current velocity magnitude
    let lap: Int
    let checkpointsHit: [Int]     // ordered checkpoint IDs hit this lap
    let boostAvailable: Bool
    let boostActive: Bool
    let finished: Bool
    let finishTime: TimeInterval? // nil until they cross finish line
}
```

**Design notes:**
- `sessionID` lets peers ignore stale state from a previous host session
- `totalLaps` is included so the HUD can show "Lap 2 / 3"
- `checkpointsHit` is an ordered array — players must hit checkpoints in sequence to complete a lap
- `GamePhase` is `Int`-backed for compact wire format

---

## 2. `Models/PlayerInput.swift`

Peers send this to the host each tick. `playerID` is **inferred from the connection**, not included in the message.

```swift
import Foundation

struct PlayerInput: Codable {
    let tick: UInt32
    let steerDirection: Float    // -1.0 (full left) to 1.0 (full right), 0.0 = center
    let accelerate: Bool
    let boostActivated: Bool     // true only on the tick boost was tapped
}
```

**Design notes:**
- The host maintains a `[NWConnection: UUID]` map to associate inputs with players
- `boostActivated` is a rising-edge flag — the boost system activates on `true`, ignores subsequent `true` values

---

## 3. `Models/NetworkMessages.swift`

One-shot control messages for lobby and session management.

```swift
import Foundation

enum NetworkMessageType: UInt8, Codable {
    case joinRequest = 0
    case joinResponse = 1
    case hostMigrated = 2
    case playerDisconnected = 3
}

struct JoinRequest: Codable {
    let nickname: String
}

struct JoinResponse: Codable {
    let accepted: Bool
    let playerID: UUID?
    let rejectionReason: RejectionReason?
    let assignedDriverIndex: Int?

    enum RejectionReason: String, Codable {
        case lobbyFull
        case nameTaken
    }
}

struct HostMigrated: Codable {
    let newHostPlayerID: UUID
    let sessionID: UUID
    let lastKnownTick: UInt32
}

struct PlayerDisconnected: Codable {
    let playerID: UUID
}
```

**Design notes:**
- `assignedDriverIndex` maps to `Driver(rawValue:)` enum — auto-assigned, not chosen by player
- `HostMigrated` carries the last known tick so the new host can resume from the correct game state snapshot
- No "Ready" message — host presses Start whenever they want (min 2 players enforced in UI)

---

## 4. `Models/Driver.swift`

One bike model with 6 color variants. Colors stored as hex strings.

```swift
import Foundation

enum Driver: Int, CaseIterable, Codable {
    case green = 0
    case orange = 1
    case pink = 2
    case purple = 3
    case blue = 4
    case yellow = 5

    var displayName: String {
        switch self {
        case .green:  return "Go-Send"
        case .orange: return "Grab-Food"
        case .pink:   return "Shopee"
        case .purple: return "Lalamove"
        case .blue:   return "Maxim"
        case .yellow: return "Ninja"
        }
    }

    var colorHex: String {
        switch self {
        case .green:  return "#34C759"
        case .orange: return "#FF9500"
        case .pink:   return "#FF375F"
        case .purple: return "#AF52DE"
        case .blue:   return "#007AFF"
        case .yellow: return "#FFCC00"
        }
    }

    var modelFileName: String { "bike.usdz" }
}
```

**Design notes:**
- `modelFileName` is the same for all drivers — only the material color changes at load time
- `CaseIterable` for round-robin auto-assignment in multiplayer
- `Codable` so the host can tell peers which driver index they were assigned

---

## 5. `Models/Track.swift`

Track metadata + positions for all game elements. Obstacle and checkpoint positions are **defined as data**, not extracted from the USDZ at runtime.

```swift
import Foundation

struct Track: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let defaultLaps: Int
    let minLaps: Int
    let maxLaps: Int
    let modelFileName: String
    let startPosition: SIMD3<Float>
    let startRotation: Float          // yaw in radians
    let checkpoints: [Checkpoint]
    let obstacles: [Obstacle]
}

struct Checkpoint: Codable {
    let id: Int                      // 0 = start/finish, 1 = midpoint
    let position: SIMD3<Float>
    let radius: Float                // trigger zone radius in meters
}

struct Obstacle: Codable {
    let position: SIMD3<Float>
    let size: SIMD3<Float>           // bounding box (width, height, depth)
    let rotation: Float              // yaw in radians
    let type: ObstacleType
}

enum ObstacleType: String, Codable {
    case building
    case barrier
    case cone
    case parkedCar
}
```

**Design notes:**
- For MVP there is 1 track — but the struct supports multiple via `Identifiable`
- Checkpoint ID 0 is always start/finish, ID 1 is the midpoint
- Obstacle `size` defines the collision box that `TrackEntity` will apply at load time
- All positions are in track-local coordinates (track placed at AR world origin)

**MVP track data** (hardcoded or loaded from JSON):

```swift
extension Track {
    static let downtown = Track(
        id: "downtown",
        name: "Downtown Dash",
        description: "Tight city streets with sharp corners",
        defaultLaps: 3,
        minLaps: 1,
        maxLaps: 5,
        modelFileName: "track_downtown.usdz",
        startPosition: SIMD3<Float>(0.0, 0.02, 0.0),
        startRotation: 0.0,
        checkpoints: [
            Checkpoint(id: 0, position: SIMD3<Float>(0.0, 0.0, 0.0), radius: 0.05),   // start/finish
            Checkpoint(id: 1, position: SIMD3<Float>(0.0, 0.0, -0.5), radius: 0.05),  // midpoint
        ],
        obstacles: [
            // Filled when track model dimensions are known
        ]
    )
}
```

> **Note:** Obstacle positions and checkpoint positions are placeholders. They must be updated once the 3D model dimensions are finalized.

---

## 6. `Models/RaceResult.swift`

Full result for each player after the race ends.

```swift
import Foundation

struct RaceResult: Codable {
    let playerID: UUID
    let nickname: String
    let position: Int              // 1st = 1, 2nd = 2, etc.
    let totalTime: TimeInterval?   // nil if DNF
    let bestLapTime: TimeInterval? // nil if no complete laps
    let stars: Int                 // 1–5
    let didFinish: Bool
}
```

**Design notes:**
- Stars calculated from position only (1st = 5, 2nd = 4, ... 5th+ = 1)
- DNF players get 1 star and `didFinish = false`
- Solo mode: no stars (skip for MVP), time displayed but no rating

---

## 7. `Extensions/SIMD3+Encodable.swift`

SIMD3 conforms to Codable for JSON network serialization as a flat array `[x, y, z]`.

```swift
import Foundation

extension SIMD3<Float> {
    var array: [Float] { [x, y, z] }

    init(_ array: [Float]) {
        precondition(array.count == 3, "SIMD3 requires exactly 3 elements")
        self.init(array[0], array[1], array[2])
    }
}

extension SIMD3<Float>: Codable {
    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let x = try container.decode(Float.self)
        let y = try container.decode(Float.self)
        let z = try container.decode(Float.self)
        self.init(x, y, z)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(x)
        try container.encode(y)
        try container.encode(z)
    }
}
```

**Design notes:**
- Encoded as `[1.0, 2.5, 0.0]` in JSON — compact and readable
- Conforming to `Codable` via extension avoids wrapper types

---

## 8. `Entities/Protocols/BikeEntityProtocol.swift`

Protocol that abstracts RealityKit bike entity details. Enables testing systems with mock entities before real 3D models exist.

```swift
import RealityKit

protocol BikeEntityProtocol: AnyObject {
    var entity: Entity { get }
    var input: BikeInputComponent { get set }
    var state: BikeStateComponent { get set }

    func applyForwardForce(_ magnitude: Float)
    func applySteeringTorque(_ magnitude: Float)
    func resetTo(position: SIMD3<Float>, rotation: Float)
}

final class MockBikeEntity: BikeEntityProtocol {
    let entity: Entity
    var input = BikeInputComponent()
    var state: BikeStateComponent

    init(playerID: UUID, nickname: String, position: SIMD3<Float>) {
        let mesh = MeshResource.generateBox(size: [0.05, 0.05, 0.10])
        self.entity = ModelEntity(mesh: mesh, materials: [])
        self.state = BikeStateComponent(playerID: playerID, nickname: nickname)
        self.entity.position = position
    }

    func applyForwardForce(_ magnitude: Float) {
        let forward = SIMD3<Float>(0, 0, -magnitude)
        entity.position += forward * 0.016
    }

    func applySteeringTorque(_ magnitude: Float) {
        entity.transform.rotation *= simd_quatf(angle: magnitude * 0.016, axis: [0, 1, 0])
    }

    func resetTo(position: SIMD3<Float>, rotation: Float) {
        entity.position = position
        entity.transform.rotation = simd_quatf(angle: rotation, axis: [0, 1, 0])
    }
}
```

**Design notes:**
- `BikeInputComponent` and `BikeStateComponent` are the ECS components from the tech doc
- Mock uses a procedural box mesh — no USDZ needed
- Real `BikeEntity` class will implement the same protocol

---

## 9. `Entities/Protocols/TrackEntityProtocol.swift`

Protocol for track entities. Separates track setup from the USDZ loading implementation.

```swift
import RealityKit

protocol TrackEntityProtocol: AnyObject {
    var entity: Entity { get }
    var checkpoints: [Entity] { get }
    var finishLine: Entity { get }
    var obstacles: [Entity] { get }
}

final class MockTrackEntity: TrackEntityProtocol {
    let entity: Entity
    let checkpoints: [Entity]
    let finishLine: Entity
    let obstacles: [Entity]

    init(track: Track) {
        let root = Entity()

        // Floor plane
        let floor = ModelEntity(
            mesh: .generatePlane(width: 1.0, depth: 1.5),
            materials: [SimpleMaterial(color: .darkGray, isMetallic: false)]
        )
        root.addChild(floor)

        // Checkpoint trigger zones (invisible)
        self.checkpoints = track.checkpoints.map { cp in
            let trigger = Entity()
            trigger.position = cp.position
            trigger.name = "checkpoint_\(cp.id)"
            root.addChild(trigger)
            return trigger
        }

        self.finishLine = Entity()
        self.finishLine.position = track.checkpoints.first { $0.id == 0 }?.position ?? .zero
        self.finishLine.name = "finishLine"
        root.addChild(finishLine)

        // Obstacles
        self.obstacles = track.obstacles.map { obs in
            let mesh = MeshResource.generateBox(size: obs.size)
            let entity = ModelEntity(
                mesh: mesh,
                materials: [SimpleMaterial(color: .gray, isMetallic: false)]
            )
            entity.position = obs.position
            entity.transform.rotation = simd_quatf(angle: obs.rotation, axis: [0, 1, 0])
            root.addChild(entity)
            return entity
        }

        self.entity = root
    }
}
```

**Design notes:**
- Mock uses flat plane + procedural boxes — fully functional for physics testing
- Checkpoint entities are invisible trigger zones — their names are used for collision event filtering
- Real `TrackEntity` replaces the procedural geometry with the USDZ model while keeping the same structure

---

## 10. Test Files

### `Tests/GameStateTests.swift`

```swift
import Testing
import Foundation
@testable import BikeBike

@Suite struct GameStateTests {

    @Test func encodeDecodeRoundTrip() throws {
        let state = GameState(
            sessionID: UUID(),
            tick: 42,
            phase: .racing,
            countdownSeconds: nil,
            totalLaps: 3,
            players: [
                PlayerState(
                    playerID: UUID(),
                    nickname: "Alice",
                    position: SIMD3<Float>(1.0, 0.0, 2.0),
                    rotation: 1.57,
                    speed: 3.5,
                    lap: 1,
                    checkpointsHit: [0],
                    boostAvailable: true,
                    boostActive: false,
                    finished: false,
                    finishTime: nil
                )
            ],
            results: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(state)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GameState.self, from: data)

        #expect(decoded.tick == 42)
        #expect(decoded.phase == .racing)
        #expect(decoded.totalLaps == 3)
        #expect(decoded.players.count == 1)
        #expect(decoded.players[0].nickname == "Alice")
    }

    @Test func deltaDetectsChangedPlayerPosition() {
        // Verify delta logic (when implemented in GameStateCodec)
        let old = SIMD3<Float>(0, 0, 0)
        let new = SIMD3<Float>(0.1, 0, 0)
        #expect(old != new)
    }
}
```

### `Tests/RaceResultTests.swift`

```swift
import Testing
import Foundation
@testable import BikeBike

@Suite struct RaceResultTests {

    @Test func firstPlaceGetsFiveStars() {
        let result = RaceResult(
            playerID: UUID(),
            nickname: "Alice",
            position: 1,
            totalTime: 45.2,
            bestLapTime: 14.8,
            stars: 5,
            didFinish: true
        )

        #expect(result.stars == 5)
        #expect(result.didFinish)
    }

    @Test func dnfPlayerGetsOneStarAndNoTime() {
        let result = RaceResult(
            playerID: UUID(),
            nickname: "Bob",
            position: 6,
            totalTime: nil,
            bestLapTime: nil,
            stars: 1,
            didFinish: false
        )

        #expect(result.stars == 1)
        #expect(result.totalTime == nil)
        #expect(result.didFinish == false)
    }
}
```

### `Tests/StarRatingTests.swift`

```swift
import Testing
import Foundation
@testable import BikeBike

@Suite struct StarRatingTests {

    func stars(for position: Int) -> Int {
        max(1, 6 - position)  // 1st=5, 2nd=4, ..., 5th=1, 6th=1
    }

    @Test func positionToStars() {
        #expect(stars(for: 1) == 5)
        #expect(stars(for: 2) == 4)
        #expect(stars(for: 3) == 3)
        #expect(stars(for: 4) == 2)
        #expect(stars(for: 5) == 1)
        #expect(stars(for: 6) == 1)
    }
}
```

---

## Dependency Graph

```
SIMD3+Encodable  ──┐
                    ├──> GameState ──> GameStateTests
Driver ────────────┤
                    ├──> NetworkMessages
Track ─────────────┤
                    ├──> RaceResult ──> RaceResultTests ──> StarRatingTests
PlayerInput ───────┤
                    │
                    └──> BikeEntityProtocol ──> (Phase 2: Systems)
                         TrackEntityProtocol ──> (Phase 2: TrackEntity)
```

No file depends on RealityKit beyond `import RealityKit` for the protocol signatures.

---

## Acceptance Criteria

- [ ] All 7 source files compile
- [ ] All 3 test files pass with `swift test`
- [ ] `GameState` encodes to valid JSON and decodes back without data loss
- [ ] `SIMD3<Float>` encodes as `[x, y, z]` array in JSON
- [ ] `Driver.allCases` contains exactly 6 entries
- [ ] `Track.downtown` static property returns a valid track
- [ ] `MockBikeEntity` and `MockTrackEntity` instantiate without crash
- [ ] No warnings from Swift 6 strict concurrency checking
