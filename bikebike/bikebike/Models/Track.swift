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
        name: "Oval Loop",
        description: "Stadium oval tabletop track",
        defaultLaps: 3,
        minLaps: 1,
        maxLaps: 5,
        modelFileName: OvalTrackGeometry.presetId,
        startPosition: OvalTrackGeometry.startGridOffset,
        startRotation: OvalTrackGeometry.startRotation,
        checkpoints: [
            OvalTrackGeometry.finishCheckpoint,
            OvalTrackGeometry.halfwayCheckpoint,
        ],
        obstacles: []
    )
}
