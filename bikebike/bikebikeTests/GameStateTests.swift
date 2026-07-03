import Testing
import Foundation
@testable import bikebike

@Suite struct GameStateTests {

    @Test func gameStateEncodesAndDecodesRoundTrip() throws {
        let state = GameState(
            sessionID: UUID(),
            tick: 42,
            phase: .racing,
            countdownSeconds: nil,
            totalLaps: 3,
            players: [
                PlayerState(
                    playerID: UUID(),
                    nickname: "Alice",
                    position: SIMD3<Float>(1.0, 0.0, 2.0),
                    rotation: 1.57,
                    speed: 3.5,
                    lap: 1,
                    checkpointsHit: [0],
                    boostAvailable: true,
                    boostActive: false,
                    finished: false,
                    finishTime: nil
                )
            ],
            results: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(state)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GameState.self, from: data)

        #expect(decoded.tick == 42)
        #expect(decoded.phase == .racing)
        #expect(decoded.totalLaps == 3)
        #expect(decoded.players.count == 1)
        #expect(decoded.players[0].nickname == "Alice")
        #expect(decoded.players[0].lap == 1)
    }

    @Test func gamePhaseIntValues() {
        #expect(GamePhase.waiting.rawValue == 0)
        #expect(GamePhase.countdown.rawValue == 1)
        #expect(GamePhase.racing.rawValue == 2)
        #expect(GamePhase.finished.rawValue == 3)
        #expect(GamePhase.results.rawValue == 4)
    }

    @Test func playerStateEncodesSimd3AsArray() throws {
        let player = PlayerState(
            playerID: UUID(),
            nickname: "Test",
            position: SIMD3<Float>(1.5, 0.0, -2.5),
            rotation: 0.0,
            speed: 0.0,
            lap: 0,
            checkpointsHit: [],
            boostAvailable: true,
            boostActive: false,
            finished: false,
            finishTime: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(player)

        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("1.5"))
        #expect(json.contains("-2.5"))
    }

    @Test func gameStateWithCountdown() throws {
        let state = GameState(
            sessionID: UUID(),
            tick: 0,
            phase: .countdown,
            countdownSeconds: 3,
            totalLaps: 3,
            players: [],
            results: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(state)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(GameState.self, from: data)

        #expect(decoded.phase == .countdown)
        #expect(decoded.countdownSeconds == 3)
        #expect(decoded.players.isEmpty)
    }
}
