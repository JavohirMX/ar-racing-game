//
//  TrackMeshBuilder.swift
//  bikebike
//

import RealityKit
import UIKit

enum TrackMeshBuilder {
    /// Single merged annulus floor mesh built from trapezoid quads along inner/outer edges.
    static func makeAnnulusFloorEntity(segments: Int = OvalTrackGeometry.segmentCount) -> ModelEntity {
        let floorY = OvalTrackGeometry.floorThickness / 2
        var positions: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        for index in 0..<segments {
            let t0 = Float(index) / Float(segments)
            let t1 = Float(index + 1) / Float(segments)
            let e0 = OvalTrackGeometry.trackEdges(at: t0)
            let e1 = OvalTrackGeometry.trackEdges(at: t1)

            let base = UInt32(positions.count)
            positions.append(SIMD3(e0.inner.x, floorY, e0.inner.y))
            positions.append(SIMD3(e0.outer.x, floorY, e0.outer.y))
            positions.append(SIMD3(e1.outer.x, floorY, e1.outer.y))
            positions.append(SIMD3(e1.inner.x, floorY, e1.inner.y))

            indices.append(contentsOf: [base, base + 1, base + 2, base, base + 2, base + 3])
        }

        var descriptor = MeshDescriptor()
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.primitives = .triangles(indices)

        let mesh = try! MeshResource.generate(from: [descriptor])
        let material = SimpleMaterial(
            color: UIColor(white: 0.18, alpha: 1),
            roughness: 0.85,
            isMetallic: false
        )
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = "TrackFloor"
        return entity
    }
}
