import Testing
import Foundation
@testable import bikebike

@Suite struct DriverTests {

    @Test func allDriversHaveUniqueColors() {
        let hexColors = Driver.allCases.map { $0.colorHex }
        #expect(Set(hexColors).count == Driver.allCases.count)
    }

    @Test func allDriversHaveDisplayName() {
        for driver in Driver.allCases {
            #expect(!driver.displayName.isEmpty)
        }
    }

    @Test func driverCountIsSix() {
        #expect(Driver.allCases.count == 6)
    }

    @Test func rawValuesAreSequential() {
        let rawValues = Driver.allCases.map { $0.rawValue }
        #expect(rawValues == [0, 1, 2, 3, 4, 5])
    }

    @Test func allDriversShareModelFileName() {
        let fileNames = Set(Driver.allCases.map { $0.modelFileName })
        #expect(fileNames.count == 1)
        #expect(fileNames.first == "bike-talin.usdz")
    }
}
