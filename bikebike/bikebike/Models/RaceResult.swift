import Foundation

struct RaceResult: Codable {
    let playerID: UUID
    let nickname: String
    let position: Int
    let totalTime: TimeInterval?
    let bestLapTime: TimeInterval?
    let stars: Int
    let didFinish: Bool
}
