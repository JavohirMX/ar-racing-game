import RealityKit
import Foundation

struct BoostComponent: Component {
    var isActive = false
    var cooldownRemaining: TimeInterval = 0
    var boostTimeRemaining: TimeInterval = 0

    let cooldownDuration: TimeInterval = 10.0
    let boostDuration: TimeInterval = 2.5
    let speedMultiplier: Float = 1.5
}
