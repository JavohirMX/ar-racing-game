# Technical Design Document

## Architecture Overview

The app follows **MVVM** pattern with **RealityKit Entity-Component System (ECS)** for the 3D/AR layer. SwiftUI handles all 2D UI. Network Framework provides peer-to-peer multiplayer without any server backend.

```
┌──────────────────────────────────────────────────┐
│                   SwiftUI Layer                   │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌──────────┐  │
│  │  Menu  │ │ Lobby  │ │  HUD   │ │ Results  │  │
│  └────────┘ └────────┘ └────────┘ └──────────┘  │
├──────────────────────────────────────────────────┤
│                  ViewModel Layer                  │
│  ┌──────────────┐ ┌───────────┐ ┌────────────┐  │
│  │ GameSession  │ │ NetManager│ │ AudioMgr   │  │
│  │   ViewModel  │ │ (Host/Peer)│ │ HapticMgr  │  │
│  └──────┬───────┘ └─────┬─────┘ └────────────┘  │
├─────────┼───────────────┼────────────────────────┤
│         ▼               ▼                         │
│  ┌──────────────────────────────────────────┐    │
│  │        RealityKit + ARKit Layer           │    │
│  │  ┌────────────────────────────────────┐  │    │
│  │  │  ARView / RealityView              │  │    │
│  │  │  ┌──────┐ ┌──────┐ ┌───────────┐  │  │    │
│  │  │  │ Bike │ │Obst. │ │Track/Floor│  │  │    │
│  │  │  │Entity│ │Entity│ │  Entity   │  │  │    │
│  │  │  └──────┘ └──────┘ └───────────┘  │  │    │
│  │  │  SpatialTrackingSession            │  │    │
│  │  └────────────────────────────────────┘  │    │
│  └──────────────────────────────────────────┘    │
├──────────────────────────────────────────────────┤
│           Network Framework Layer                 │
│  ┌────────────┐ ┌──────────┐ ┌───────────────┐  │
│  │ NWListener │ │NWBrowser │ │ NWConnection  │  │
│  │ (advertise)│ │(discover)│ │ x N (per peer)│  │
│  └────────────┘ └──────────┘ └───────────────┘  │
└──────────────────────────────────────────────────┘
```

### Key Design Decisions

| Decision | Rationale |
|---|---|
| Host-authoritative | Simple to implement, avoids consensus complexity for a 2-6 week project |
| TCP over UDP | Reliable delivery matters more than raw speed for 6-player game state; NWConnection TCP handles ordering and retransmission |
| MVVM + ECS | MVVM for UI/logic separation; RealityKit ECS is the natural pattern for 3D entities |
| No backend server | Local multiplayer only — pure peer-to-peer, no server costs or infrastructure |
| SwiftData for local state | Persist player preferences, high scores, driver unlocks |

---

## Frameworks & Dependencies

| Framework | Version | Purpose |
|---|---|---|
| SwiftUI | iOS 18+ | All 2D UI (menus, HUD, lobby, results) |
| RealityKit | iOS 18+ | 3D rendering, physics simulation, entity management |
| ARKit | iOS 18+ | Plane detection, world tracking via `SpatialTrackingSession` |
| Network | iOS 12+ | Peer-to-peer networking (`NWBrowser`, `NWListener`, `NWConnection`) |
| AVFoundation | iOS 4+ | Audio playback (engine SFX, UI sounds) |
| CoreHaptics | iOS 13+ | Haptic feedback engine |
| Combine | iOS 13+ | Reactive data flow between ViewModels and Views |
| SwiftData | iOS 17+ | Local persistence for settings and stats |

### Why Not MultipeerConnectivity?

As of iOS 27, the entire `MultipeerConnectivity` framework is deprecated (including `MCSession`, `MCNearbyServiceBrowser`, `MCNearbyServiceAdvertiser`, and `MCBrowserViewController`). Apple's guidance: **"Use Network Framework instead."**

The Network Framework provides equivalent peer-to-peer capabilities:
- `NWBrowser` ↔ `MCNearbyServiceBrowser` (Bonjour-based service discovery)
- `NWListener` + Bonjour service ↔ `MCNearbyServiceAdvertiser` (advertising)
- `NWConnection` ↔ `MCSession` (data transport)

Since `MultipeerConnectivityService` (RealityKit) depends on `MCSession`, we implement **custom game state synchronization** — the host serializes game state and sends it to all peers each tick.

---

## Networking Architecture

### Stack

