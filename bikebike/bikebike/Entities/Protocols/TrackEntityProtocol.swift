import RealityKit
import SwiftUI

protocol TrackEntityProtocol: AnyObject {
    var entity: Entity { get }
    var checkpoints: [Entity] { get }
    var finishLine: Entity { get }
    var obstacles: [Entity] { get }
}

final class MockTrackEntity: TrackEntityProtocol {
    let entity: Entity
    let checkpoints: [Entity]
    let finishLine: Entity
    let obstacles: [Entity]

    init(track: Track) {
        let root = Entity()

        let floor = ModelEntity(
            mesh: .generatePlane(width: 1.0, depth: 1.5),
            materials: [SimpleMaterial(color: .darkGray, isMetallic: false)]
        )
        root.addChild(floor)

        self.checkpoints = track.checkpoints.map { cp in
            let trigger = Entity()
            trigger.position = cp.position
            trigger.name = "checkpoint_\(cp.id)"
            root.addChild(trigger)
            return trigger
        }

        self.finishLine = Entity()
        self.finishLine.position = track.checkpoints.first { $0.id == 0 }?.position ?? .zero
        self.finishLine.name = "finishLine"
        root.addChild(finishLine)

        self.obstacles = track.obstacles.map { obs in
            let mesh = MeshResource.generateBox(size: obs.size)
            let entity = ModelEntity(
                mesh: mesh,
                materials: [SimpleMaterial(color: .gray, isMetallic: false)]
            )
            entity.position = obs.position
            entity.transform.rotation = simd_quatf(angle: obs.rotation, axis: [0, 1, 0])
            root.addChild(entity)
            return entity
        }

        self.entity = root
    }
}
