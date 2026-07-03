import RealityKit
import Foundation


struct BikeInputComponent: Component {
    var steerDirection: Float = 0
    var isAccelerating: Bool = false
    var boostRequested: Bool = false
}

struct BikeStateComponent: Component {
    let playerID: UUID
    let nickname: String
    var currentLap: Int = 0
    var checkpointsHit: [Int] = []
    var hasFinished: Bool = false
    var finishTime: TimeInterval?
}

protocol BikeEntityProtocol: AnyObject {
    var entity: Entity { get }
    var input: BikeInputComponent { get set }
    var state: BikeStateComponent { get set }

    func applyForwardForce(_ magnitude: Float)
    func applySteeringTorque(_ magnitude: Float)
    func resetTo(position: SIMD3<Float>, rotation: Float)
}

final class MockBikeEntity: BikeEntityProtocol {
    let entity: Entity
    var input = BikeInputComponent()
    var state: BikeStateComponent

    init(playerID: UUID, nickname: String, position: SIMD3<Float>) {
        let mesh = MeshResource.generateBox(size: [0.05, 0.05, 0.10])
        self.entity = ModelEntity(mesh: mesh, materials: [])
        self.state = BikeStateComponent(playerID: playerID, nickname: nickname)
        self.entity.position = position
    }

    func applyForwardForce(_ magnitude: Float) {
        let forward = SIMD3<Float>(0, 0, -magnitude)
        entity.position += forward * 0.016
    }

    func applySteeringTorque(_ magnitude: Float) {
        entity.transform.rotation *= simd_quatf(angle: magnitude * 0.016, axis: [0, 1, 0])
    }

    func resetTo(position: SIMD3<Float>, rotation: Float) {
        entity.position = position
        entity.transform.rotation = simd_quatf(angle: rotation, axis: [0, 1, 0])
    }
}
