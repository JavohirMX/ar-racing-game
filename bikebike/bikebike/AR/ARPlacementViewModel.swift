import ARKit
import RealityKit
import SwiftUI
import Combine

struct ARPlacementContainer: UIViewRepresentable {
    let track: Track
    @Binding var isPlaneDetected: Bool
    @Binding var canConfirm: Bool
    var onEntityReady: (Entity) -> Void

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.session.delegate = context.coordinator

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        arView.session.run(config)

        let trackEntity = MockTrackEntity(track: track)
        trackEntity.entity.components.set(OpacityComponent(opacity: 0.5))
        let anchor = AnchorEntity(.plane(.horizontal, classification: .any, minimumBounds: [0.2, 0.2]))
        anchor.addChild(trackEntity.entity)
        arView.scene.addAnchor(anchor)
        context.coordinator.anchor = anchor
        onEntityReady(trackEntity.entity)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isPlaneDetected: $isPlaneDetected, canConfirm: $canConfirm)
    }

    final class Coordinator: NSObject, ARSessionDelegate {
        @Binding var isPlaneDetected: Bool
        @Binding var canConfirm: Bool
        var anchor: AnchorEntity?

        init(isPlaneDetected: Binding<Bool>, canConfirm: Binding<Bool>) {
            _isPlaneDetected = isPlaneDetected
            _canConfirm = canConfirm
        }

        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            if anchors.contains(where: { $0 is ARPlaneAnchor }) {
                isPlaneDetected = true
                canConfirm = true
            }
        }
    }
}

@MainActor
final class ARPlacementViewModel: ObservableObject {
    @Published var isPlaneDetected = false
    @Published var canConfirm = false
    @Published var guidanceText = "Move your device slowly over a flat surface"
}
