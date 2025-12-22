# GamesmanAR

GamesmanAR brings physical board games into the augmented reality era. Point your iPhone at a game board to see coordinate frames, position tracking, and interactive overlays rendered directly on the physical playing surface.

## Overview

This iOS app uses ARKit and OpenCV to detect and track ArUco markers in real-time, creating a foundation for augmented reality gameplay. It distinguishes between fixed board markers that define the coordinate system and dynamic piece markers that move during play.

## Features

- **Dual-marker system** – Board markers (50mm) establish the coordinate frame; piece markers (25mm) track game pieces
- **Real-time pose estimation** – Detects marker positions and orientations at camera frame rate
- **Visual coordinate frames** – RGB axes (X=red, Y=green, Z=blue) overlaid on each marker
- **Position labels** – Displays coordinates in centimeters relative to board origin
- **AR grid overlay** – Interactive dot grid rendered on the game surface with 5cm spacing
- **Multi-marker averaging** – Stabilizes tracking by averaging across all visible board markers
- **Automatic cleanup** – Removes markers from scene after 1 second of being unseen

## Setup

### Requirements
- iOS device with ARKit support (iPhone 6s or newer)
- Xcode 14+
- OpenCV framework with ArUco module

### Marker Preparation
Print ArUco markers at these exact physical sizes:
- **Board markers**: 50mm × 50mm (IDs: 666, 669, 66, 69)
- **Piece markers**: 25mm × 25mm (any other IDs)

### Board Layout
Place the four board markers at corners to define a 15cm × 15cm coordinate system:

```
66 (0, 15cm) ──────── 69 (15cm, 15cm)
    │                     │
    │     Playing         │
    │      Surface        │
    │                     │
666 (0, 0)  ──────── 669 (15cm, 0)
```

## How It Works

### Architecture

**ARController** – Manages ARKit session and delegates frame processing
```swift
- ARSCNView setup with world tracking
- Horizontal plane detection enabled
- Per-frame marker detection and pose estimation
```

**Coordinator** – Core AR logic and state management
```swift
- Detects board vs. piece markers based on size
- Computes world and board-relative transforms
- Updates scene nodes with smooth animations
- Manages node lifecycle (create/update/cleanup)
```

**ArucoNode** – Visual representation of detected markers
```swift
- RGB coordinate frame visualization
- Billboard-constrained position labels
- Scales based on marker type (board vs. piece)
```

**AROverlay** – Grid visualization system
```swift
- Generates dots every 5cm across board surface
- Averages position/rotation across visible board markers
- Dynamically creates/removes nodes as board moves
```

**ArucoCV Bridge** – OpenCV integration (Objective-C++)
```swift
- ArUco marker detection and pose estimation
- Returns transforms with marker IDs
- Separate detection for different marker sizes
```

### Position Estimation Algorithm

For each piece marker:
1. Detect marker pose in camera space using OpenCV
2. Transform to world space using ARKit camera transform
3. For each visible board marker:
   - Compute piece position in that board marker's local space
   - Add board marker's known position offset
4. Average all computed positions for stability
5. Display result in centimeters

### Performance Optimizations

- **Mutex locking** prevents concurrent frame processing
- **Background queue** offloads CV operations from main thread
- **Temporal filtering** via 0.1s animation smooths jitter
- **Automatic pruning** removes unseen markers after 1 second

## Configuration

Edit `AppDelegate.swift` to customize:

```swift
// Marker physical sizes (meters)
static let BoardMarkerSize = 0.050  // 50mm
static let PieceMarkerSize = 0.025  // 25mm

// Board marker positions (meters)
static let FixedMarkerDict = [
    666: (x: 0.0,  y: 0.0,  z: 0.0),    // Origin
    669: (x: 0.15, y: 0.0,  z: 0.0),    // +X corner
    66:  (x: 0.0,  y: 0.15, z: 0.0),    // +Y corner
    69:  (x: 0.15, y: 0.15, z: 0.0),    // Diagonal corner
]
```

## Usage

1. Launch app on ARKit-capable device
2. Point camera at prepared game board with markers
3. Observe coordinate frames appear on markers
4. Watch position labels update as pieces move
5. See AR grid overlay on the playing surface

## Project Structure

```
GamesmanAR/swift
├── AppDelegate.swift      # App entry point and SwiftUI views
├── ARController.swift     # ARKit integration and session management
├── ArucoNode.swift        # Marker visualization nodes
├── AROverlay.swift        # Grid overlay system
└── ArucoCV/               # OpenCV bridge (not included)
```

## Roadmap

- [ ] Connect to GamesmanUni solver API
- [ ] Display optimal move arrows overlaid on board
- [ ] Support custom board sizes and marker layouts
- [ ] Game state detection from piece positions
- [ ] Multi-game configuration presets
- [ ] Move history visualization
- [ ] App Store deployment

## Part of GamesPlane

GamesmanAR is the mobile AR component of **GamesPlane**, a project bringing Gamesman's perfect-play solving capabilities to physical board games through computer vision and augmented reality.

---

*Developed by Josh Zhang as part of the UC Berkeley GamesCrafters research group*
