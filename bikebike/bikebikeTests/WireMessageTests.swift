import Testing
import Foundation
@testable import bikebike

@Suite struct WireMessageTests {

    @Test func encodeDecodePlayerInput() throws {
        let input = PlayerInput(tick: 7, steerDirection: -0.5, accelerate: true, boostActivated: false)
        let message = WireMessage.playerInput(input)

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(WireMessage.self, from: data)

        guard case .playerInput(let result) = decoded else {
            Issue.record("Wrong message type")
            return
        }
        #expect(result.tick == 7)
        #expect(result.steerDirection == -0.5)
    }

    @Test func encodeDecodeJoinRequest() throws {
        let request = JoinRequest(nickname: "Alice")
        let message = WireMessage.joinRequest(request)

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(WireMessage.self, from: data)

        guard case .joinRequest(let result) = decoded else {
            Issue.record("Wrong message type")
            return
        }
        #expect(result.nickname == "Alice")
    }

    @Test func encodeDecodeJoinResponseAccepted() throws {
        let playerID = UUID()
        let response = JoinResponse(accepted: true, playerID: playerID, rejectionReason: nil, assignedDriverIndex: 2)
        let message = WireMessage.joinResponse(response)

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(WireMessage.self, from: data)

        guard case .joinResponse(let result) = decoded else {
            Issue.record("Wrong message type")
            return
        }
        #expect(result.accepted)
        #expect(result.assignedDriverIndex == 2)
    }

    @Test func encodeDecodeJoinResponseRejected() throws {
        let response = JoinResponse(accepted: false, playerID: nil, rejectionReason: .lobbyFull, assignedDriverIndex: nil)
        let message = WireMessage.joinResponse(response)

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(WireMessage.self, from: data)

        guard case .joinResponse(let result) = decoded else {
            Issue.record("Wrong message type")
            return
        }
        #expect(result.accepted == false)
        #expect(result.rejectionReason == .lobbyFull)
    }

    @Test func encodeDecodePlayerDisconnected() throws {
        let playerID = UUID()
        let disconnect = PlayerDisconnected(playerID: playerID)
        let message = WireMessage.playerDisconnected(disconnect)

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(WireMessage.self, from: data)

        guard case .playerDisconnected(let result) = decoded else {
            Issue.record("Wrong message type")
            return
        }
        #expect(result.playerID == playerID)
    }

    @Test func encodeDecodeFullGameState() throws {
        let state = GameState(
            sessionID: UUID(),
            tick: 100,
            phase: .racing,
            countdownSeconds: nil,
            totalLaps: 3,
            players: [
                PlayerState(
                    playerID: UUID(), nickname: "P1",
                    position: SIMD3<Float>(0.5, 0, -1),
                    rotation: 1.57, speed: 4.2, lap: 2,
                    checkpointsHit: [0, 1],
                    boostAvailable: true, boostActive: false,
                    finished: false, finishTime: nil
                )
            ],
            results: nil
        )
        let message = WireMessage.gameState(state)

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(WireMessage.self, from: data)

        guard case .gameState(let result) = decoded else {
            Issue.record("Wrong message type")
            return
        }
        #expect(result.tick == 100)
        #expect(result.phase == .racing)
        #expect(result.players[0].lap == 2)
    }
}
