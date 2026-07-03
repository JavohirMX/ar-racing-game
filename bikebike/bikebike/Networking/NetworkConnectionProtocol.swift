import Foundation
import Network

enum ConnectionState: Sendable {
    case setup
    case preparing
    case ready
    case failed(Error)
    case cancelled

    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }
}

protocol NetworkConnectionProtocol: AnyObject, Sendable {
    var onStateUpdate: (@Sendable (ConnectionState) -> Void)? { get set }
    var onReceive: (@Sendable (Data) -> Void)? { get set }
    func start(queue: DispatchQueue)
    func send(data: Data)
    func cancel()
}

final class RealNetworkConnection: NetworkConnectionProtocol, @unchecked Sendable {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "receive.\(UUID().uuidString)")
    private var receiveBuffer = Data()

    var onStateUpdate: (@Sendable (ConnectionState) -> Void)?
    var onReceive: (@Sendable (Data) -> Void)?

    init(endpoint: NWEndpoint, using params: NWParameters = .tcp) {
        self.connection = NWConnection(to: endpoint, using: params)
    }

    init(connection: NWConnection) {
        self.connection = connection
    }

    func start(queue: DispatchQueue) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .setup:     self?.onStateUpdate?(.setup)
            case .preparing: self?.onStateUpdate?(.preparing)
            case .ready:     self?.onStateUpdate?(.ready)
            case .failed(let error): self?.onStateUpdate?(.failed(error))
            case .cancelled: self?.onStateUpdate?(.cancelled)
            case .waiting(let error): self?.onStateUpdate?(.failed(error))
            @unknown default: break
            }
        }
        connection.start(queue: queue)
        receiveNext()
    }

    func send(data: Data) {
        let count = UInt32(data.count)
        var header = Data()
        header.append(UInt8((count >> 24) & 0xFF))
        header.append(UInt8((count >> 16) & 0xFF))
        header.append(UInt8((count >> 8) & 0xFF))
        header.append(UInt8(count & 0xFF))
        header.append(data)

        connection.send(
            content: header,
            contentContext: .defaultMessage,
            isComplete: true,
            completion: .contentProcessed { _ in }
        )
    }

    func cancel() {
        connection.cancel()
    }

    private func receiveNext() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 131072) { [weak self] data, _, _, error in
            guard let self else { return }
            if let error {
                self.onStateUpdate?(.failed(error))
                return
            }
            if let data, !data.isEmpty {
                self.handleReceived(data)
            }
            self.receiveNext()
        }
    }

    private func handleReceived(_ data: Data) {
        receiveBuffer.append(data)

        while receiveBuffer.count >= 4 {
            let b0 = UInt32(receiveBuffer[0])
            let b1 = UInt32(receiveBuffer[1])
            let b2 = UInt32(receiveBuffer[2])
            let b3 = UInt32(receiveBuffer[3])
            let payloadLength = Int(b0 << 24 | b1 << 16 | b2 << 8 | b3)

            guard payloadLength > 0, payloadLength <= 1_048_576 else {
                receiveBuffer.removeAll()
                onStateUpdate?(.failed(NetworkError.connectionFailed("Invalid frame length")))
                return
            }

            let totalFrameLength = 4 + payloadLength
            guard receiveBuffer.count >= totalFrameLength else { break }

            let payload = receiveBuffer.subdata(in: 4..<totalFrameLength)
            onReceive?(payload)
            receiveBuffer.removeFirst(totalFrameLength)
        }
    }
}

final class MockNetworkConnection: NetworkConnectionProtocol, @unchecked Sendable {
    var onStateUpdate: (@Sendable (ConnectionState) -> Void)?
    var onReceive: (@Sendable (Data) -> Void)?

    private let queue = DispatchQueue(label: "mock.connection.\(UUID().uuidString)")
    private weak var partner: MockNetworkConnection?
    private(set) var isActive = false

    func start(queue: DispatchQueue) {
        isActive = true
        onStateUpdate?(.ready)
    }

    func send(data: Data) {
        partner?.queue.async { [weak partner] in
            guard let partner, partner.isActive else { return }
            partner.onReceive?(data)
        }
    }

    func cancel() {
        isActive = false
        onStateUpdate?(.cancelled)
    }

    static func createPair() -> (MockNetworkConnection, MockNetworkConnection) {
        let a = MockNetworkConnection()
        let b = MockNetworkConnection()
        a.partner = b
        b.partner = a
        return (a, b)
    }
}
