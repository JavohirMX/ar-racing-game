# Game Design Document

## Overview

**Bike Bike** is a local multiplayer augmented reality racing game where players control delivery drivers on motorbikes. Races take place on 3D city-themed tracks placed on real-world flat surfaces via AR. The first player to complete all laps wins.

### Quick Reference

| Attribute | Value |
|---|---|
| Genre | Arcade Racing |
| Platform | iOS 18+ (physical device) |
| Players | 1 (solo) or 2-6 (multiplayer) |
| Race duration | ~1-4 minutes (depends on track & laps) |
| Perspective | Top-down / isometric AR view |

---

## Core Loop

```
┌─────────────┐
│  Main Menu  │
└──────┬──────┘
       ▼
┌─────────────────┐
│  Select Mode    │──► Solo ──┐
│  (Solo / Multi) │──► Multi ─┐
└─────────────────┘           │
       ◄──────────────────────┘
       ▼
┌─────────────────┐
│  Select Track   │  (2-3 city-themed tracks)
│  Select Laps    │  (custom lap count)
│  Select Driver  │  (4-6 delivery driver skins)
└────────┬────────┘
         ▼
┌─────────────────┐
│  Surface Scan   │  (detect flat surface via ARKit)
│  Place Track    │  (host places, peers join)
└────────┬────────┘
         ▼
┌─────────────────┐
│     Lobby       │  (auto-discover or QR join)
│  (multi only)   │
└────────┬────────┘
         ▼
┌─────────────────┐
│   3-2-1-GO!     │  (countdown)
└────────┬────────┘
         ▼
┌─────────────────┐
│     RACE        │  ◄─── Core gameplay
└────────┬────────┘
         ▼
┌─────────────────┐
│    Results      │  (star rating, positions, times)
└─────────────────┘
```

---

## Game Modes

### Solo Mode
Practice on any track without opponents. No networking required. The player races against the clock and receives a star rating based on completion time.

### Multiplayer Mode
Race against 2-6 players in the same room. One device hosts (places the track) and others join via Bonjour auto-discovery or QR code.

---

## Controls

On-screen controls overlaid on the AR view:

| Control | Position | Action |
|---|---|---|
| Left Arrow | Bottom-left | Steer the bike left |
| Right Arrow | Bottom-right | Steer the bike right |
| Accelerate Pedal | Bottom-center | Hold to accelerate forward |
| Boost Button | Bottom-center (above accel) | Tap to activate speed boost |

Controls are semi-transparent to avoid obstructing the AR view. Layout adapts to screen size.

---

## Bikes & Drivers

### Handling Model (Arcade)
- Instant acceleration (no realistic inertia)
- High grip — bikes stick to the track
- Forgiving collisions — bounce off walls and obstacles with minimal speed loss
- Drifting enabled via angular damping on turns

### Driver Skins (4-6)
Each driver is a unique delivery rider with a distinct bright color. All have identical stats — purely cosmetic.

