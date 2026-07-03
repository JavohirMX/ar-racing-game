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
    let startRotation: Float
    let checkpoints: [Checkpoint]
    let obstacles: [Obstacle]
}

struct Checkpoint: Codable {
    let id: Int
    let position: SIMD3<Float>
    let radius: Float
}

struct Obstacle: Codable {
    let position: SIMD3<Float>
    let size: SIMD3<Float>
    let rotation: Float
    let type: ObstacleType
}

enum ObstacleType: String, Codable {
    case building
    case barrier
    case cone
    case parkedCar
}

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
            Checkpoint(id: 0, position: SIMD3<Float>(0.0, 0.0, 0.0), radius: 0.05),
            Checkpoint(id: 1, position: SIMD3<Float>(0.0, 0.0, -0.5), radius: 0.05),
        ],
        obstacles: []
    )
}
