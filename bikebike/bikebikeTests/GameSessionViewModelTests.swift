import Testing
@testable import bikebike

@Suite @MainActor struct GameSessionViewModelTests {

    @Test func initialPhaseIsWaiting() {
        let vm = GameSessionViewModel(mode: .solo, track: .downtown)
        #expect(vm.phase == .waiting)
    }

    @Test func soloModeSetsUpOnePlayer() {
        let vm = GameSessionViewModel(mode: .solo, track: .downtown)
        vm.setup()
        #expect(vm.playerCount == 1)
    }

    @Test func startRaceBeginsCountdown() {
        let vm = GameSessionViewModel(mode: .solo, track: .downtown)
        vm.startRace()
        #expect(vm.phase == .countdown)
        #expect(vm.countdownSeconds == 3)
    }

    @Test func hostModeSetsUpHostManager() {
        let vm = GameSessionViewModel(mode: .multiplayerHost, track: .downtown)
        vm.setup()
        #expect(vm.playerCount == 1)
    }

    @Test func peerModeInitializesPeerManager() {
        let vm = GameSessionViewModel(mode: .multiplayerPeer, track: .downtown)
        vm.setup()
        #expect(vm.phase == .waiting)
    }

    @Test func cleanupStopsTimer() {
        let vm = GameSessionViewModel(mode: .solo, track: .downtown)
        vm.cleanup()
    }
}
