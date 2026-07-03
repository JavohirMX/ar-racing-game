import Testing
import Foundation
@testable import bikebike

@Suite struct GameStateCodecTests {

    @Test func encodeDecodeRoundTrip() throws {
        let codec = GameStateCodec()
        let state = GameState(
            sessionID: UUID(),
            tick: 100,
            phase: .racing,
            countdownSeconds: nil,
            totalLaps: 3,
            players: [
                PlayerState(
                    playerID: UUID(),
                    nickname: "Player1",
                    position: SIMD3<Float>(0.5, 0.0, -1.0),
                    rotation: 1.57,
                    speed: 4.2,
                    lap: 2,
                    checkpointsHit: [0, 1],
                    boostAvailable: false,
                    boostActive: true,
                    finished: false,
                    finishTime: nil
                )
            ],
            results: nil
        )

        let data = try codec.encode(state)
        let decoded = try codec.decode(from: data)

        #expect(decoded.tick == 100)
        #expect(decoded.phase == .racing)
        #expect(decoded.players[0].lap == 2)
        #expect(decoded.players[0].boostActive)
    }

    @Test func encodeEmptyState() throws {
        let codec = GameStateCodec()
        let state = GameState(
            sessionID: UUID(), tick: 0, phase: .waiting,
            countdownSeconds: nil, totalLaps: 3,
            players: [], results: nil
        )

        let data = try codec.encode(state)
        #expect(data.count > 0)
    }

    @Test func encodeStateWithResults() throws {
        let codec = GameStateCodec()
        let results = [
            RaceResult(
                playerID: UUID(), nickname: "Winner",
                position: 1, totalTime: 42.5, bestLapTime: 13.2,
                stars: 5, didFinish: true
            )
        ]
        let state = GameState(
            sessionID: UUID(), tick: 999, phase: .results,
            countdownSeconds: nil, totalLaps: 3,
            players: [], results: results
        )

        let data = try codec.encode(state)
        let decoded = try codec.decode(from: data)

        #expect(decoded.phase == .results)
        #expect(decoded.results?.count == 1)
        #expect(decoded.results?[0].position == 1)
    }
}
