//
//  BikeModelLoader.swift
//  bikebike
//

import Foundation
import RealityKit
import os.log

@MainActor
enum BikeModelLoader {
    private static let logger = Logger(subsystem: "bikebike", category: "BikeModelLoader")
    private static let modelName = "bike-talin"

    /// Scale the bike footprint relative to the drive collider size.
    private static let visualFitScale: Float = 1.35
    /// Blender export arrives pitched backward; stand it upright before fitting.
    private static let bikePitchOffset: Float = -.pi / 2
    private static let bikeYawOffset: Float = 0
    private static let bikeLift: Float = -0.002

    private static var templateEntity: Entity?
    private static var preloadTask: Task<Void, Never>?

    static var isReady: Bool { templateEntity != nil }

    static func preload() async {
        if templateEntity != nil {
            return
        }

        if let preloadTask {
            await preloadTask.value
            return
        }

        let task = Task { @MainActor in
            defer { preloadTask = nil }

            do {
                let loaded = try await loadTemplateEntity()
                templateEntity = loaded
                logger.info("Preloaded bike model '\(modelName)'")
            } catch {
                logger.error("Bike preload failed: \(error.localizedDescription)")
            }
        }

        preloadTask = task
        await task.value
    }

    static func makeBike() throws -> Entity {
        guard let templateEntity else {
            throw BikeEntityError.loadFailed("Bike model '\(modelName)' is not preloaded")
        }

        let root = Entity()
        root.name = "Bike"

        let visual = templateEntity.clone(recursive: true)
        prepareVisualEntity(visual)
        root.addChild(visual)
        return root
    }

    private static func loadTemplateEntity() async throws -> Entity {
        try await Task.detached {
            try await Entity(named: modelName)
        }.value
    }

    private static var bikeOrientation: simd_quatf {
        let pitch = simd_quatf(angle: bikePitchOffset, axis: SIMD3(1, 0, 0))
        let yaw = simd_quatf(angle: bikeYawOffset, axis: SIMD3(0, 1, 0))
        return yaw * pitch
    }

    private static func prepareVisualEntity(_ visual: Entity) {
        visual.orientation = bikeOrientation

        let orientedBounds = visual.visualBounds(relativeTo: nil)
        let extents = orientedBounds.extents
        guard max(extents.x, extents.z) > 0.0001 else { return }

        let targetWidth = OvalTrackGeometry.vehicleSize.x * visualFitScale
        let targetLength = OvalTrackGeometry.vehicleSize.z * visualFitScale
        let scale = min(
            targetWidth / max(extents.x, 0.0001),
            targetLength / max(extents.z, 0.0001)
        )

        visual.scale = SIMD3(repeating: scale)

        let bounds = visual.visualBounds(relativeTo: nil)
        let minY = bounds.center.y - bounds.extents.y / 2
        visual.position = SIMD3(-bounds.center.x, -minY + bikeLift, -bounds.center.z)
    }
}