```
App Layer
    │
GameState (Codable struct)
    │
HostSyncManager / PeerSyncManager
    │
NWConnection (TCP, one per peer)
    │
NWBrowser (peer discovery) / NWListener (host advertising)
    │
Bonjour (service type: "_bikebike._tcp")
```

### Peer Discovery

```swift
// Host advertises
let listener = try NWListener(using: .tcp, on: randomPort)
listener.service = NWListener.Service(
    name: hostName,
    type: "_bikebike._tcp",
    domain: "local."
)

// Peer discovers
let browser = NWBrowser(
    for: .bonjour(type: "_bikebike._tcp", domain: "local."),
    using: .tcp
)
```

The service type `_bikebike._tcp` must be declared in `Info.plist` under `NSBonjourServices`.

### Connection Setup

Once a peer discovers a host:
1. Peer creates `NWConnection` to the discovered endpoint
2. Peer sends a `JoinRequest` message (contains player nickname, driver selection)
3. Host validates, sends `JoinResponse` (accepted/rejected, assigned player ID)
4. Connection transitions to ready state — game data can flow

### Game State Synchronization

**Tick rate:** 30 Hz (state sent every ~33ms)

**Host → Peers (every tick):**
```swift
struct GameState: Codable {
    let tick: UInt32
    let phase: GamePhase           // waiting, countdown, racing, finished
    let countdownSeconds: Int?     // during countdown only
    let players: [PlayerState]
    let results: [RaceResult]?     // when phase == finished
}

struct PlayerState: Codable {
    let playerID: UUID
    let position: SIMD3<Float>
    let rotation: Float            // yaw angle
    let speed: Float
    let lap: Int
    let checkpointsHit: [Int]
    let boostAvailable: Bool
    let boostActive: Bool
    let finished: Bool
    let finishTime: TimeInterval?
}
```

**Peers → Host (every tick):**
```swift
struct PlayerInput: Codable {
    let tick: UInt32
    let steerDirection: Float      // -1.0 (full left) to 1.0 (full right), 0.0 = center
    let accelerate: Bool
    let boostActivated: Bool       // true on the tick boost was tapped
}
```

### Delta Compression

To reduce bandwidth, the host compares the current game state frame to the previous and only sends changed fields. This is applied as a post-optimization — start with full state, profile, then add if needed.

### Host Migration

```
Host disconnect detected
        │
        ▼
Each peer computes: myPriority = hash(myPeerID + sessionID)
        │
        ▼
Peer with highest priority promotes itself
        │
        ▼
New host starts NWListener, sends "HostMigrated" to all peers
        │
        ▼
Peers reconnect to new host
        │
        ▼
New host loads last known GameState
        │
        ▼
Race resumes with countdown (3... 2... 1... GO!)
```

### QR Code Fallback

When auto-discovery fails (e.g., restrictive network):
1. Host displays a QR code containing JSON: `{"name":"Player1","host":"192.168.1.5","port":12345,"service":"_bikebike._tcp"}`
2. Peer scans the QR, parses the endpoint
3. Peer connects directly via `NWConnection(host:port:using:)`

---

## RealityKit / ARKit Architecture

### SpatialTrackingSession Configuration

```swift
let configuration = SpatialTrackingSession.Configuration(
    tracking: [.plane],
    sceneUnderstanding: [.shadow, .occlusion, .collision],
    camera: .back
)
let trackingSession = SpatialTrackingSession()
await trackingSession.run(configuration)
```

### Entity Hierarchy

```
Scene
├── AnchorEntity (world tracking, placed on detected plane)
│   ├── TrackEntity (usdz model, static physics body for floor)
│   │   ├── BuildingEntity[] (static obstacles)
│   │   ├── BarrierEntity[] (static obstacles)
│   │   ├── ConeEntity[] (static obstacles)
│   │   └── FinishLineTrigger (collision detection zone)
│   └── BikeEntity[] (one per player)
│       ├── ModelComponent (usdz bike + rider model)
│       ├── PhysicsBodyComponent (dynamic, affected by forces)
│       ├── PhysicsMotionComponent (velocity, angular velocity)
│       ├── BikeInputComponent (steer, accelerate, boost state)
│       ├── BikeStateComponent (lap, checkpoints, playerID)
│       └── ParticleEmitterComponent (boost trail, conditional)
```

### Custom Components

