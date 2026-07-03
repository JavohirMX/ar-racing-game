import Testing
import Foundation
@testable import bikebike

@Suite struct HostSessionManagerTests {

    @Test func instantiateHost() {
        let host = HostSessionManager(nickname: "Host", maxPlayers: 6)
        #expect(host.nickname == "Host")
    }

    @Test func initialPlayerCountIsZero() async {
        let host = HostSessionManager(nickname: "Host", maxPlayers: 6)
        let count = await host.connectedPlayerCount
        #expect(count == 0)
    }

    @Test func connectedPlayersInitiallyEmpty() async {
        let host = HostSessionManager(nickname: "Host", maxPlayers: 6)
        let players = await host.connectedPlayers
        #expect(players.isEmpty)
    }

    @Test func defaultMaxPlayersIsSix() {
        let host = HostSessionManager(nickname: "Host")
        #expect(host.maxPlayers == 6)
    }
}
