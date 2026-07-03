import Testing
import Foundation
@testable import bikebike

@Suite struct PeerSessionManagerTests {

    @Test func instantiatePeer() {
        let peer = PeerSessionManager(nickname: "Peer1")
        #expect(peer.nickname == "Peer1")
    }

    @Test func peerCanBeCreatedWithMockConnectionFactory() {
        let peer = PeerSessionManager(nickname: "Peer1") { _ in
            MockNetworkConnection()
        }
        #expect(peer.nickname == "Peer1")
    }
}
