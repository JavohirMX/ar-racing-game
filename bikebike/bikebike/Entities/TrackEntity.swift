import RealityKit
import SwiftUI
import os.log

enum TrackEntityError: Error {
    case loadFailed(String)
}

@MainActor
final class TrackEntity: TrackEntityProtocol {
    private static let logger = Logger(subsystem: "bikebike", category: "TrackEntity")

    let entity: Entity
    let checkpoints: [Entity]
    let finishLine: Entity
    let obstacles: [Entity]
    let appliedScale: Float
    let visualBounds: BoundingBox
    let baseTrack: Track

    private init(
        entity: Entity,
        checkpoints: [Entity],
        finishLine: Entity,
        obstacles: [Entity],
        appliedScale: Float,
        visualBounds: BoundingBox,
        baseTrack: Track
    ) {
        self.entity = entity
        self.checkpoints = checkpoints
        self.finishLine = finishLine
        self.obstacles = obstacles
        self.appliedScale = appliedScale
        self.visualBounds = visualBounds
        self.baseTrack = baseTrack
    }

    static func load(track: Track) async throws -> TrackEntity {
        let loaded: Entity
        if track.modelFileName == OvalTrackGeometry.presetId {
            loaded = ProceduralTrack.makeOvalLoopTrack(scale: 1.0)
            logger.info("Built procedural track '\(OvalTrackGeometry.presetId)'")
        } else {
            let resourceName = track.modelFileName.usdzResourceName
            do {
                loaded = try await loadEntityOffMain(named: resourceName)
                logger.info("Loaded USDZ track '\(resourceName)'")
            } catch {
                logger.error("Failed to load USDZ '\(resourceName)': \(error.localizedDescription)")
                throw error
            }
        }

        let bounds = loaded.visualBounds(relativeTo: nil)
        TrackBoundsHelper.logBounds(bounds, label: track.name)

        let checkpointEntities = track.checkpoints.map { cp in
            let trigger = Entity()
            trigger.position = cp.position
            trigger.name = "checkpoint_\(cp.id)"
            loaded.addChild(trigger)
            return trigger
        }

        let finish = Entity()
        finish.position = track.checkpoints.first { $0.id == 0 }?.position ?? .zero
        finish.name = "finishLine"
        loaded.addChild(finish)

        let obstacleEntities = track.obstacles.map { obs in
            let mesh = MeshResource.generateBox(size: obs.size)
            let obstacle = ModelEntity(
                mesh: mesh,
                materials: [SimpleMaterial(color: .gray, isMetallic: false)]
            )
            obstacle.position = obs.position
            obstacle.transform.rotation = simd_quatf(angle: obs.rotation, axis: [0, 1, 0])
            loaded.addChild(obstacle)
            return obstacle
        }

        return TrackEntity(
            entity: loaded,
            checkpoints: checkpointEntities,
            finishLine: finish,
            obstacles: obstacleEntities,
            appliedScale: 1.0,
            visualBounds: bounds,
            baseTrack: track
        )
    }

    var calibratedTrack: Track {
        baseTrack
    }

    nonisolated private static func loadEntityOffMain(named resourceName: String) async throws -> Entity {
        try await Task.detached {
            try await Entity(named: resourceName)
        }.value
    }
}
