import Foundation

extension String {
    /// RealityKit `Entity(named:)` expects the bundle resource name without file extension.
    var usdzResourceName: String {
        (self as NSString).deletingPathExtension
    }
}
