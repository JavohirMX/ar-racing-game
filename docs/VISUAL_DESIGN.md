# Visual Design Document

## Art Direction

**Vibrant, playful, low-poly city arcade.** The visual style should feel energetic and fun — think toy cars racing through a miniature city. Clean geometry, saturated colours, and clear readability take priority over realism.

### Keywords
Playful, energetic, readable, bright, toy-like, friendly

### References
- Monument Valley (isometric toy-world aesthetic)
- Mario Kart (colour-coded racers, readable UI)
- Lego City (blocky, colourful urban environments)

---

## Colour Palette

### Track & Environment

| Element | Color | Hex | Notes |
|---|---|---|---|
| Road surface | Dark gray | `#3A3A3C` | Asphalt with subtle noise texture |
| Lane markings | White | `#FFFFFF` | Dashed center line |
| Sidewalks | Light gray | `#8E8E93` | Raised curb edges |
| Roadside green | Green | `#34C759` | Grass strips, trees |
| Buildings | Warm beige | `#E8D5B7` | Base building color |
| Building accents | Varied | — | Awnings, signs, doors in accent colours |
| Sky (AR pass-through) | Real world | — | The real environment shows through |

### Drivers (by team)

| Driver | Primary | Secondary | Delivery Bag |
|---|---|---|---|
| Go-Send | `#34C759` Green | `#FFFFFF` White | Green backpack |
| Grab-Food | `#FF9500` Orange | `#FFFFFF` White | Orange thermal bag |
| Shopee | `#FF375F` Pink | `#FFFFFF` White | Pink parcel box |
| Lalamove | `#AF52DE` Purple | `#FFFFFF` White | Purple cargo crate |
| Maxim | `#007AFF` Blue | `#FFFFFF` White | Blue courier satchel |
| Ninja | `#FFCC00` Yellow | `#000000` Black | Yellow express pouch |

### UI Palette

| Element | Color | Hex | Purpose |
|---|---|---|---|
| Background (overlay) | Dark translucent | `#000000` @ 70% | HUD, panels |
| Primary text | White | `#FFFFFF` | Labels, names |
| Secondary text | Light gray | `#C7C7CC` | Subtitles, hints |
| Accent | Electric Blue | `#007AFF` | Buttons, active states |
| Warning | Yellow-Orange | `#FF9500` | Countdown urgency |
| Success | Green | `#34C759` | Finish, ready states |
| Boost gauge fill | Gradient | `#FF375F` → `#FF9500` | Boost cooldown indicator |

---

## Typography

| Usage | Font | Weight | Size |
|---|---|---|---|
| Title text | SF Pro Rounded | Bold | 28pt |
| HUD labels | SF Pro Rounded | Semibold | 16pt |
| Body text | SF Pro Rounded | Regular | 14pt |
| Countdown numbers | SF Pro Rounded | Heavy | 64pt |
| Lap counter | SF Mono | Bold | 18pt |
| Position indicator | SF Pro Rounded | Bold | 20pt |

All game UI uses **SF Pro Rounded** for its friendly, game-like feel. System fonts — no custom font imports.

---

## Screens & UI

### Main Menu

```
┌──────────────────────────┐
│                          │
│     🏍️  Bike Bike       │
│                          │
│   [   SOLO RACE   ]     │
│   [  MULTIPLAYER  ]     │
│   [   SETTINGS    ]     │
│                          │
│     v1.0 · Bike Bike    │
└──────────────────────────┘
```

- Centered logo/title at top third
- Large rounded buttons with primary colour fill
- Subtle animated background (rotating 3D bike preview)
- Haptic tap on button press

### Driver Select

```
┌──────────────────────────┐
│   Select Your Driver     │
│                          │
│  ┌──┐ ┌──┐ ┌──┐ ┌──┐   │
│  │G │ │O │ │P │ │P │   │
│  │R │ │R │ │I │ │U │   │
│  │N │ │NG│ │NK│ │RP│   │
│  └──┘ └──┘ └──┘ └──┘   │
│  ┌──┐ ┌──┐              │
│  │B │ │Y │              │
│  │LU│ │EL│              │
│  │  │ │L │              │
│  └──┘ └──┘              │
│                          │
│   [  CONFIRM DRIVER  ]  │
└──────────────────────────┘
```

- Grid of driver cards (2 columns × 3 rows)
- Each card: colour swatch, driver name, small bike preview
- Selected card has ring highlight in driver's colour
- Taken drivers show as dimmed + player name (multiplayer only)

