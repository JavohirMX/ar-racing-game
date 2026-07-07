import ARKit
import RealityKit
import SwiftUI
import Combine
import os.log
import simd

struct TrackPlacementResult {
    let entity: Entity
    let calibratedTrack: Track
    let scale: Float
    let worldTransform: simd_float4x4?
}

// MARK: - Placement AR view

struct ARPlacementContainer: UIViewRepresentable {
    let track: Track
    @Binding var isPlaneDetected: Bool
    @Binding var canConfirm: Bool
    @Binding var isLoading: Bool
    @Binding var sessionError: String?
    var placementOpacity: Float = 0.85
    var onEntityReady: (TrackPlacementResult) -> Void

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false
        arView.renderOptions = [.disableDepthOfField, .disableMotionBlur]
        arView.session.delegate = context.coordinator
        context.coordinator.arView = arView
        context.coordinator.track = track
        context.coordinator.placementOpacity = placementOpacity
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.startSessionIfNeeded(on: uiView)
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: Coordinator) {
        uiView.session.pause()
        coordinator.reset()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            isPlaneDetected: $isPlaneDetected,
            canConfirm: $canConfirm,
            isLoading: $isLoading,
            sessionError: $sessionError,
            onEntityReady: onEntityReady
        )
    }

  @MainActor
    final class Coordinator: NSObject, ARSessionDelegate {
        private static let logger = Logger(subsystem: "bikebike", category: "ARPlacement")

        @Binding var isPlaneDetected: Bool
        @Binding var canConfirm: Bool
        @Binding var isLoading: Bool
        @Binding var sessionError: String?
        let onEntityReady: (TrackPlacementResult) -> Void

        weak var arView: ARView?
        var anchor: AnchorEntity?
        var trackEntity: TrackEntity?
        var track: Track = .downtown
        var placementOpacity: Float = 0.85

        private var didStartSession = false
        private var didLoadTrack = false
        private var placedPlaneAnchorID: UUID?
        private var loadTask: Task<Void, Never>?

        init(
            isPlaneDetected: Binding<Bool>,
            canConfirm: Binding<Bool>,
            isLoading: Binding<Bool>,
            sessionError: Binding<String?>,
            onEntityReady: @escaping (TrackPlacementResult) -> Void
        ) {
            _isPlaneDetected = isPlaneDetected
            _canConfirm = canConfirm
            _isLoading = isLoading
            _sessionError = sessionError
            self.onEntityReady = onEntityReady
        }

        func reset() {
            loadTask?.cancel()
            loadTask = nil
            didStartSession = false
            didLoadTrack = false
            placedPlaneAnchorID = nil
            anchor?.removeFromParent()
            anchor = nil
            trackEntity = nil
        }

        func startSessionIfNeeded(on arView: ARView) {
            guard !didStartSession, arView.bounds.width > 0, arView.bounds.height > 0 else { return }
            didStartSession = true
            self.arView = arView

            let config = ARWorldTrackingConfiguration()
            config.planeDetection = [.horizontal]
            arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
            Self.logger.info("AR session started for placement")
        }

        private func loadTrackIfNeeded(for planeAnchor: ARPlaneAnchor) {
            guard !didLoadTrack else { return }
            didLoadTrack = true
            placedPlaneAnchorID = planeAnchor.identifier
            isLoading = true
            canConfirm = false

            loadTask = Task { @MainActor in
                defer { isLoading = false }
                do {
                    async let bikePreload: Void = BikeModelLoader.preload()
                    let loaded = try await TrackEntity.load(track: track)
                    await bikePreload
                    trackEntity = loaded
                    loaded.entity.components.set(OpacityComponent(opacity: placementOpacity))

                    let anchor = AnchorEntity(anchor: planeAnchor)
                    anchor.addChild(loaded.entity)
                    arView?.scene.addAnchor(anchor)
                    self.anchor = anchor

                    let result = TrackPlacementResult(
                        entity: loaded.entity,
                        calibratedTrack: loaded.calibratedTrack,
                        scale: loaded.appliedScale,
                        worldTransform: anchor.transformMatrix(relativeTo: nil)
                    )
                    onEntityReady(result)
                    canConfirm = true
                    Self.logger.info("Track placed on detected plane")
                } catch {
                    Self.logger.warning("USDZ load failed, using mock track: \(error.localizedDescription)")
                    attachMockTrack(on: planeAnchor)
                }
            }
        }

        private func attachMockTrack(on planeAnchor: ARPlaneAnchor) {
            let mock = MockTrackEntity(track: track)
            mock.entity.components.set(OpacityComponent(opacity: placementOpacity))

            let anchor = AnchorEntity(anchor: planeAnchor)
            anchor.addChild(mock.entity)
            arView?.scene.addAnchor(anchor)
            self.anchor = anchor

            onEntityReady(TrackPlacementResult(
                entity: mock.entity,
                calibratedTrack: track,
                scale: 1.0,
                worldTransform: anchor.transformMatrix(relativeTo: nil)
            ))
            canConfirm = true
        }

        // MARK: ARSessionDelegate

        nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            guard let planeAnchor = anchors.compactMap({ $0 as? ARPlaneAnchor }).first else { return }
            Task { @MainActor in
                isPlaneDetected = true
                loadTrackIfNeeded(for: planeAnchor)
            }
        }

        nonisolated func session(_ session: ARSession, didFailWithError error: Error) {
            Task { @MainActor in
                Self.logger.error("AR session failed: \(error.localizedDescription)")
                sessionError = error.localizedDescription
            }
        }

        nonisolated func sessionWasInterrupted(_ session: ARSession) {
            Task { @MainActor in
                Self.logger.warning("AR session interrupted")
                sessionError = "AR session was interrupted."
            }
        }

        nonisolated func sessionInterruptionEnded(_ session: ARSession) {
            Task { @MainActor in
                sessionError = nil
                guard let arView else { return }
                let config = ARWorldTrackingConfiguration()
                config.planeDetection = [.horizontal]
                arView.session.run(config)
            }
        }
    }
}

