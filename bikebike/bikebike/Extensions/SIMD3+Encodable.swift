import Foundation

extension SIMD3<Float> {
    var array: [Float] { [x, y, z] }

    init(_ array: [Float]) {
        precondition(array.count == 3, "SIMD3 requires exactly 3 elements")
        self.init(array[0], array[1], array[2])
    }
}
