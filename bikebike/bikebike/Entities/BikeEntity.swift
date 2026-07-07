import RealityKit
import Foundation
import os.log

enum BikeEntityError: Error {
    case loadFailed(String)
}

@MainActor
final class BikeEntity: BikeEntityProtocol {
    private static let logger = Logger(subsystem: "bikebike", category: "BikeEntity")

    let entity: Entity
    var input = BikeInputComponent()
    var state: BikeStateComponent
    let driver: Driver

    private init(entity: Entity, driver: Driver, playerID: UUID, nickname: String) {
        self.entity = entity
        self.driver = driver
        self.state = BikeStateComponent(playerID: playerID, nickname: nickname)
    }

    static func load(
        driver: Driver,
        playerID: UUID,
        nickname: String,
        position: SIMD3<Float>
    ) async throws -> BikeEntity {
        await BikeModelLoader.preload()

        let root: Entity
        do {
            root = try BikeModelLoader.makeBike()
            logger.info("Built bike from '\(driver.modelFileName)'")
        } catch {
            logger.error("Failed to build bike: \(error.localizedDescription)")
            throw error
        }

        root.position = position

        return BikeEntity(
            entity: root,
            driver: driver,
            playerID: playerID,
            nickname: nickname
        )
    }

    func applyForwardForce(_ magnitude: Float) {
        let forward = entity.transform.matrix.columns.2
        let direction = -SIMD3<Float>(forward.x, forward.y, forward.z)
        entity.position += direction * magnitude * 0.016
    }

    func applySteeringTorque(_ magnitude: Float) {
        entity.transform.rotation *= simd_quatf(angle: magnitude * 0.016, axis: [0, 1, 0])
    }

    func resetTo(position: SIMD3<Float>, rotation: Float) {
        entity.position = position
        entity.transform.rotation = simd_quatf(angle: rotation, axis: [0, 1, 0])
    }
}
