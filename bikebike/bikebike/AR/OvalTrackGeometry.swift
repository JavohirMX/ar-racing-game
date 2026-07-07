//
//  OvalTrackGeometry.swift
//  bikebike
//

import simd

/// Stadium-oval racetrack math (~0.8m × 0.5m tabletop footprint).
enum OvalTrackGeometry {
    static let presetId = "oval-loop-procedural"

    static let turnRadius: Float = 0.25
    static let straightLength: Float = 0.30
    static let trackWidth: Float = 0.12
    static let wallHeight: Float = 0.04
    static let wallThickness: Float = 0.012
    static let floorThickness: Float = 0.008
    static let segmentCount = 48

    static let vehicleSize = SIMD3<Float>(0.04, 0.016, 0.065)
    static var vehicleHalfExtents: SIMD3<Float> { vehicleSize / 2 }

    static var trackHalfWidth: Float { trackWidth / 2 }

    static let surfaceY: Float = 0.03

    /// Spawn slightly before the start/finish line on the bottom straight (counterclockwise).
    static var startGridOffset: SIMD3<Float> {
        let spawnT = max(0, finishLineParameter - 0.035)
        let point = centerlinePoint(t: spawnT)
        return SIMD3(point.x, 0.025, point.y)
    }

    static var startRotation: Float {
        let spawnT = max(0, finishLineParameter - 0.035)
        let tangent = centerlineTangent(t: spawnT)
        return -atan2(tangent.y, tangent.x) + .pi / 2
    }

    static let finishLineHalfWidth: Float = 0.08

    /// Centerline parameter [0, 1) at the start/finish line on the bottom straight.
    static var finishLineParameter: Float {
        (straightLength / 2) / perimeter
    }

    private static var halfStraight: Float { straightLength / 2 }
    private static var semicircleLength: Float { .pi * turnRadius }
    private static var perimeter: Float { 2 * straightLength + 2 * semicircleLength }

    static var perimeterLength: Float { perimeter }
    private static var drivableHalfWidth: Float {
        max(0.02, trackWidth / 2 - max(vehicleHalfExtents.x, vehicleHalfExtents.z))
    }

    static var finishCheckpoint: Checkpoint {
        let point = centerlinePoint(t: finishLineParameter)
        return Checkpoint(
            id: 0,
            position: SIMD3(point.x, surfaceY, point.y),
            radius: finishLineHalfWidth
        )
    }

    static var halfwayCheckpoint: Checkpoint {
        let point = centerlinePoint(t: checkpointParameter)
        return Checkpoint(
            id: 1,
            position: SIMD3(point.x, surfaceY, point.y),
            radius: finishLineHalfWidth
        )
    }

    // MARK: - Centerline

    /// Point on the track centerline; `t` in [0, 1) wraps the full loop (counterclockwise from above).
    static func centerlinePoint(t: Float) -> SIMD2<Float> {
        let wrapped = t - floor(t)
        let distance = wrapped * perimeter
        return centerlinePoint(distance: distance)
    }

    static func centerlineTangent(t: Float) -> SIMD2<Float> {
        let epsilon: Float = 0.002
        let p0 = centerlinePoint(t: t)
        let p1 = centerlinePoint(t: t + epsilon)
        let delta = p1 - p0
        let len = simd_length(delta)
        guard len > 0.0001 else { return SIMD2(1, 0) }
        return delta / len
    }

    /// Right-hand normal for CCW centerline travel; points toward the oval interior.
    static func centerlineRight(t: Float) -> SIMD2<Float> {
        let tangent = centerlineTangent(t: t)
        return SIMD2(tangent.y, -tangent.x)
    }

    static func centerlineNormal(t: Float) -> SIMD2<Float> {
        centerlineRight(t: t)
    }

    struct TrackEdges {
        var center: SIMD2<Float>
        var right: SIMD2<Float>
        var inner: SIMD2<Float>
        var outer: SIMD2<Float>
    }

    static func trackEdges(at t: Float) -> TrackEdges {
        let center = centerlinePoint(t: t)
        let right = centerlineRight(t: t)
        let half = trackHalfWidth
        return TrackEdges(
            center: center,
            right: right,
            inner: center + right * half,
            outer: center - right * half
        )
    }

    private static func centerlinePoint(distance: Float) -> SIMD2<Float> {
        var d = distance.truncatingRemainder(dividingBy: perimeter)
        if d < 0 { d += perimeter }

        let bottomStraight = straightLength
        let leftArc = semicircleLength
        let topStraight = straightLength

        if d < bottomStraight {
            let x = halfStraight - d
            return SIMD2(x, -turnRadius)
        }
        d -= bottomStraight

        if d < leftArc {
            let angle = -.pi / 2 - (d / turnRadius)
            return SIMD2(-halfStraight + turnRadius * cos(angle), turnRadius * sin(angle))
        }
        d -= leftArc

        if d < topStraight {
            let x = -halfStraight + d
            return SIMD2(x, turnRadius)
        }
        d -= topStraight

        let angle = .pi / 2 - (d / turnRadius)
        return SIMD2(halfStraight + turnRadius * cos(angle), turnRadius * sin(angle))
    }

    // MARK: - Containment

    struct CorridorClampResult {
        var position: SIMD2<Float>
        var hitWall: Bool
    }