```swift
struct BikeInputComponent: Component {
    var steerDirection: Float = 0
    var isAccelerating: Bool = false
    var boostRequested: Bool = false
}

struct BikeStateComponent: Component {
    let playerID: UUID
    var currentLap: Int = 0
    var checkpointsHit: Set<Int> = []
    var hasFinished: Bool = false
    var finishTime: TimeInterval?
}

struct BoostComponent: Component {
    var isActive: Bool = false
    var cooldownRemaining: TimeInterval = 0
    var cooldownDuration: TimeInterval = 10.0
    var boostDuration: TimeInterval = 2.5
    var speedMultiplier: Float = 1.5
}
```

### Physics Tuning (Arcade)

| Property | Value | Notes |
|---|---|---|
| Bike mass | 1.0 kg | Light for responsive handling |
| Linear damping | 0.3 | Some drag for natural feel |
| Angular damping | 0.95 | High damping for quick turn response |
| Max speed (normal) | 5.0 m/s | Scaled to AR world |
| Max speed (boost) | 7.5 m/s | 1.5x multiplier |
| Acceleration | 15.0 m/s² | Quick to reach max speed |
| Turn rate | 120°/s | Responsive steering |
| Collision restitution | 0.1 | Low bounce off obstacles |
| Friction | 1.0 | High grip on track surface |

---

## Game State Machine

```
                    ┌──────────┐
                    │  WAITING │ ◄── Initial state
                    └────┬─────┘
                         │ all players joined & ready
                         ▼
                    ┌───────────┐
                    │ COUNTDOWN │ (3... 2... 1... GO!)
                    └─────┬─────┘
                          │ countdown reaches 0
                          ▼
                    ┌───────────┐
              ┌────►│  RACING   │◄──┐
              │     └─────┬─────┘   │
              │           │         │
              │     ┌─────▼─────┐   │
              │     │ checkpoint│   │ player input each tick
              │     └───────────┘   │
              │                     │
              │     all players     │
              │     finished or     │
              │     timeout         │
              │           │         │
              │           ▼         │
              │     ┌──────────┐    │
              └─────│ FINISHED │────┘
                    └────┬─────┘
                         │ host computes results
                         ▼
                    ┌──────────┐
                    │ RESULTS  │
                    └──────────┘
```

### Phase Details

| Phase | Duration | Description |
|---|---|---|
| WAITING | Indefinite | Players join, select drivers. Host presses "Start" when ready. Minimum 2 players for multi. |
| COUNTDOWN | 3 seconds | "3... 2... 1... GO!" with audio + haptic ticks. Bikes are frozen. |
| RACING | ~1-4 min | Core gameplay. Input processed each tick, state synced. |
| FINISHED | ~5 seconds | All bikes slow to stop. Finish animation plays. |
| RESULTS | Until dismissed | Star ratings, positions, times displayed. "Play Again" or "Main Menu" options. |

### Timeout
If not all players finish within 5 minutes of the leader crossing the line, race ends anyway. DNF players get 1 star.

---

## Input Pipeline

```
Touch Events (SwiftUI overlay)
        │
        ▼
InputViewModel (normalizes raw touch to -1...1 steer, bool accelerate/boost)
        │
        ▼
┌───────────────────┐
│ Local player:     │
│ → BikeInputComp   │  (applies directly to local bike entity)
│ → PlayerInput msg │  (sends to host via NWConnection)
│                   │
│ Host:             │
│ → Ingest all      │
│   PlayerInput     │
│ → Run physics     │
│ → Emit GameState  │
│                   │
│ Peers:            │
│ → Receive GameState
│ → Interpolate to  │
│   target position │
│   (smooth rendering)
└───────────────────┘
```

### Input Smoothing (Peers)

Peers don't use received positions directly — they interpolate:

```swift
// Each tick, peer updates target position from host state
bikeEntity.move(
    to: Transform(scale: .one, rotation: targetRotation, translation: targetPosition),
    relativeTo: nil,
    duration: 0.05  // slightly longer than tick interval for smoothness
)
```

---

## Audio System

```swift
class AudioManager {
    private let engine = AVAudioEngine()
    private var players: [SoundID: AVAudioPlayerNode] = [:]

    enum SoundID: String {
        case engineLoop, boost, collision, countdown, goHorn, finishCheer, uiTap
    }

    func play(_ sound: SoundID, pitch: Float = 1.0, volume: Float = 1.0)
    func setMasterVolume(_ volume: Float)
    func toggleSound(_ sound: SoundID, enabled: Bool)
}
```

Audio files are `.wav` / `.m4a` in the app bundle. Engine sounds loop continuously with pitch modulation based on bike speed.

---

## Haptics System

