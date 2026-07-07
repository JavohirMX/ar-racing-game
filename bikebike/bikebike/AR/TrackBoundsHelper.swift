import RealityKit
import os.log

enum TrackBoundsHelper {
    private static let logger = Logger(subsystem: "bikebike", category: "TrackBounds")

    static func logBounds(_ bounds: BoundingBox, label: String) {
        logger.info("""
        Track '\(label)' bounds:
          min: (\(bounds.min.x), \(bounds.min.y), \(bounds.min.z))
          max: (\(bounds.max.x), \(bounds.max.y), \(bounds.max.z))
        """)
    }
}
