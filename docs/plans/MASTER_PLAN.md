# Bike Bike — Master Plan

## Project Overview

**Bike Bike** is a local multiplayer AR racing game for iOS 18.4+. Players control delivery drivers on motorbikes, racing on 3D city-themed tracks placed on real-world flat surfaces via ARKit. First to complete all laps wins.

| Attribute | Value |
|---|---|
| Genre | Arcade AR Racing |
| Platform | iOS 18.4+ (physical device) |
| Players | 1 (solo) or 2–6 (multiplayer) |
| Race duration | ~1–4 minutes |
| Perspective | Top-down AR view |
| Tech stack | Swift 6, SwiftUI, RealityKit, ARKit, Network Framework |
| Architecture | MVVM + Entity-Component (ECS-inspired) |
| Multiplayer | Host-authoritative, Bonjour P2P, TCP, 30 Hz tick |
| Testing | Swift Testing |
| MVP scope | 1 track, 1 bike model × 6 colors, solo + multiplayer |

---

## Architecture

```
┌──────────────────────────────────────────────────────┐
│                   SwiftUI Layer                       │
│  MainMenu → Lobby → Countdown → HUD → Results       │
├──────────────────────────────────────────────────────┤
│                  ViewModel Layer                      │
│  GameSessionViewModel (@MainActor, ObservableObject) │
│  ARPlacementViewModel                                │
├──────────────────────────────────────────────────────┤
│                  Game Engine Layer                    │
│  RaceEngine (@MainActor) — physics, checkpoints,     │
│  boost, results                                      │
├──────────────┬───────────────────────────────────────┤
│  Networking  │          AR/RealityKit Layer           │
│  Host/Peer   │  ARView, TrackEntity, BikeEntity     │
│  Managers    │  SpatialTrackingSession               │
│  (actors)    │  Plane detection, model loading       │
├──────────────┴───────────────────────────────────────┤
│              Audio / Haptics / Extensions             │
└──────────────────────────────────────────────────────┘
```

### Data flow (host-authoritative, 30 Hz)

```
Peers → PlayerInput → HostSessionManager → RaceEngine.tick()
                                                │
                              ┌─────────────────┘
                              ▼
                    GameState (physics, positions, laps)
                              │
                              ▼
                HostSessionManager.broadcast() → All Peers
                              │
                              ▼
              Peers render via interpolation
```

---

## Key Decisions (All Phases)

| # | Decision | Phase |
|---|---|---|
| 1 | App lifecycle: SwiftUI `@main App` (not UIKit) | 1 |
| 2 | iOS deployment target: 18.4+ | 1 |
| 3 | All models Codable, SIMD3 already Codable in Swift 6 | 1 |
| 4 | GamePhase: Int-backed enum | 1 |
| 5 | Driver: 1 bike model × 6 colors, hex string colors, Int enum | 1 |
| 6 | Track: 1 track for MVP, obstacle positions defined as data | 1 |
| 7 | Laps: configurable 1–5, default 3 | 1 |
| 8 | PlayerID in PlayerInput: inferred from connection | 2 |
| 9 | Join request: nickname only (driver auto-assigned) | 2 |
| 10 | No Ready message (host decides start) | 2 |
| 11 | Rejection reasons: lobby full + name taken | 2 |
| 12 | Message framing: length-prefixed in RealNetworkConnection | 2 |
| 13 | Full GameState per tick (no delta compression for MVP) | 2 |
| 14 | Host migration: deferred | 2 |
| 15 | Concurrency: actors for networking, @MainActor for engine/UI | 2 |
| 16 | QR scanner: CoreImage generator + AVFoundation scanner | 2 |
| 17 | Physics: manual SIMD math in RaceEngine (iOS 26 broke RealityKit Systems) | 3 |
| 18 | Physics: 15 m/s² accel, 5.0/7.5 max speed, 120°/s steering | 3 |
| 19 | Boost: 2.5s duration, 10s cooldown, 1.5× speed | 3 |
| 20 | Checkpoints: ordered sequential (0→1→0→1...), distance-based | 3 |
| 21 | Star rating: position-based (1st=5★, 2nd=4★ ... 5th+=1★) | 3 |
| 22 | Solo + multiplayer modes: both supported | 3 |
| 23 | Theme: cream/beige, orange CTA, rounded typography | 4 |
| 24 | Controls: virtual joystick + press-and-hold gas/brake/boost buttons | 4 |
| 25 | AR: ARWorldTrackingConfiguration (plane detection) | 4 |
| 26 | Audio: system sounds for MVP (custom audio deferred) | 5 |
| 27 | Haptics: UIImpactFeedbackGenerator for MVP (CoreHaptics deferred) | 5 |

