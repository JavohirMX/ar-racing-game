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
    let rotation: Float
    let speed: Float
    let lap: Int
    let checkpointsHit: [Int]
    let boostAvailable: Bool
    let boostActive: Bool
    let finished: Bool
    let finishTime: TimeInterval?
}
