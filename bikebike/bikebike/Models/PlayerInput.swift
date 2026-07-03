import Foundation

struct PlayerInput: Codable {
    let tick: UInt32
    let steerDirection: Float
    let accelerate: Bool
    let boostActivated: Bool
}