| Driver | Color | Theme |
|---|---|---|
| Go-Send | Green (#34C759) | Food delivery backpack |
| Grab-Food | Orange (#FF9500) | Thermal bag |
| Shopee | Pink (#FF375F) | Parcel box |
| Lalamove | Purple (#AF52DE) | Cargo crate |
| Maxim | Blue (#007AFF) | Courier satchel |
| Ninja | Yellow (#FFCC00) | Express pouch |

### Bike Model
Low-poly motorbike with rider. Rider has a visible delivery bag/box as the distinguishing feature. Built in Blender, exported as `.usdz`.

---

## Tracks

### Design
2-3 pre-built city-themed tracks created in Blender and exported as `.usdz` RealityKit scenes.

### Track Features
- Asphalt road surface with lane markings
- Buildings, parked cars, barriers, and cones as **static obstacles**
- Start/finish line with checkered markings
- Curbs and sidewalk edges define track boundaries
- Configurable number of laps per race

### Placement
The host player scans a flat surface with their device camera, then places the track at the desired position, scale, and rotation in the AR world. Once confirmed, the track is locked and shared with all connected peers.

### Example Tracks
1. **Downtown Dash** — Tight city streets with sharp corners
2. **Market Run** — Wider roads with market stall obstacles
3. **Harbor Sprint** — Open track with sparse obstacles

---

## Speed Boost

### Mechanics
- Each player has one boost charge
- **Tap** the boost button to activate
- Boost increases speed by ~50% for 2-3 seconds
- After use, boost enters **cooldown** (~10 seconds)
- Visual feedback: speed lines / particle trail behind the bike
- Audio: "whoosh" sound effect
- Haptic: sharp buzz on activation

---

## Win Condition & Scoring

### Winning
- First player to cross the finish line after completing all laps wins
- Race ends when all players finish (or after a timeout)

### Star Rating (1-5 stars)
| Stars | Criteria |
|---|---|
| 5 ★★★★★ | 1st place |
| 4 ★★★★☆ | 2nd place |
| 3 ★★★☆☆ | 3rd place |
| 2 ★★☆☆☆ | 4th place |
| 1 ★☆☆☆☆ | 5th-6th place or DNF |

---

## Multiplayer Flow

### Session Lifecycle

```
Host                          Peer(s)
  │                              │
  │  Start session               │
  │  (NWListener advertises)     │
  │                              │  Join session
  │◄─────────────────────────────│  (NWBrowser discovers host)
  │                              │
  │  Host places track ──────────│──► Track synced to peers
  │                              │
  │  Lobby (all players listed)  │
  │  Min 2 players to start      │
  │                              │
  │  3... 2... 1... GO!          │
  │                              │
  │═══════ RACE =════════════════│
  │  Host runs game state        │  Peers send input, render state
  │                              │
  │  Race ends                   │
  │  Results screen              │
  │                              │
  └──────────────────────────────┘
```

### Host Authority
- Host owns the track placement and race state machine
- Host receives input from all peers
- Host sends game state update (positions, lap counts, boost status) to all peers every tick
- Peers render received state locally

### Host Migration
If the host disconnects mid-race:
1. All peers detect the disconnection
2. The peer with the lowest `MCPeerID` hash (or equivalent tie-breaker) becomes the new host
3. All peers reconnect to the new host
4. Race resumes from last known good state

### Joining Methods
1. **Auto-Discovery** — `NWBrowser` finds hosts advertising on the local network via Bonjour
2. **QR Code** — Host displays a QR code encoding their Bonjour endpoint. Peers scan to connect (fallback for when auto-discovery fails)

---

## Haptics

| Event | Haptic Style | Intensity |
|---|---|---|
| Collision with wall/obstacle | Impact | Medium |
| Boost activation | Sharp transient | High |
| Crossing finish line | Long notification success | High |
| Countdown tick | Light tap | Low |
| GO! start | Heavy impact | High |

---

## Audio

| Event | Sound |
|---|---|
| Engine idle | Looping hum (per bike variant) |
| Accelerating | Pitch-shifted engine loop |
| Boost | Whoosh + pitch rise |
| Collision | Metal scrape / thud |
| Countdown | Beep (x3) → Horn blast for "GO!" |
| Finish line | Cheer / fanfare |
| UI navigation | Subtle click / tap |

Sound effects are customizable — players can toggle individual sounds or adjust master volume.

---

## Edge Cases & Error Handling

| Scenario | Handling |
|---|---|
| No flat surface found | Show guidance UI: "Move your device slowly over a flat surface" |
| Surface lost during race | Pause race, show "Surface lost — please look at the track" |
| Host disconnects | Host migration to next peer |
| Peer disconnects | Remaining players continue, disconnected player's bike vanishes |
| All peers disconnect | Convert to solo mode, finish the race |
| App backgrounded | Pause race, resume on foreground return |
| Device sleep | Prevent auto-lock during race |