---

## Phase Status

| Phase | Status | Source Files | Test Files |
|---|---|---|---|
| **P1: Foundation Models** | ✅ Complete | 7 | 3 |
| **P2: Networking** | ✅ Complete | 7 | 5 |
| **P3: Game Logic** | ✅ Complete | 4 | 3 |
| **P4: UI** | ✅ Complete | 15 | — |
| **P5: Audio/Haptics** | ✅ MVP | 2 | — |
| **P6: AR Integration** | 🔴 Pending | 1 (stub) | — |
| **P7: Wire UI ↔ Engine** | 🔴 Pending | — | — |

**Total: 37 source files, 11 test files**

---

## File Inventory

```
bikebike/bikebike/
├── App/
│   ├── BikeBikeApp.swift                    # @main entry point
│   └── AppDependencyContainer.swift         # DI, navigation, shared state
├── Models/
│   ├── Driver.swift                         # 6-color enum
│   ├── GameState.swift                      # GamePhase, GameState, PlayerState
│   ├── NetworkMessages.swift                # Join/Response, migration, disconnect
│   ├── PlayerInput.swift                    # Per-tick controls
│   ├── RaceResult.swift                     # Position, times, stars
│   └── Track.swift                          # Track + Checkpoint + Obstacle
├── Networking/
│   ├── WireMessage.swift                    # Enum wrapping all message types
│   ├── NetworkConnectionProtocol.swift      # Protocol + Real + Mock connections
│   ├── HostSessionManager.swift             # Actor: advertise, accept, broadcast
│   ├── PeerSessionManager.swift             # Actor: browse, connect, send/receive
│   ├── GameStateCodec.swift                 # JSON encode/decode
│   ├── QRCodeGenerator.swift                # CoreImage QR generation
│   └── QRCodeScanner.swift                  # AVFoundation QR scanning
├── Game/
│   ├── RaceEngine.swift                     # @MainActor: physics, checkpoints, results
│   ├── GameSessionViewModel.swift           # @MainActor: state machine, networking glue
│   └── StarRatingCalculator.swift           # Position → stars
├── Entities/
│   ├── Components/
│   │   └── BoostComponent.swift             # ECS: active, cooldown, duration
│   └── Protocols/
│       ├── BikeEntityProtocol.swift         # Components + protocol + MockBike
│       └── TrackEntityProtocol.swift        # Protocol + MockTrack
├── AR/
│   └── ARPlacementViewModel.swift           # ARView wrapper, plane detection, mock track
├── Audio/
│   └── AudioManager.swift                   # System sounds (stub for custom audio)
├── Haptics/
│   └── HapticManager.swift                  # UIImpactFeedbackGenerator (stub)
├── Extensions/
│   ├── Color+Hex.swift                      # Hex string → Color
│   └── SIMD3+Encodable.swift                # SIMD3 helpers
├── UI/
│   ├── RootView.swift                       # NavigationStack root
│   ├── MainMenuView.swift                   # Menu + Multiplayer + LapCount + LetsPlay
│   ├── GameSessionContainerView.swift       # Race container: countdown + HUD + results
│   ├── SurfaceScanView.swift                # AR scan + Settings + FoodDelivered
│   ├── QRScannerView.swift                  # QR scanner + HostLobby
│   ├── Navigation/GameFlowMode.swift        # .solo / .multiplayerHost / .multiplayerPeer
│   ├── Models/LobbyPresentation.swift       # Mock lobby slots + results data
│   ├── Components/
│   │   ├── BackButton.swift                 # Back, gear, title, background, chrome
│   │   └── SharedComponents.swift           # Buttons, panels, joystick, HUD, slots
│   └── Theme/
│       ├── GameColors.swift                 # 25 named colors
│       ├── GameTypography.swift             # 7 fonts + shadow
│       └── MenuButtonStyle.swift            # BeveledButton, OrangeCTA styles
└── ContentView.swift                        # Placeholder (not used in flow)

bikebikeTests/
├── DriverTests.swift
├── GameStateTests.swift
├── GameStateCodecTests.swift
├── WireMessageTests.swift
├── ModelTests.swift
├── StarRatingCalculatorTests.swift
├── RaceEngineTests.swift
├── GameSessionViewModelTests.swift
├── HostSessionManagerTests.swift
├── PeerSessionManagerTests.swift
└── bikebikeTests.swift                      # Xcode template
```

