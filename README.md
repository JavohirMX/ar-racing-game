# AR Racing Game

A local multiplayer augmented reality racing game for iOS. Race as delivery drivers on motorbikes through city-themed tracks placed in the real world — compete with friends to see who finishes first.

## Features

- **Augmented Reality** — Place a 3D city racetrack on any flat surface
- **Local Multiplayer** — Race with up to 6 friends in the same room
- **Solo Mode** — Practice on your own against the clock
- **Delivery Driver Theme** — Choose from 4-6 unique driver/bike skins
- **Arcade Physics** — Drift, boost, and race with forgiving, fun handling
- **Speed Boost** — Tap to activate a temporary speed burst with a cooldown
- **Star Ratings** — Earn 1-5 stars based on your finishing position
- **Haptic Feedback** — Feel collisions, boosts, and the finish line
- **Customizable Sound** — Fun audio effects for engines, boosts, and race events

## Tech Stack

| Technology | Purpose |
|---|---|
| Swift 6 | Language |
| SwiftUI | UI framework (menus, HUD, lobby) |
| RealityKit | 3D rendering, physics, entities |
| ARKit (`SpatialTrackingSession`) | Plane detection, world tracking |
| Network Framework (`NWConnection`, `NWBrowser`, `NWListener`) | Local peer-to-peer multiplayer |
| AVFoundation | Audio playback |
| CoreHaptics | Haptic feedback |


## Requirements

- Xcode 16+
- iOS 18.0+
- Physical device with A12 Bionic or newer (ARKit requires it)

## Quick Start

```bash
# Clone the repo
git clone https://github.com/JavohirMX/ar-racing-game.git
cd ar-racing-game

# Open in Xcode
open ARRacingGame.xcodeproj

# Build and run on a physical iOS device
# (ARKit does not work in the simulator)
```

## Project Structure

```
ARRacingGame/
├── App/            # App entry point, dependency injection
├── Game/           # Race state machine, game logic
├── Entities/       # RealityKit entities and components
├── Networking/     # Network Framework multiplayer manager
├── UI/             # SwiftUI views (menu, lobby, HUD, results)
├── Audio/          # Sound effect manager
├── Haptics/        # Haptic feedback manager
├── Models/         # Data models (Track, Driver, GameState)
└── Resources/      # 3D assets (.usdz), audio files
```

## Documentation

- [Game Design Document](docs/GAME_DESIGN.md) — Gameplay, mechanics, and design
- [Technical Design Document](docs/TECH_DESIGN.md) — Architecture, networking, and implementation
- [Visual Design Document](docs/VISUAL_DESIGN.md) — Art direction, UI, and assets

## Team

**Realitivity** - Ana, Baeni, Ish, Talin, John

---

Built as a fun project at the Apple Developer Academy @ BINUS, Bali.
