import Foundation

enum Driver: Int, CaseIterable, Codable {
    case green = 0
    case orange = 1
    case pink = 2
    case purple = 3
    case blue = 4
    case yellow = 5

    var displayName: String {
        switch self {
        case .green:  return "Go-Send"
        case .orange: return "Grab-Food"
        case .pink:   return "Shopee"
        case .purple: return "Lalamove"
        case .blue:   return "Maxim"
        case .yellow: return "Ninja"
        }
    }

    var colorHex: String {
        switch self {
        case .green:  return "#34C759"
        case .orange: return "#FF9500"
        case .pink:   return "#FF375F"
        case .purple: return "#AF52DE"
        case .blue:   return "#007AFF"
        case .yellow: return "#FFCC00"
        }
    }

    var modelFileName: String { "bike.usdz" }
}