### Track Select

```
┌──────────────────────────┐
│   Select Track           │
│                          │
│  ┌──────────────────┐   │
│  │  Downtown Dash   │   │
│  │  Tight city st.  │   │
│  │  Preview render  │   │
│  └──────────────────┘   │
│  ┌──────────────────┐   │
│  │  Market Run      │   │
│  │  Market stalls   │   │
│  └──────────────────┘   │
│                          │
│   Laps: [ -  3  + ]     │
│                          │
│   [  START RACE  ]      │
└──────────────────────────┘
```

- Horizontal scrolling track cards with rendered preview
- Stepper control for lap count (1-9)
- Start button only enabled once driver and track are selected

### Surface Scan / Track Placement

```
┌──────────────────────────┐
│  (Full camera AR view)   │
│                          │
│   ┌──────────────────┐  │
│   │ Move device over │  │
│   │ a flat surface   │  │
│   └──────────────────┘  │
│                          │
│   [Detected plane grid] │
│                          │
│   Track preview ghost   │
│                          │
│   [  CONFIRM PLACE  ]   │
└──────────────────────────┘
```

- Full-screen `RealityView` with camera passthrough
- Detected planes rendered as semi-transparent grid
- Track appears as translucent ghost until confirmed
- Pinch to scale, two-finger rotate, drag to reposition
- "Confirm Place" button appears once on a valid surface

### Multiplayer Lobby

```
┌──────────────────────────┐
│   Race Lobby        3/6  │
│                          │
│   Host:  Javohir ✓      │
│   ┌─────────────────┐   │
│   │ 🟢 John (GoSend)│   │
│   │ 🟠 Talin (Grab) │   │
│   │ ⚪ Waiting...    │   │
│   │ ⚪ Waiting...    │   │
│   │ ⚪ Waiting...    │   │
│   │ ⚪ Waiting...    │   │
│   └─────────────────┘   │
│                          │
│ Join with QR:  [QR ▣]   │
│                          │
│   [  START RACE  ]      │
│       (host only)        │
└──────────────────────────┘
```

- Host has QR code toggle
- Connected peers show green dot + driver icon
- Empty slots show gray waiting indicator
- Start button visible only to host, only when ≥ 2 players
- Peers see "Waiting for host to start..."

### HUD (During Race)

```
┌─────┬──────────────────┬──────┐
│ MINI│  Lap 2/3         │ 1st  │
│ MAP │                  │ ▲    │
│     │                  │      │
│     │                  │      │
│     │                  │      │
│     │                  │      │
│     │                  │      │
│     │                  │      │
│     │                  │      │
│     │    (AR view)     │      │
│     │                  │      │
│     │                  │      │
│     │                  │      │
│     │                  │      │
│     │                  │      │
│     │                  │      │
│     │                  │      │
│     │                  │      │
├─────┴──────────────────┴──────┤
│ ◄          [BOOST]         ► │
│               ▲               │
│          ACCELERATE           │
└──────────────────────────────┘
```

| Element | Position | Description |
|---|---|---|
| Minimap | Top-left | Small top-down view of track with dot for each player |
| Lap counter | Top-center | Current lap / total laps |
| Position | Top-right | Current position with arrow indicator |
| Boost button | Bottom-center | Shows cooldown ring fill, tap to activate |
| Accelerate | Bottom-center | Large pedal, press and hold |
| Left/Right | Bottom-left/right | Steer buttons |

- HUD elements are semi-transparent (`0.7` opacity black background)
- Boost button shows radial cooldown animation (ring fills clockwise)
- Minimap updates in real-time showing all player positions

### Countdown Overlay

```
┌──────────────────────────┐
│                          │
│                          │
│                          │
│          3               │
│                          │
│                          │
│                          │
└──────────────────────────┘
```

- Large number centered on screen (64pt bold)
- Scale animation: grows then shrinks ("pulse")
- Each tick: light haptic tap
- "3" → "2" → "1" with 1-second interval
- "GO!" shown for 0.5s in green, heavy haptic impact + horn sound
- Overlay fades out as race begins

### Results Screen

