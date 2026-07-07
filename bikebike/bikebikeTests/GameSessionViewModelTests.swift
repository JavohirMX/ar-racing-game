import Testing
import Foundation
@testable import bikebike

@Suite @MainActor struct GameSessionViewModelTests {

    private func makeVM(mode: GameMode) -> GameSessionViewModel {
        GameSessionViewModel(
            mode: mode,
            track: .downtown,
            laps: 3,
            nickname: "Test",
            sessionID: UUID()
        )
    }

    @Test func initialPhaseIsWaiting() {
        let vm = makeVM(mode: .solo)
        #expect(vm.phase == .waiting)
    }

    @Test func soloModeSetsUpOnePlayer() {
        let vm = makeVM(mode: .solo)
        vm.setup()
        #expect(vm.playerCount == 1)
    }

    @Test func startRaceBeginsCountdown() {
        let vm = makeVM(mode: .solo)
        vm.startRace()
        #expect(vm.phase == .countdown)
        #expect(vm.countdownSeconds == 3)
    }

    @Test func hostModeSetsUpHostManager() {
        let vm = makeVM(mode: .multiplayerHost)
        vm.setup()
        #expect(vm.playerCount == 1)
    }

    @Test func peerModeInitializesPeerManager() {
        let vm = makeVM(mode: .multiplayerPeer)
        vm.setup()
        #expect(vm.phase == .waiting)
    }

    @Test func cleanupStopsTimer() {
        let vm = makeVM(mode: .solo)
        vm.cleanup()
    }
}