// MARK: - Race AR view

struct ARRaceSceneContainer: UIViewRepresentable {
    let track: Track
    let players: [PlayerState]
    let placementWorldTransform: simd_float4x4?
    @Binding var isLoading: Bool

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.automaticallyConfigureSession = false
        arView.renderOptions = [.disableDepthOfField, .disableMotionBlur]
        arView.session.delegate = context.coordinator
        context.coordinator.arView = arView
        context.coordinator.track = track
        context.coordinator.placementWorldTransform = placementWorldTransform
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.startSessionIfNeeded(on: uiView)
        Task { @MainActor in
            await context.coordinator.sceneSync.syncPlayers(players)
        }
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: RaceCoordinator) {
        uiView.session.pause()
        coordinator.reset()
    }

    func makeCoordinator() -> RaceCoordinator {
        RaceCoordinator(isLoading: $isLoading)
    }

    @MainActor
    final class RaceCoordinator: NSObject, ARSessionDelegate {
        private static let logger = Logger(subsystem: "bikebike", category: "ARRace")

        @Binding var isLoading: Bool
        let sceneSync = ARSceneSync()
        weak var arView: ARView?
        var track: Track = .downtown
        var placementWorldTransform: simd_float4x4?
        private var anchor: AnchorEntity?

        private var didStartSession = false
        private var didLoadTrack = false
        private var loadTask: Task<Void, Never>?

        init(isLoading: Binding<Bool>) {
            _isLoading = isLoading
        }

        func reset() {
            loadTask?.cancel()
            sceneSync.reset()
            didStartSession = false
            didLoadTrack = false
            anchor?.removeFromParent()
            anchor = nil
        }

        func startSessionIfNeeded(on arView: ARView) {
            guard !didStartSession, arView.bounds.width > 0, arView.bounds.height > 0 else { return }
            didStartSession = true
            self.arView = arView

            let config = ARWorldTrackingConfiguration()
            config.planeDetection = [.horizontal]
            arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
            Self.logger.info("AR session started for race")

            if placementWorldTransform != nil {
                loadTrackIfNeeded()
            }
        }

        private func loadTrackIfNeeded() {
            guard !didLoadTrack else { return }
            didLoadTrack = true
            isLoading = true

            loadTask = Task { @MainActor in
                defer { isLoading = false }
                do {
                    async let bikePreload: Void = BikeModelLoader.preload()
                    let loaded = try await TrackEntity.load(track: track)
                    await bikePreload
                    let anchor = makeAnchor()
                    anchor.addChild(loaded.entity)
                    arView?.scene.addAnchor(anchor)
                    self.anchor = anchor
                    sceneSync.trackRoot = loaded.entity
                    Self.logger.info("Race track placed on detected plane")
                } catch {
                    Self.logger.warning("Race USDZ load failed, using mock: \(error.localizedDescription)")
                    let mock = MockTrackEntity(track: track)
                    let anchor = makeAnchor()
                    anchor.addChild(mock.entity)
                    arView?.scene.addAnchor(anchor)
                    self.anchor = anchor
                    sceneSync.trackRoot = mock.entity
                }
            }
        }

        private func makeAnchor() -> AnchorEntity {
            if let placementWorldTransform {
                return AnchorEntity(world: placementWorldTransform)
            }
            return AnchorEntity(.plane(.horizontal, classification: .any, minimumBounds: [0.2, 0.2]))
        }

        nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            Task { @MainActor in
                guard placementWorldTransform == nil,
                      anchors.contains(where: { $0 is ARPlaneAnchor }) else { return }
                loadTrackIfNeeded()
            }
        }
    }
}

@MainActor
final class ARPlacementViewModel: ObservableObject {
    @Published var isPlaneDetected = false
    @Published var canConfirm = false
    @Published var isLoading = false
    @Published var guidanceText = "Move your device slowly over a flat surface"
}
