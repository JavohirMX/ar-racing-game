//
//  ProceduralTrack.swift
//  bikebike
//

import RealityKit
import UIKit

enum ProceduralTrack {
    static var presetId: String { OvalTrackGeometry.presetId }
    static var startGridOffset: SIMD3<Float> { OvalTrackGeometry.startGridOffset }

    /// Stadium-oval loop track (~0.8m × 0.5m).
    static func makeOvalLoopTrack(scale: Float = 1.0) -> Entity {
        let root = Entity()
        root.name = "TrackRoot"
        root.scale = SIMD3(repeating: scale)

        let segments = OvalTrackGeometry.segmentCount
        let floorY = OvalTrackGeometry.floorThickness / 2
        let wallY = OvalTrackGeometry.wallHeight / 2 + OvalTrackGeometry.floorThickness

        let floor = TrackMeshBuilder.makeAnnulusFloorEntity(segments: segments)
        root.addChild(floor)

        for index in 0..<segments {
            let t0 = Float(index) / Float(segments)
            let t1 = Float(index + 1) / Float(segments)

            let e0 = OvalTrackGeometry.trackEdges(at: t0)
            let e1 = OvalTrackGeometry.trackEdges(at: t1)
            let c0 = e0.center
            let c1 = e1.center

            let curbColor: UIColor = index.isMultiple(of: 2) ? .systemRed : .white
            addCurbWall(from: e0.inner, to: e1.inner, wallY: wallY, color: curbColor, name: "InnerWall\(index)", root: root)
            addCurbWall(from: e0.outer, to: e1.outer, wallY: wallY, color: curbColor, name: "OuterWall\(index)", root: root)

            if index.isMultiple(of: 4) {
                let yaw = atan2(c1.y - c0.y, c1.x - c0.x)
                let dash = makeVisualBox(
                    size: SIMD3(0.02, 0.003, 0.008),
                    color: .white,
                    position: SIMD3(c0.x, floorY + 0.004, c0.y),
                    roughness: 0.3
                )
                dash.orientation = simd_quatf(angle: -yaw, axis: SIMD3(0, 1, 0))
                root.addChild(dash)
            }
        }

        let finishPoint = OvalTrackGeometry.centerlinePoint(t: OvalTrackGeometry.finishLineParameter)
        let finishTangent = OvalTrackGeometry.centerlineTangent(t: OvalTrackGeometry.finishLineParameter)
        let finishYaw = atan2(finishTangent.y, finishTangent.x)

        let finishLine = makeVisualBox(
            size: SIMD3(OvalTrackGeometry.trackWidth, 0.05, 0.02),
            color: .white,
            position: SIMD3(finishPoint.x, 0.03, finishPoint.y)
        )
        finishLine.name = "FinishLine"
        finishLine.orientation = simd_quatf(angle: -finishYaw + .pi / 2, axis: SIMD3(0, 1, 0))
        root.addChild(finishLine)

        let spawnT = max(0, OvalTrackGeometry.finishLineParameter - 0.035)
        let spawnEdges = OvalTrackGeometry.trackEdges(at: spawnT)
        for (index, offset) in [(Float(-0.04), UIColor.systemGreen), (Float(0.0), UIColor.systemGreen), (Float(0.04), UIColor(white: 0.9, alpha: 1))].enumerated() {
            let tangent = OvalTrackGeometry.centerlineTangent(t: spawnT)
            let stripeCenter = spawnEdges.center + spawnEdges.right * offset.0
            let yaw = atan2(tangent.y, tangent.x)

            let stripe = makeVisualBox(
                size: SIMD3(0.035, 0.01, 0.06),
                color: offset.1,
                position: SIMD3(stripeCenter.x, 0.012, stripeCenter.y)
            )
            stripe.name = "StartGrid\(index)"
            stripe.orientation = simd_quatf(angle: -yaw, axis: SIMD3(0, 1, 0))
            root.addChild(stripe)
        }

        return root
    }

    // MARK: - Builders

    private static func addCurbWall(
        from start: SIMD2<Float>,
        to end: SIMD2<Float>,
        wallY: Float,
        color: UIColor,
        name: String,
        root: Entity
    ) {
        let midpoint = (start + end) / 2
        let edgeVector = end - start
        let length = max(simd_length(edgeVector), 0.012)
        let yaw = atan2(edgeVector.y, edgeVector.x)

        let wall = makeVisualBox(
            size: SIMD3(length, OvalTrackGeometry.wallHeight, OvalTrackGeometry.wallThickness),
            color: color,
            position: SIMD3(midpoint.x, wallY, midpoint.y)
        )
        wall.name = name
        wall.orientation = simd_quatf(angle: -yaw, axis: SIMD3(0, 1, 0))
        root.addChild(wall)
    }

    private static func makeVisualBox(
        size: SIMD3<Float>,
        color: UIColor,
        position: SIMD3<Float>,
        isMetallic: Bool = false,
        roughness: MaterialScalarParameter = 0.35
    ) -> ModelEntity {
        let mesh = MeshResource.generateBox(size: size)
        let material = SimpleMaterial(color: color, roughness: roughness, isMetallic: isMetallic)
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.position = position
        return entity
    }
}