```
┌──────────────────────────┐
│    🏁 Race Complete!     │
│                          │
│  1st ★★★★★  John      │
│      1:23.4  Go-Send    │
│                          │
│  2nd ★★★★☆  Javohir   │
│      1:25.1  Grab-Food   │
│                          │
│  3rd ★★★☆☆  Talin │
│      1:30.8  Shopee      │
│                          │
│  [  PLAY AGAIN  ]       │
│  [  MAIN MENU  ]       │
└──────────────────────────┘
```

- Finishing positions listed in order
- Each row: position, star rating (graphical stars), player name, time, driver icon
- Winner row highlighted with subtle glow/border
- Two action buttons at bottom

---

## 3D Asset Specifications

### Motorbike + Rider
- **Poly count**: ~500-800 triangles (low-poly)
- **Style**: Flat/solid shading, no textures (vertex colours only)
- **Parts**: Two wheels, frame, handlebars, seat, rider figure, delivery bag
- **Scale**: ~0.15m in AR world (to fit on ~0.5m–1m wide tracks)
- **Animation**: Wheels rotate based on speed, rider leans on turns
- **Format**: `.usdz` exported from Blender

### Track
- **Poly count**: ~2000-4000 triangles total
- **Components**: Road mesh, sidewalk edges, buildings (separate meshes)
- **Scale**: ~1m × 1.5m in AR world
- **Obstacles**: Parked cars (~200 tris each), barriers (~50 tris), cones (~30 tris)
- **Start/Finish**: Checkered plane across the track
- **Format**: `.usdz` (single file with child entities)

### Building (Obstacle)
- **Poly count**: ~200-400 triangles
- **Style**: Simple boxes with roof variations, coloured awnings
- **Placement**: Along track edges, occasional ones protruding onto roads

### Boost Visual Effect
- **Particle trail**: Orange/red particles emitted behind the bike during boost
- **Duration**: 2.5 seconds (matches boost duration)
- **Technique**: RealityKit `ParticleEmitterComponent`

---

## Animation

| Animation | Trigger | Duration | Style |
|---|---|---|---|
| Wheel spin | Bike moving | Continuous | Rotate wheel meshes at speed × factor |
| Rider lean | Steering input | Instant | Tilt rider mesh ±15° on Z-axis |
| Boost particle trail | Boost active | 2.5s | Particle emitter behind exhaust |
| Countdown pulse | Each second of countdown | 0.3s | Scale from 1.0 → 1.3 → 1.0 |
| Finish line flash | Player crosses | 1.0s | Checkered pattern colour pulse |
| Star fill | Results screen | 0.3s each | Stars fill left to right with spring animation |
| Track place confirm | User taps confirm | 0.5s | Track ghost fades to solid with subtle scale up |

---

## Sound Design

| Event | Sound Description | Type |
|---|---|---|
| Engine idle | Low buzzing hum, slight uneven rev | Looping |
| Engine accelerating | Pitch-shifted hum rising with speed | Dynamic pitch |
| Boost activated | Rising whoosh + pitch jump | One-shot |
| Boost cooldown ready | Soft chime | One-shot |
| Collision (wall) | Metallic scrape | One-shot |
| Collision (obstacle) | Hollow thud | One-shot |
| Countdown tick | Quick beep, rising in pitch (3 low → 1 high) | One-shot × 3 |
| GO! | Short horn blast | One-shot |
| Finish line | Cheering crowd + short musical sting | One-shot |
| UI button press | Subtle click | One-shot |
| Menu music | Light, upbeat lo-fi loop | Looping (optional) |

- All sounds in `.m4a` or `.wav` format
- Engine sound pitch: `1.0` (idle) to `1.8` (max speed)
- Master volume slider in settings (0-100%)
- Per-sound toggle in settings

---

## Accessibility

| Feature | Implementation |
|---|---|
| High contrast mode | Thicker outlines on HUD elements, higher opacity backgrounds |
| Colour-blind support | Driver differentiation by shape (bag style) not just colour |
| Scalable UI | HUD respects Dynamic Type for labels |
| Audio cues | Critical events (countdown, GO, finish) have distinct audio |
| Reduced motion | Option to disable screen shake and particle effects |

---

## Icon & Branding

### App Icon
- Circular icon with a stylised motorbike silhouette
- Background: gradient from dark blue to purple (evening delivery vibe)
- Bike: white silhouette with one coloured delivery bag accent

### Colour Reference
| Role | Hex |
|---|---|
| App icon background | `#1C1C2E` → `#3A1C5E` gradient |
| App icon bike | `#FFFFFF` white |
| App icon accent | `#FF9500` orange stripe on bag |
