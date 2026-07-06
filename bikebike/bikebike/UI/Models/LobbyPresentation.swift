import UIKit

struct LobbySlotPresentation: Identifiable, Equatable {
    let id: Int
    let driver: Driver
    let nickname: String?
    let subtitle: String
    let isHost: Bool
    let isOccupied: Bool

    static func demo(hostNickname: String) -> [LobbySlotPresentation] {
        let drivers = Driver.allCases
        return (0..<6).map { index in
            if index == 0 {
                return LobbySlotPresentation(
                    id: index,
                    driver: drivers[index % drivers.count],
                    nickname: "\(hostNickname) (You)",
                    subtitle: "Ready",
                    isHost: true,
                    isOccupied: true
                )
            }
            return LobbySlotPresentation(
                id: index,
                driver: drivers[index % drivers.count],
                nickname: nil,
                subtitle: "Open slot",
                isHost: false,
                isOccupied: false
            )
        }
    }
}

struct FoodDeliveredRow: Identifiable {
    let id: Int
    let rank: Int
    let nickname: String
    let stars: Int
    let time: TimeInterval

    static let sampleRows: [FoodDeliveredRow] = [
        FoodDeliveredRow(id: 1, rank: 1, nickname: "Masterish", stars: 5, time: 73.25),
        FoodDeliveredRow(id: 2, rank: 2, nickname: "Jo-Ana", stars: 4, time: 74.23),
        FoodDeliveredRow(id: 3, rank: 3, nickname: "The Noder", stars: 3, time: 109.15)
    ]
}

enum MockQRCode {
    static func image() -> UIImage? {
        let info = QREndpointInfo(
            name: "Bikebike",
            host: "192.168.1.1",
            port: 12345,
            service: "_bikebike._tcp"
        )
        return QRCodeGenerator().generate(from: info)
    }
}