```swift
class HapticManager {
    private let engine: CHHapticEngine?

    func playImpact(style: UIImpactFeedbackGenerator.FeedbackStyle)
    func playCustomPattern(_ pattern: CHHapticPattern)
    func playTransient(intensity: Float, sharpness: Float)
}
```

CoreHaptics engine is created on app launch. If the device doesn't support CoreHaptics, fall back to `UIImpactFeedbackGenerator` for basic feedback.

---

## Project Structure

```
BikeBike/
├── App/
│   ├── BikeBikeApp.swift              # @main entry point
│   └── AppDependencyContainer.swift   # DI setup
├── Models/
│   ├── GameState.swift                # Codable game state for networking
│   ├── PlayerInput.swift              # Codable input for networking
│   ├── Driver.swift                   # Driver skin model
│   ├── Track.swift                    # Track metadata model
│   ├── RaceResult.swift               # Result data
│   └── NetworkMessages.swift          # JoinRequest, JoinResponse, etc.
├── Game/
│   ├── GameSessionViewModel.swift     # Central game state machine
│   ├── RaceEngine.swift               # Physics tick, checkpoint detection
│   └── StarRatingCalculator.swift     # Position → star rating logic
├── Entities/
│   ├── BikeEntity.swift               # Bike entity factory
│   ├── TrackEntity.swift              # Track entity factory
│   ├── Components/
│   │   ├── BikeInputComponent.swift
│   │   ├── BikeStateComponent.swift
│   │   └── BoostComponent.swift
│   └── Systems/
│       ├── BikeMovementSystem.swift    # Per-tick physics update
│       ├── BoostSystem.swift          # Boost activation & cooldown
│       └── CheckpointSystem.swift     # Detect checkpoint/lap crossings
├── Networking/
│   ├── HostSessionManager.swift       # NWListener + game state broadcast
│   ├── PeerSessionManager.swift       # NWBrowser + connect + receive state
│   ├── GameStateCodec.swift           # Encode/decode with delta compression
│   ├── QRCodeGenerator.swift          # Generate QR for manual join
│   ├── QRCodeScanner.swift            # Scan QR to join
│   └── HostMigrationHandler.swift     # Detect disconnect, promote new host
├── UI/
│   ├── MainMenuView.swift
│   ├── DriverSelectView.swift
│   ├── TrackSelectView.swift
│   ├── SurfaceScanView.swift          # AR plane detection UI
│   ├── LobbyView.swift                # Multiplayer lobby
│   ├── CountdownOverlay.swift
│   ├── HUDView.swift                  # Minimap, lap, position, boost
│   ├── ResultsView.swift
│   └── SettingsView.swift
├── Audio/
│   └── AudioManager.swift
├── Haptics/
│   └── HapticManager.swift
├── Extensions/
│   └── SIMD3+NetworkEncoding.swift    # Encode SIMD3<Float> for Codable
└── Resources/
    ├── Models/                         # .usdz files
    │   ├── bike_gosend.usdz
    │   ├── bike_grabfood.usdz
    │   ├── bike_shopee.usdz
    │   ├── bike_lalamove.usdz
    │   ├── bike_maxim.usdz
    │   ├── bike_ninja.usdz
    │   ├── track_downtown.usdz
    │   ├── track_market.usdz
    │   └── track_harbor.usdz
    └── Audio/                          # .wav / .m4a files
        ├── engine_loop.wav
        ├── boost.wav
        ├── collision.wav
        ├── countdown_beep.wav
        ├── go_horn.wav
        └── finish_fanfare.wav
```

---

## Info.plist Requirements

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>This app uses the local network to discover and connect to nearby players for multiplayer races.</string>

<key>NSBonjourServices</key>
<array>
    <string>_bikebike._tcp</string>
</array>

<key>NSCameraUsageDescription</key>
<string>This app uses the camera to place the racetrack in augmented reality.</string>

<key>UIRequiredDeviceCapabilities</key>
<array>
    <string>arkit</string>
</array>

<key>UIStatusBarHidden</key>
<true/>

<key>UIRequiresFullScreen</key>
<true/>
```

---

## Performance Targets

| Metric | Target |
|---|---|
| Frame rate (rendering) | 60 FPS |
| Network tick rate | 30 Hz |
| State message size (full) | < 2 KB (6 players) |
| State message size (delta) | < 500 bytes (typical) |
| Latency (local network) | < 10 ms |
| Memory usage | < 300 MB |
| App launch to menu | < 2 seconds |
| Track load time | < 3 seconds |