    /// Clamp a local XZ position to the drivable corridor inside the stadium oval.
    static func clampToCorridor(_ localPos: SIMD3<Float>) -> CorridorClampResult {
        let point = SIMD2(localPos.x, localPos.z)
        let nearest = nearestCenterline(to: point)
        let right = nearest.right
        let lateral = simd_dot(point - nearest.point, right)
        let clampedLateral = min(drivableHalfWidth, max(-drivableHalfWidth, lateral))
        let hitWall = abs(lateral - clampedLateral) > 0.0005
        let clamped = nearest.point + right * clampedLateral
        return CorridorClampResult(position: clamped, hitWall: hitWall)
    }

    // MARK: - Finish line

    /// Centerline parameter [0, 1) for a local XZ position.
    static func centerlineParameter(for localPos: SIMD3<Float>) -> Float {
        nearestCenterline(to: SIMD2(localPos.x, localPos.z)).parameter
    }

    /// Half a lap past the finish line; a lap only counts after this is crossed.
    static var checkpointParameter: Float {
        (finishLineParameter + 0.5).truncatingRemainder(dividingBy: 1)
    }

    static var finishArcLength: Float { finishLineParameter * perimeter }
    static var checkpointArcLength: Float { checkpointParameter * perimeter }

    static func arcLength(for localPos: SIMD3<Float>) -> Float {
        centerlineParameter(for: localPos) * perimeter
    }

    /// Smallest forward delta along the loop from `from` to `to` in [0, perimeter).
    static func forwardArcDelta(from: Float, to: Float) -> Float {
        let delta = to - from
        return delta >= 0 ? delta : delta + perimeter
    }

    // MARK: - Private

    private struct NearestCenterline {
        var point: SIMD2<Float>
        var right: SIMD2<Float>
        var parameter: Float
        var distanceSquared: Float
    }

    private static func nearestCenterline(to point: SIMD2<Float>) -> NearestCenterline {
        var best = NearestCenterline(
            point: centerlinePoint(t: 0),
            right: centerlineRight(t: 0),
            parameter: 0,
            distanceSquared: .infinity
        )

        let samples = segmentCount * 2
        for index in 0..<samples {
            let t = Float(index) / Float(samples)
            let candidate = centerlinePoint(t: t)
            let distSq = simd_length_squared(candidate - point)
            if distSq < best.distanceSquared {
                best = NearestCenterline(
                    point: candidate,
                    right: centerlineRight(t: t),
                    parameter: t,
                    distanceSquared: distSq
                )
            }
        }

        refineNearest(onBottomStraight: point, best: &best)
        refineNearest(onTopStraight: point, best: &best)
        refineNearest(onLeftArc: point, best: &best)
        refineNearest(onRightArc: point, best: &best)

        return best
    }

    private static func parameter(onBottomStraight x: Float) -> Float {
        let distance = halfStraight - x
        return distance / perimeter
    }

    private static func parameter(onTopStraight x: Float) -> Float {
        let distance = straightLength + semicircleLength + (x + halfStraight)
        return distance / perimeter
    }

    private static func refineNearest(onBottomStraight point: SIMD2<Float>, best: inout NearestCenterline) {
        let x = min(halfStraight, max(-halfStraight, point.x))
        let candidate = SIMD2(x, -turnRadius)
        let t = parameter(onBottomStraight: x)
        updateBest(candidate: candidate, parameter: t, point: point, best: &best)
    }

    private static func refineNearest(onTopStraight point: SIMD2<Float>, best: inout NearestCenterline) {
        let x = min(halfStraight, max(-halfStraight, point.x))
        let candidate = SIMD2(x, turnRadius)
        let t = parameter(onTopStraight: x)
        updateBest(candidate: candidate, parameter: t, point: point, best: &best)
    }

    private static func refineNearest(onLeftArc point: SIMD2<Float>, best: inout NearestCenterline) {
        let center = SIMD2(-halfStraight, 0)
        let delta = point - center
        let a = atan2(delta.y, delta.x)
        let phi: Float
        if a <= -.pi / 2 {
            phi = -.pi / 2 - a
        } else if a >= .pi / 2 {
            phi = 3 * .pi / 2 - a
        } else {
            phi = a < 0 ? 0 : .pi
        }
        let theta = -.pi / 2 - phi
        let candidate = center + turnRadius * SIMD2(cos(theta), sin(theta))
        let t = (straightLength + turnRadius * phi) / perimeter
        updateBest(candidate: candidate, parameter: t, point: point, best: &best)
    }

    private static func refineNearest(onRightArc point: SIMD2<Float>, best: inout NearestCenterline) {
        let center = SIMD2(halfStraight, 0)
        let delta = point - center
        let a = atan2(delta.y, delta.x)
        let phi: Float
        if a >= -.pi / 2 && a <= .pi / 2 {
            phi = .pi / 2 - a
        } else {
            phi = a > 0 ? 0 : .pi
        }
        let theta = .pi / 2 - phi
        let candidate = center + turnRadius * SIMD2(cos(theta), sin(theta))
        let t = (2 * straightLength + semicircleLength + turnRadius * phi) / perimeter
        updateBest(candidate: candidate, parameter: t, point: point, best: &best)
    }

    private static func updateBest(
        candidate: SIMD2<Float>,
        parameter: Float,
        point: SIMD2<Float>,
        best: inout NearestCenterline
    ) {
        let distSq = simd_length_squared(candidate - point)
        if distSq < best.distanceSquared {
            best = NearestCenterline(
                point: candidate,
                right: centerlineRight(t: parameter),
                parameter: parameter,
                distanceSquared: distSq
            )
        }
    }
}
