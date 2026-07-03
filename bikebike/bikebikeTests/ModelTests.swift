import Testing
import Foundation
@testable import bikebike

@Suite struct ModelTests {

    @Test func raceResultStarsCalculation() {
        let positions = 1...6
        let expectedStars = [5, 4, 3, 2, 1, 1]

        for (position, expected) in zip(positions, expectedStars) {
            let stars = max(1, 6 - position)
            #expect(stars == expected, "Position \(position) should get \(expected) stars, got \(stars)")
        }
    }

    @Test func raceResultDnfPlayer() {
        let dnf = RaceResult(
            playerID: UUID(),
            nickname: "Bob",
            position: 6,
            totalTime: nil,
            bestLapTime: nil,
            stars: 1,
            didFinish: false
        )

        #expect(dnf.stars == 1)
        #expect(dnf.totalTime == nil)
        #expect(dnf.bestLapTime == nil)
        #expect(dnf.didFinish == false)
    }

    @Test func raceResultWinner() {
        let winner = RaceResult(
            playerID: UUID(),
            nickname: "Alice",
            position: 1,
            totalTime: 45.2,
            bestLapTime: 14.8,
            stars: 5,
            didFinish: true
        )

        #expect(winner.stars == 5)
        #expect(winner.position == 1)
        #expect(winner.didFinish)
    }

    @Test func joinRequestEncoding() throws {
        let request = JoinRequest(nickname: "Player1")

        let encoder = JSONEncoder()
        let data = try encoder.encode(request)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(JoinRequest.self, from: data)

        #expect(decoded.nickname == "Player1")
    }

    @Test func joinResponseAccepted() throws {
        let playerID = UUID()
        let response = JoinResponse(
            accepted: true,
            playerID: playerID,
            rejectionReason: nil,
            assignedDriverIndex: 0
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(response)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(JoinResponse.self, from: data)

        #expect(decoded.accepted)
        #expect(decoded.playerID == playerID)
        #expect(decoded.assignedDriverIndex == 0)
        #expect(decoded.rejectionReason == nil)
    }

    @Test func joinResponseRejected() throws {
        let response = JoinResponse(
            accepted: false,
            playerID: nil,
            rejectionReason: .lobbyFull,
            assignedDriverIndex: nil
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(response)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(JoinResponse.self, from: data)

        #expect(decoded.accepted == false)
        #expect(decoded.playerID == nil)
        #expect(decoded.rejectionReason == .lobbyFull)
    }

    @Test func playerInputEncoding() throws {
        let input = PlayerInput(
            tick: 100,
            steerDirection: -0.5,
            accelerate: true,
            boostActivated: false
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(input)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(PlayerInput.self, from: data)

        #expect(decoded.tick == 100)
        #expect(decoded.steerDirection == -0.5)
        #expect(decoded.accelerate)
        #expect(decoded.boostActivated == false)
    }

    @Test func hostMigratedEncoding() throws {
        let newHostID = UUID()
        let sessionID = UUID()
        let message = HostMigrated(
            newHostPlayerID: newHostID,
            sessionID: sessionID,
            lastKnownTick: 150
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(message)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(HostMigrated.self, from: data)

        #expect(decoded.newHostPlayerID == newHostID)
        #expect(decoded.sessionID == sessionID)
        #expect(decoded.lastKnownTick == 150)
    }

    @Test func trackDefaults() {
        let track = Track.downtown

        #expect(track.id == "downtown")
        #expect(track.defaultLaps == 3)
        #expect(track.minLaps == 1)
        #expect(track.maxLaps == 5)
        #expect(track.checkpoints.count == 2)
        #expect(track.checkpoints[0].id == 0)
        #expect(track.checkpoints[1].id == 1)
    }

    @Test func simd3ArrayConversion() {
        let vector = SIMD3<Float>(1.0, 2.0, 3.0)
        let array = vector.array

        #expect(array == [1.0, 2.0, 3.0])

        let reconstructed = SIMD3<Float>(array)
        #expect(reconstructed == vector)
    }
}
