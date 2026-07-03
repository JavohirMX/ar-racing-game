import Foundation

enum NetworkMessageType: UInt8, Codable {
    case joinRequest = 0
    case joinResponse = 1
    case hostMigrated = 2
    case playerDisconnected = 3
}

struct JoinRequest: Codable {
    let nickname: String
}

struct JoinResponse: Codable {
    let accepted: Bool
    let playerID: UUID?
    let rejectionReason: RejectionReason?
    let assignedDriverIndex: Int?

    enum RejectionReason: String, Codable {
        case lobbyFull
        case nameTaken
    }
}

struct HostMigrated: Codable {
    let newHostPlayerID: UUID
    let sessionID: UUID
    let lastKnownTick: UInt32
}

struct PlayerDisconnected: Codable {
    let playerID: UUID
}
