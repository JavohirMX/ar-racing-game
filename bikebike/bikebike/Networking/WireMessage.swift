import Foundation

enum WireMessage: Codable {
    case gameState(GameState)
    case playerInput(PlayerInput)
    case joinRequest(JoinRequest)
    case joinResponse(JoinResponse)
    case playerDisconnected(PlayerDisconnected)
}
