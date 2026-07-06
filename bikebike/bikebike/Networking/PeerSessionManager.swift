import Foundation
import Network

struct DiscoveredHost: Sendable, Identifiable {
    let id: String
    let name: String
    let endpoint: NWEndpoint
}

struct JoinResult: Sendable {
    let accepted: Bool
    let playerID: UUID?
    let driverIndex: Int?
    let rejectionReason: JoinResponse.RejectionReason?
}

enum NetworkError: Error, Sendable {
    case encodingFailed
    case decodingFailed
    case connectionFailed(String)
}

private final class JoinContinuationBox: @unchecked Sendable {
    var continuation: CheckedContinuation<JoinResult, Error>?

    init(_ continuation: CheckedContinuation<JoinResult, Error>) {
        self.continuation = continuation
    }

    func resume(returning result: JoinResult) {
        continuation?.resume(returning: result)
        continuation = nil
    }

    func resume(throwing error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

actor PeerSessionManager {
    nonisolated let nickname: String

    private var browser: NWBrowser?
    private var connection: (any NetworkConnectionProtocol)?
    private var stateContinuation: AsyncStream<GameState>.Continuation?
    private var hostContinuation: AsyncStream<DiscoveredHost>.Continuation?
    private var connectionFactory: @Sendable (NWEndpoint) -> any NetworkConnectionProtocol

    private var onDisconnected: (@Sendable (Error?) -> Void)?

    func setOnDisconnected(_ handler: @escaping @Sendable (Error?) -> Void) { onDisconnected = handler }

    init(
        nickname: String,
        connectionFactory: @escaping @Sendable (NWEndpoint) -> any NetworkConnectionProtocol = { RealNetworkConnection(endpoint: $0) }
    ) {
        self.nickname = nickname
        self.connectionFactory = connectionFactory
    }

    func startBrowsing() -> AsyncStream<DiscoveredHost> {
        let browser = NWBrowser(
            for: .bonjour(type: "_bikebike._tcp", domain: "local."),
            using: .tcp
        )

        let (stream, continuation) = AsyncStream<DiscoveredHost>.makeStream()
        hostContinuation = continuation
        self.browser = browser

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self else { return }
            Task { await self.handleBrowseResults(results) }
        }

        browser.start(queue: .global())
        return stream
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil
        hostContinuation?.finish()
        hostContinuation = nil
    }

    func join(host: DiscoveredHost) async throws -> JoinResult {
        let conn = connectionFactory(host.endpoint)
        connection = conn

        return try await withCheckedThrowingContinuation { continuation in
            let joinBox = JoinContinuationBox(continuation)

            conn.onStateUpdate = { @Sendable state in
                switch state {
                case .failed(let error):
                    joinBox.resume(throwing: error)
                case .cancelled:
                    joinBox.resume(throwing: CancellationError())
                default:
                    break
                }
            }

            conn.onReceive = { @Sendable [weak self] data in
                Task { await self?.handleMessage(data, joinBox: joinBox) }
            }

            conn.start(queue: .global())

            if let data = try? JSONEncoder().encode(
                WireMessage.joinRequest(JoinRequest(nickname: nickname))
            ) {
                conn.send(data: data)
            } else {
                joinBox.resume(throwing: NetworkError.encodingFailed)
            }
        }
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        stateContinuation?.finish()
        stateContinuation = nil
    }

    func sendInput(_ input: PlayerInput) {
        guard let conn = connection else { return }
        if let data = try? JSONEncoder().encode(WireMessage.playerInput(input)) {
            conn.send(data: data)
        }
    }

    func stateStream() -> AsyncStream<GameState> {
        let (stream, continuation) = AsyncStream<GameState>.makeStream()
        stateContinuation = continuation
        return stream
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        for result in results {
            if case .service(let name, _, _, _) = result.endpoint {
                let host = DiscoveredHost(
                    id: "\(name):\(result.endpoint)",
                    name: name,
                    endpoint: result.endpoint
                )
                hostContinuation?.yield(host)
            }
        }
    }

    private func handleMessage(_ data: Data, joinBox: JoinContinuationBox) async {
        do {
            let message = try JSONDecoder().decode(WireMessage.self, from: data)

            switch message {
            case .gameState(let state):
                stateContinuation?.yield(state)

            case .joinResponse(let response):
                let result = JoinResult(
                    accepted: response.accepted,
                    playerID: response.playerID,
                    driverIndex: response.assignedDriverIndex,
                    rejectionReason: response.rejectionReason
                )
                joinBox.resume(returning: result)

                if !response.accepted {
                    disconnect()
                }

            case .playerDisconnected:
                break

            default:
                break
            }
        } catch {
            onDisconnected?(error)
        }
    }
}
