import Testing
import Foundation
@testable import bikebike

@Suite @MainActor struct RaceEngineTests {

    @Test func engineInitializesWithTrack() {
        let engine = RaceEngine(track: .downtown, sessionID: UUID())
        #expect(engine.track.id == "downtown")
        #expect(engine.totalLaps == 3)
    }

    @Test func playerCountStartsAtZero() {
        let engine = RaceEngine(track: .downtown, sessionID: UUID())
        #expect(engine.playerCount == 0)
    }

    @Test func addingPlayerIncreasesCount() {
        let engine = RaceEngine(track: .downtown, sessionID: UUID())
        engine.addPlayer(playerID: UUID(), nickname: "Test")
        #expect(engine.playerCount == 1)
    }

    @Test func startRaceResetsState() {
        let engine = RaceEngine(track: .downtown, sessionID: UUID())
        let playerID = UUID()
        engine.addPlayer(playerID: playerID, nickname: "Test")
        engine.startRace()

        let (state, _) = engine.tick()
        #expect(state.players.count == 1)
        #expect(state.tick > 0)
    }

    @Test func tickGeneratesGameState() {
        let engine = RaceEngine(track: .downtown, sessionID: UUID())
        let playerID = UUID()
        engine.addPlayer(playerID: playerID, nickname: "Test")
        engine.startRace()

        let (state, raceFinished) = engine.tick()

        #expect(state.phase == .racing)
        #expect(state.players.count == 1)
        #expect(state.tick > 0)
        #expect(raceFinished == false)
    }

    @Test func tickIncrementsCounter() {
        let engine = RaceEngine(track: .downtown, sessionID: UUID())
        let playerID = UUID()
        engine.addPlayer(playerID: playerID, nickname: "Test")
        engine.startRace()

        let (s1, _) = engine.tick()
        let (s2, _) = engine.tick()

        #expect(s2.tick > s1.tick)
    }

    @Test func removePlayerDecreasesCount() {
        let engine = RaceEngine(track: .downtown, sessionID: UUID())
        let playerID = UUID()
        engine.addPlayer(playerID: playerID, nickname: "Test")
        #expect(engine.playerCount == 1)

        engine.removePlayer(playerID: playerID)
        #expect(engine.playerCount == 0)
    }

    @Test func accelerationIncreasesSpeed() {
        let engine = RaceEngine(track: .downtown, sessionID: UUID())
        let playerID = UUID()
        engine.addPlayer(playerID: playerID, nickname: "Test")
        engine.startRace()

        engine.applyInput(
            playerID: playerID,
            input: PlayerInput(tick: 1, steerDirection: 0, accelerate: true, boostActivated: false)
        )

        let (s1, _) = engine.tick()
        let speed1 = s1.players.first?.speed ?? 0
        #expect(speed1 > 0)
    }

    @Test func speedRespectsLimit() {
        let engine = RaceEngine(track: .downtown, sessionID: UUID())
        let playerID = UUID()
        engine.addPlayer(playerID: playerID, nickname: "Test")
        engine.startRace()

        engine.applyInput(
            playerID: playerID,
            input: PlayerInput(tick: 1, steerDirection: 0, accelerate: true, boostActivated: false)
        )

        // Run many ticks to approach max speed
        for _ in 0..<300 {
            engine.applyInput(
                playerID: playerID,
                input: PlayerInput(tick: 1, steerDirection: 0, accelerate: true, boostActivated: false)
            )
            _ = engine.tick()
        }

        let (final, _) = engine.tick()
        let speed = final.players.first?.speed ?? 0
        #expect(speed <= 5.05)
    }
}