---

## Remaining Work

### 🔴 P6: AR Integration

| Task | Priority | Detail |
|---|---|---|
| Load `.usdz` models | **Critical** | `racetrack.usdz` and `bike-talin.usdz` exist but unused. Wire into `TrackEntity` + `BikeEntity`. |
| Replace mock track with real model | **Critical** | `ARPlacementContainer` places a gray plane. Load USDZ, attach collision shapes to walls/obstacles. |
| Place bikes in AR scene | **Critical** | `GameSessionContainerView` shows no bikes. Add bike entities, position from `RaceEngine` state each tick. |
| Migrate to `SpatialTrackingSession` | Medium | Currently using legacy `ARWorldTrackingConfiguration`. Use iOS 18+ spatial tracking for shadows/occlusion. |
| Manual placement controls | Low | Pinch-to-scale, drag-to-reposition (currently auto-places). |

### 🔴 P7: Wire UI ↔ Engine

| Task | Priority | Detail |
|---|---|---|
| Connect `GameSessionViewModel` to `GameSessionContainerView` | **Critical** | View has local countdown + 5s auto-finish. Replace with ViewModel-driven tick loop, countdown, and finish logic. |
| Feed HUD controls to engine | **Critical** | Joystick/gas/brake/boost update local `@State`. Wire to `viewModel.updateInput(steer:accelerate:boost:)`. |
| Wire lobby slots to real network state | **Critical** | `HostLobbyView` uses hardcoded `LobbySlotPresentation.demo`. Connect to `HostSessionManager` player list + QR endpoint. |
| Wire results to engine output | **Critical** | `FoodDeliveredView` uses `FoodDeliveredRow.sampleRows`. Connect to `RaceEngine` buildResults + GameState. |
| Show discovered hosts in join flow | High | Bonjour browser already works. Expose `PeerSessionManager` discovered hosts in a UI list for manual join. |

### 🟡 P8: Polish

| Task | Priority | Detail |
|---|---|---|
| Custom audio files | Medium | Replace system sounds with `.wav`/`.m4a` via `AVAudioEngine`. Add engine loop, collision, countdown, fanfare. |
| Engine pitch modulation | Low | Vary engine pitch based on bike speed. |
| CoreHaptics patterns | Low | Replace `UIImpactFeedbackGenerator` with `CHHapticEngine`. Add custom patterns for boost, finish, collision. |
| Client-side interpolation | Medium | Peers receive position snapshots at 30 Hz. Add smooth interpolation between ticks for visual smoothness. |
| Race timeout / DNF | Low | 5-minute timeout after leader finishes for stragglers. DNF players get 1 star. |
| Boost visual effects | Low | Speed lines / particle trail when boosting (`ParticleEmitterComponent` on bike entity). |
| Wheel rotation / rider lean | Low | Animate mesh sub-nodes within bike entity based on speed and steering. |

---

## Acceptance Criteria (MVP)

- [x] Player opens app → main menu
- [x] Solo: scan surface → countdown → race with HUD → results
- [x] Multiplayer host: create game → peers join → race → results
- [x] Multiplayer peer: discover → join → lobby → race → results
- [x] Physics: acceleration, steering, speed limits, damping feel arcade-like
- [x] Boost: 2.5s active, 10s cooldown, speed multiplier
- [x] Checkpoints: ordered detection, lap tracking, finish detection
- [x] Results: ranking, stars, times
- [x] Audio: basic system sounds for buttons, countdown, boost, finish
- [x] Haptics: basic impact feedback for buttons, countdown, boost, race start
- [ ] Real `.usdz` track loaded in AR (currently gray plane mock)
- [ ] Bikes visible and moving in AR scene (no bike render)
- [ ] Engine-driven race (GameSessionContainerView uses local timer, not ViewModel)
- [ ] Custom audio files (system sounds only)
- [ ] CoreHaptics patterns (UIImpactFeedbackGenerator only)
