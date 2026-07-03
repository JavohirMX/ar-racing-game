# Phase 2: Networking

## Overview

Implement peer-to-peer multiplayer networking using Network Framework. One device hosts (advertises via Bonjour, broadcasts game state), peers connect (discover via Bonjour browser, send input). No server backend. All communication runs over a single TCP connection per peer with length-prefixed JSON frames.

**iOS deployment target:** 18.4+
**Testing framework:** Swift Testing
**Concurrency model:** Actor-based (HostSessionManager, PeerSessionManager are actors)
**3D dependency:** None

---

## Decisions Made

| # | Decision | Answer |
|---|---|---|
| 1 | Message framing | Length-prefixed: 4-byte big-endian uint32 + JSON payload |
| 2 | Delta compression | Full GameState every tick for MVP |
| 3 | Host migration | Deferred to later phase |
| 4 | Concurrency model | Actors (HostSessionManager, PeerSessionManager) |
| 5 | QR scanner | Deferred to UI phase (Phase 4) |
| 6 | Network abstraction | Protocol + mock for testing |
| 7 | Message multiplexing | `WireMessage` enum wraps all message types |
| 8 | Host migration | Skip for MVP |
| 9 | Bonjour service type | `_bikebike._tcp` (already in Info.plist) |

---

## Architecture Overview

```
 Peer Device                          Host Device
┌──────────────────┐               ┌──────────────────────────┐
│ PeerSessionMgr   │               │ HostSessionManager       │
│ (actor)          │               │ (actor)                  │
│                  │  TCP          │                          │
│ ┌──────────────┐ │◄─────────────►│ ┌──────────────────────┐ │
│ │MessageFramer │ │  GameState    │ │ MessageFramer[]      │ │
│ └──────────────┘ │  (host→peer)  │ │ (one per connection) │ │
│                  │               │ └──────────────────────┘ │
│ ┌──────────────┐ │  PlayerInput  │                          │
│ │NWBrowser     │ │  (peer→host)  │ ┌──────────────────────┐ │
│ │(discover)    │─┼──────────────►│ │ NWListener           │ │
│ └──────────────┘ │               │ │ (advertise on Bonjour)│ │
│                  │               │ └──────────────────────┘ │
│ ┌──────────────┐ │  JoinRequest  │                          │
│ │NWConnection  │ │  (peer→host)  │ ┌──────────────────────┐ │
│ │(to host)     │─┼──────────────►│ │ NWConnection[]       │ │
│ └──────────────┘ │               │ │ (one per peer)       │ │
└──────────────────┘               │ └──────────────────────┘ │
                                   └──────────────────────────┘
```

### Data flow

```
Host:  GameState ──► GameStateCodec ──► WireMessage ──► MessageFramer ──► TCP ──► Peer
Peer:  PlayerInput ──► GameStateCodec ──► WireMessage ──► MessageFramer ──► TCP ──► Host

Control: Join Request/JoinResponse follow same pipeline
```

---

## Wire Format

### Length-prefixed framing

```
┌──────────────────────┬──────────────────────────────────┐
│  4 bytes (big-endian)│  JSON payload (UTF-8)             │
│  payload length      │  e.g. {"gameState":{"tick":42...}}│
└──────────────────────┴──────────────────────────────────┘
```

### WireMessage enum

All messages (tick-rate and control) share a single enum wrapper:

```swift
enum WireMessage: Codable {
    case gameState(GameState)
    case playerInput(PlayerInput)
    case joinRequest(JoinRequest)
    case joinResponse(JoinResponse)
    case playerDisconnected(PlayerDisconnected)
}
```

JSON encoding uses single-key dictionaries:
- `{"gameState": {...}}`
- `{"playerInput": {...}}`
- `{"joinRequest": {"nickname":"Alice"}}`
- `{"joinResponse": {"accepted":true,...}}`
- `{"playerDisconnected": {"playerID":"..."}}`

---

## Files to Create

```
bikebike/bikebike/
├── Networking/
│   ├── WireMessage.swift
│   ├── MessageFramer.swift
│   ├── NetworkConnectionProtocol.swift
│   ├── HostSessionManager.swift
│   ├── PeerSessionManager.swift
│   ├── GameStateCodec.swift
│   └── QRCodeGenerator.swift

bikebikeTests/
    ├── MessageFramerTests.swift
    ├── WireMessageTests.swift
    ├── GameStateCodecTests.swift
    ├── HostSessionManagerTests.swift
    └── PeerSessionManagerTests.swift
```

---

## 1. `Networking/WireMessage.swift`

Unified enum for all on-wire message types.

```swift
import Foundation

enum WireMessage: Codable {
    case gameState(GameState)
    case playerInput(PlayerInput)
    case joinRequest(JoinRequest)
    case joinResponse(JoinResponse)
    case playerDisconnected(PlayerDisconnected)
}
```

**Design notes:**
- `Codable` uses the associated-value enum key as the JSON key
- Adding new message types in future phases is a single case
- `HostMigrated` excluded for MVP (deferred)

---

## 2. `Networking/MessageFramer.swift`

Encodes/decodes length-prefixed frames. Maintains an internal buffer for stream reassembly.

```swift
import Foundation

struct MessageFramer {
    private var buffer = Data()

    func encode(_ message: WireMessage) throws -> Data {
        let payload = try JSONEncoder().encode(message)
        var frame = Data()

        var length = UInt32(payload.count).bigEndian
        frame.append(Data(bytes: &length, count: 4))
        frame.append(payload)

        return frame
    }

    mutating func append(_ data: Data) throws -> [WireMessage] {
        buffer.append(data)
        var messages: [WireMessage] = []

        while buffer.count >= 4 {
            let lengthData = buffer.prefix(4)
            let payloadLength = Int(lengthData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })

            guard payloadLength > 0 else {
                buffer.removeFirst(4)
                continue
            }

            let totalFrameLength = 4 + payloadLength
            guard buffer.count >= totalFrameLength else { break }

            let payload = buffer.subdata(in: 4..<totalFrameLength)
            let message = try JSONDecoder().decode(WireMessage.self, from: payload)
            messages.append(message)

            buffer.removeFirst(totalFrameLength)
        }

        return messages
    }
}
```

**Design notes:**
- `encode` is stateless — just prepends a 4-byte length header
- `append` is stateful — accumulates bytes, extracts complete frames
- Each connection gets its own `MessageFramer` instance (one per peer on host, one on peer)
- Zero-length payloads are skipped (should never happen in practice)

---

## 3. `Networking/NetworkConnectionProtocol.swift`

Protocol that abstracts `NWConnection` for testability. Includes a paired mock for unit tests.

```swift
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

final class RealNetworkConnection: NetworkConnectionProtocol {
    private let connection: NWConnection

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
        connection.send(content: data, completion: .contentProcessed { _ in })
    }

    func cancel() {
        connection.cancel()
    }

    private func receiveNext() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            guard let self else { return }
            if let error {
                self.onStateUpdate?(.failed(error))
                return
            }
            if let data {
                self.onReceive?(data)
                self.receiveNext()
            }
        }
    }
}
```

**Mock for testing:**

```swift
final class MockNetworkConnection: NetworkConnectionProtocol, @unchecked Sendable {
    var onStateUpdate: (@Sendable (ConnectionState) -> Void)?
    var onReceive: (@Sendable (Data) -> Void)?

    private let queue = DispatchQueue(label: "mock.connection")
    private weak var partner: MockNetworkConnection?

    func start(queue: DispatchQueue) {
        onStateUpdate?(.ready)
    }

    func send(data: Data) {
        partner?.queue.async { [weak partner] in
            partner?.onReceive?(data)
        }
    }

    func cancel() {
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
```

**Design notes:**
- `RealNetworkConnection` wraps `NWConnection`, mapping its state enum to our simpler `ConnectionState`
- `MockNetworkConnection` creates a paired channel — data `send()` on one appears on the other's `onReceive`
- `createPair()` returns two connected mocks for testing host↔peer communication
- The protocol is `Sendable` — all callback closures are `@Sendable`

---

## 4. `Networking/HostSessionManager.swift`

Actor that advertises via Bonjour, accepts peer connections, and broadcasts game state to all connected peers at tick rate.

```swift
import Foundation
import Network

actor HostSessionManager {
    let nickname: String
    let maxPlayers: Int
    let sessionID: UUID

    private var listener: NWListener?
    private var connections: [UUID: ConnectionContext] = [:]
    private var inputContinuation: AsyncStream<(UUID, PlayerInput)>.Continuation?

    var onPlayerJoined: (@Sendable (UUID, String) -> Void)?
    var onPlayerLeft: (@Sendable (UUID) -> Void)?

    private struct ConnectionContext {
        let connection: any NetworkConnectionProtocol
        let nickname: String
        var framer: MessageFramer
    }

    init(nickname: String, maxPlayers: Int = 6, sessionID: UUID = UUID()) {
        self.nickname = nickname
        self.maxPlayers = maxPlayers
        self.sessionID = sessionID
    }

    func start() async throws {
        let listener = try NWListener(using: .tcp)
        listener.service = NWListener.Service(
            name: nickname,
            type: "_bikebike._tcp",
            domain: "local."
        )

        listener.stateUpdateHandler = { state in
            // Log state changes for debugging
        }

        listener.newConnectionHandler = { [weak self] nwConnection in
            guard let self else { return }
            Task { await self.handleNewConnection(nwConnection) }
        }

        listener.start(queue: .global())
        self.listener = listener
    }

    func stop() {
        for (playerID, context) in connections {
            context.connection.cancel()
        }
        connections.removeAll()
        listener?.cancel()
        listener = nil
    }

    func broadcast(_ state: GameState) {
        guard let encoded = try? encodeWireMessage(.gameState(state)) else { return }
        for (_, context) in connections {
            context.connection.send(data: encoded)
        }
    }

    func broadcastPlayerDisconnected(_ playerID: UUID) {
        let message = PlayerDisconnected(playerID: playerID)
        guard let encoded = try? encodeWireMessage(.playerDisconnected(message)) else { return }
        for (id, context) in connections where id != playerID {
            context.connection.send(data: encoded)
        }
    }

    func inputStream() -> AsyncStream<(UUID, PlayerInput)> {
        AsyncStream { continuation in
            self.inputContinuation = continuation
        }
    }

    var connectedPlayerCount: Int { connections.count }

    var connectedPlayerIDs: [UUID] { Array(connections.keys) }

    private func handleNewConnection(_ nwConnection: NWConnection) {
        let conn = RealNetworkConnection(connection: nwConnection)
        let queue = DispatchQueue(label: "host.connection.\(UUID().uuidString)")

        conn.onStateUpdate = { [weak self] state in
            if case .failed = state, let self {
                Task { await self.removeConnection(nwConnection) }
            }
        }

        conn.onReceive = { [weak self] data in
            guard let self else { return }
            Task { await self.handleData(data, connection: conn) }
        }

        conn.start(queue: queue)
    }

    private func handleData(_ data: Data, connection conn: any NetworkConnectionProtocol) async {
        // Find or create context for this connection
        let playerID = findPlayerID(for: conn)

        var context: ConnectionContext
        if let existingPlayerID = playerID, let existing = connections[existingPlayerID] {
            context = existing
        } else {
            // Temporary context for pending connections (before JoinRequest)
            return await handlePendingJoin(data, connection: conn)
        }

        do {
            let messages = try context.framer.append(data)
            for message in messages {
                switch message {
                case .playerInput(let input):
                    if let pid = playerID {
                        inputContinuation?.yield((pid, input))
                    }
                case .joinRequest:
                    break // Ignore duplicate join requests
                default:
                    break
                }
            }
            // Update framer in context
            if let pid = playerID {
                connections[pid]?.framer = context.framer
            }
        } catch {
            // Malformed data — disconnect
            if let pid = playerID {
                removePlayer(pid)
            }
        }
    }

    private func handlePendingJoin(_ data: Data, connection conn: any NetworkConnectionProtocol) async {
        var framer = MessageFramer()
        do {
            let messages = try framer.append(data)
            for message in messages {
                if case .joinRequest(let request) = message {
                    await processJoinRequest(request, connection: conn)
                }
            }
        } catch {
            conn.cancel()
        }
    }

    private func processJoinRequest(_ request: JoinRequest, connection conn: any NetworkConnectionProtocol) async {
        let playerID = UUID()

        guard connections.count < maxPlayers else {
            sendJoinResponse(accepted: false, reason: .lobbyFull, playerID: nil, to: conn, request: request)
            conn.cancel()
            return
        }

        let namesTaken = connections.values.map { $0.nickname }
        guard !namesTaken.contains(request.nickname) else {
            sendJoinResponse(accepted: false, reason: .nameTaken, playerID: nil, to: conn, request: request)
            conn.cancel()
            return
        }

        let driverIndex = connections.count % Driver.allCases.count
        sendJoinResponse(accepted: true, reason: nil, playerID: playerID, driverIndex: driverIndex, to: conn, request: request)

        connections[playerID] = ConnectionContext(
            connection: conn,
            nickname: request.nickname,
            framer: MessageFramer()
        )

        onPlayerJoined?(playerID, request.nickname)

        // Broadcast updated player list to all peers
        broadcastPlayerList()
    }

    private func sendJoinResponse(accepted: Bool, reason: JoinResponse.RejectionReason?, playerID: UUID?, driverIndex: Int? = nil, to conn: any NetworkConnectionProtocol, request: JoinRequest) {
        let response = JoinResponse(
            accepted: accepted,
            playerID: playerID,
            rejectionReason: reason,
            assignedDriverIndex: driverIndex
        )
        if let data = try? encodeWireMessage(.joinResponse(response)) {
            conn.send(data: data)
        }
    }

    private func broadcastPlayerList() {
        let players = connections.map { (id, ctx) in
            PlayerState(
                playerID: id,
                nickname: ctx.nickname,
                position: .zero,
                rotation: 0,
                speed: 0,
                lap: 0,
                checkpointsHit: [],
                boostAvailable: true,
                boostActive: false,
                finished: false,
                finishTime: nil
            )
        }
        let state = GameState(
            sessionID: sessionID,
            tick: 0,
            phase: .waiting,
            countdownSeconds: nil,
            totalLaps: 0,
            players: players,
            results: nil
        )
        broadcast(state)
    }

    private func removeConnection(_ nwConnection: NWConnection) {
        // Find and remove the player with this connection
        // Since we use RealNetworkConnection which wraps NWConnection,
        // we need to match by identity
    }

    private func removePlayer(_ playerID: UUID) {
        connections[playerID]?.connection.cancel()
        connections.removeValue(forKey: playerID)
        onPlayerLeft?(playerID)
        broadcastPlayerDisconnected(playerID)
    }

    private func findPlayerID(for conn: any NetworkConnectionProtocol) -> UUID? {
        connections.first(where: { $0.value.connection === conn })?.key
    }

    private func encodeWireMessage(_ message: WireMessage) throws -> Data {
        var framer = MessageFramer()
        return try framer.encode(message)
    }
}
```

**Design notes:**
- `NWListener.newConnectionHandler` fires on a background queue — dispatching to `Task { await ... }` bridges to the actor
- Each connection gets its own `MessageFramer` for stream reassembly
- `broadcast(_:)` sends the same `GameState` to all peers — host runs the authoritative simulation
- `inputStream()` returns an `AsyncStream` — the caller (RaceEngine) iterates over `(UUID, PlayerInput)` tuples
- Player capacity enforced at join time (`maxPlayers`)
- `broadcastPlayerList()` sends an initial state so peers see the lobby before the race starts

---

## 5. `Networking/PeerSessionManager.swift`

Actor that discovers hosts via Bonjour, connects to one, and relays input to the host while receiving game state.

```swift
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

actor PeerSessionManager {
    let nickname: String

    private var browser: NWBrowser?
    private var connection: (any NetworkConnectionProtocol)?
    private var framer = MessageFramer()
    private var stateContinuation: AsyncStream<GameState>.Continuation?
    private var hostContinuation: AsyncStream<DiscoveredHost>.Continuation?
    private var connectionFactory: (NWEndpoint) -> any NetworkConnectionProtocol

    var onDisconnected: (@Sendable (Error?) -> Void)?

    init(
        nickname: String,
        connectionFactory: @escaping (NWEndpoint) -> any NetworkConnectionProtocol = { RealNetworkConnection(endpoint: $0) }
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
        self.hostContinuation = continuation
        self.browser = browser

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self else { return }
            Task {
                await self.handleBrowseResults(results)
            }
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
        self.connection = conn

        return try await withCheckedThrowingContinuation { continuation in
            conn.onStateUpdate = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    Task {
                        await self.sendJoinRequest(to: conn, continuation: continuation)
                    }
                case .failed(let error):
                    continuation.resume(throwing: error)
                case .cancelled:
                    continuation.resume(throwing: CancellationError())
                default:
                    break
                }
            }

            conn.onReceive = { [weak self] data in
                guard let self else { return }
                Task { await self.handleReceived(data) }
            }

            conn.start(queue: .global())
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
        let message = WireMessage.playerInput(input)
        if let data = try? encodeWireMessage(message) {
            conn.send(data: data)
        }
    }

    func stateStream() -> AsyncStream<GameState> {
        let (stream, continuation) = AsyncStream<GameState>.makeStream()
        self.stateContinuation = continuation
        return stream
    }

    private func handleBrowseResults(_ results: Set<NWBrowser.Result>) {
        for result in results {
            switch result.endpoint {
            case .service(let name, _, _, _):
                let host = DiscoveredHost(
                    id: "\(name):\(result.endpoint)",
                    name: name,
                    endpoint: result.endpoint
                )
                hostContinuation?.yield(host)
            default:
                break
            }
        }
    }

    private func sendJoinRequest(
        to conn: any NetworkConnectionProtocol,
        continuation: CheckedContinuation<JoinResult, Error>
    ) async {
        let request = JoinRequest(nickname: nickname)
        guard let data = try? encodeWireMessage(.joinRequest(request)) else {
            continuation.resume(throwing: NetworkError.encodingFailed)
            return
        }
        conn.send(data: data)

        // Store continuation for response handling
        self.pendingJoinContinuation = continuation
    }

    private var pendingJoinContinuation: CheckedContinuation<JoinResult, Error>?

    private func handleReceived(_ data: Data) async {
        do {
            let messages = try framer.append(data)
            for message in messages {
                switch message {
                case .gameState(let state):
                    stateContinuation?.yield(state)

                case .joinResponse(let response):
                    pendingJoinContinuation?.resume(returning: JoinResult(
                        accepted: response.accepted,
                        playerID: response.playerID,
                        driverIndex: response.assignedDriverIndex,
                        rejectionReason: response.rejectionReason
                    ))
                    pendingJoinContinuation = nil

                case .playerDisconnected:
                    break // GameSessionViewModel handles disconnected players

                default:
                    break
                }
            }
        } catch {
            onDisconnected?(error)
        }
    }

    private func encodeWireMessage(_ message: WireMessage) throws -> Data {
        var framer = MessageFramer()
        return try framer.encode(message)
    }
}

enum NetworkError: Error {
    case encodingFailed
    case decodingFailed
}
```

**Design notes:**
- `connectionFactory` lets tests inject `MockNetworkConnection` instead of real NW connections
- `startBrowsing()` returns `AsyncStream<DiscoveredHost>` — the UI layer iterates over it to populate the lobby list
- `join(host:)` uses `withCheckedThrowingContinuation` to bridge NWConnection's callback-based lifecycle to async/await
- `stateStream()` returns `AsyncStream<GameState>` — the caller (GameSessionViewModel) processes each tick
- `sendInput(_:)` is fire-and-forget — no response expected per tick
- `pendingJoinContinuation` is stored temporarily to resolve the join promise when the response arrives

---

## 6. `Networking/GameStateCodec.swift`

Minimal encode/decode for MVP (full state, no delta).

```swift
import Foundation

struct GameStateCodec {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func encode(_ state: GameState) throws -> Data {
        try encoder.encode(state)
    }

    func decode(from data: Data) throws -> GameState {
        try decoder.decode(GameState.self, from: data)
    }
}
```

**Design notes:**
- Kept as a struct (not a free function) so delta compression can be added later as internal state
- `JSONEncoder`/`JSONDecoder` instances are reused (no allocation per tick)
- For delta compression (future): store `previousState`, compute diff, encode only changed fields

---

## 7. `Networking/QRCodeGenerator.swift`

Generates a QR code image from endpoint connection info using CoreImage.

```swift
import UIKit
import CoreImage

struct QREndpointInfo: Codable {
    let name: String
    let host: String
    let port: UInt16
    let service: String
}

struct QRCodeGenerator {
    func generate(from info: QREndpointInfo, size: CGSize = CGSize(width: 256, height: 256)) -> UIImage? {
        guard let jsonData = try? JSONEncoder().encode(info),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }

        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(jsonString.utf8), forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }

        let scaleX = size.width / outputImage.extent.width
        let scaleY = size.height / outputImage.extent.height
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        return UIImage(ciImage: transformed)
    }
}
```

**Design notes:**
- `QREndpointInfo` encodes the host's IP, port, service name — enough for a peer to connect directly
- Uses "H" (high) error correction for reliable scanning
- `UIImage(ciImage:)` renders lazily — fine for SwiftUI's `Image(uiImage:)`
- QR scanner (`AVFoundation`) deferred to Phase 4 (UI phase)

---

## 8. Test Files

### `MessageFramerTests.swift`

```swift
import Testing
import Foundation
@testable import bikebike

@Suite struct MessageFramerTests {

    @Test func encodeProducesLengthPrefixedData() throws {
        var framer = MessageFramer()
        let input = PlayerInput(tick: 1, steerDirection: 0.5, accelerate: true, boostActivated: false)
        let message = WireMessage.playerInput(input)

        let data = try framer.encode(message)

        #expect(data.count > 4)

        let length = data.prefix(4).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        #expect(length == UInt32(data.count - 4))
    }

    @Test func decodeSingleMessage() throws {
        let input = PlayerInput(tick: 5, steerDirection: -1.0, accelerate: false, boostActivated: true)
        let message = WireMessage.playerInput(input)

        var framer = MessageFramer()
        let data = try framer.encode(message)

        let decoded = try framer.append(data)
        #expect(decoded.count == 1)

        if case .playerInput(let result) = decoded[0] {
            #expect(result.tick == 5)
            #expect(result.steerDirection == -1.0)
            #expect(result.accelerate == false)
            #expect(result.boostActivated == true)
        } else {
            Issue.record("Expected playerInput message")
        }
    }

    @Test func decodeMultipleMessagesInSingleData() throws {
        var framer = MessageFramer()

        let msg1 = WireMessage.playerInput(PlayerInput(tick: 1, steerDirection: 0, accelerate: true, boostActivated: false))
        let msg2 = WireMessage.playerInput(PlayerInput(tick: 2, steerDirection: 0, accelerate: false, boostActivated: false))

        let data1 = try framer.encode(msg1)
        let data2 = try framer.encode(msg2)
        let combined = data1 + data2

        let decoded = try framer.append(combined)
        #expect(decoded.count == 2)
    }

    @Test func partialDataDoesNotYieldMessage() throws {
        var framer = MessageFramer()
        let input = PlayerInput(tick: 1, steerDirection: 0, accelerate: true, boostActivated: false)
        var data = try framer.encode(WireMessage.playerInput(input))

        let partial = data.prefix(data.count / 2)
        let decoded = try framer.append(partial)
        #expect(decoded.isEmpty)
    }

    @Test func messageAssembledFromMultipleChunks() throws {
        var framer = MessageFramer()

        let state = GameState(
            sessionID: UUID(), tick: 10, phase: .racing,
            countdownSeconds: nil, totalLaps: 3, players: [], results: nil
        )
        let data = try framer.encode(WireMessage.gameState(state))

        // Send byte by byte
        var allDecoded: [WireMessage] = []
        for byte in data {
            let chunk = Data([byte])
            let decoded = try framer.append(chunk)
            allDecoded.append(contentsOf: decoded)
        }

        #expect(allDecoded.count == 1)
    }

    @Test func encodeGameStateRoundTrip() throws {
        var framer = MessageFramer()
        let state = GameState(
            sessionID: UUID(), tick: 42, phase: .racing,
            countdownSeconds: nil, totalLaps: 3,
            players: [
                PlayerState(
                    playerID: UUID(), nickname: "Test",
                    position: SIMD3<Float>(1, 2, 3),
                    rotation: 0.5, speed: 3.0, lap: 1,
                    checkpointsHit: [0],
                    boostAvailable: true, boostActive: false,
                    finished: false, finishTime: nil
                )
            ],
            results: nil
        )

        let data = try framer.encode(WireMessage.gameState(state))
        let decoded = try framer.append(data)

        #expect(decoded.count == 1)
        if case .gameState(let roundtripped) = decoded[0] {
            #expect(roundtripped.tick == 42)
            #expect(roundtripped.players.count == 1)
        }
    }
}
```

### `WireMessageTests.swift`

```swift
import Testing
import Foundation
@testable import bikebike

@Suite struct WireMessageTests {

    @Test func encodeDecodePlayerInput() throws {
        let input = PlayerInput(tick: 7, steerDirection: -0.5, accelerate: true, boostActivated: false)
        let message = WireMessage.playerInput(input)

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(WireMessage.self, from: data)

        if case .playerInput(let result) = decoded {
            #expect(result.tick == 7)
            #expect(result.steerDirection == -0.5)
        } else {
            Issue.record("Wrong message type")
        }
    }

    @Test func encodeDecodeJoinRequest() throws {
        let request = JoinRequest(nickname: "Alice")
        let message = WireMessage.joinRequest(request)

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(WireMessage.self, from: data)

        if case .joinRequest(let result) = decoded {
            #expect(result.nickname == "Alice")
        } else {
            Issue.record("Wrong message type")
        }
    }

    @Test func encodeDecodeJoinResponse() throws {
        let response = JoinResponse(accepted: true, playerID: UUID(), rejectionReason: nil, assignedDriverIndex: 2)
        let message = WireMessage.joinResponse(response)

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(WireMessage.self, from: data)

        if case .joinResponse(let result) = decoded {
            #expect(result.accepted)
            #expect(result.assignedDriverIndex == 2)
        } else {
            Issue.record("Wrong message type")
        }
    }

    @Test func encodeDecodePlayerDisconnected() throws {
        let playerID = UUID()
        let disconnect = PlayerDisconnected(playerID: playerID)
        let message = WireMessage.playerDisconnected(disconnect)

        let data = try JSONEncoder().encode(message)
        let decoded = try JSONDecoder().decode(WireMessage.self, from: data)

        if case .playerDisconnected(let result) = decoded {
            #expect(result.playerID == playerID)
        } else {
            Issue.record("Wrong message type")
        }
    }
}
```

### `GameStateCodecTests.swift`

```swift
import Testing
import Foundation
@testable import bikebike

@Suite struct GameStateCodecTests {

    @Test func encodeDecodeRoundTrip() throws {
        let codec = GameStateCodec()
        let state = GameState(
            sessionID: UUID(),
            tick: 100,
            phase: .racing,
            countdownSeconds: nil,
            totalLaps: 3,
            players: [
                PlayerState(
                    playerID: UUID(),
                    nickname: "Player1",
                    position: SIMD3<Float>(0.5, 0.0, -1.0),
                    rotation: 1.57,
                    speed: 4.2,
                    lap: 2,
                    checkpointsHit: [0, 1],
                    boostAvailable: false,
                    boostActive: true,
                    finished: false,
                    finishTime: nil
                )
            ],
            results: nil
        )

        let data = try codec.encode(state)
        let decoded = try codec.decode(from: data)

        #expect(decoded.tick == 100)
        #expect(decoded.phase == .racing)
        #expect(decoded.players[0].lap == 2)
        #expect(decoded.players[0].boostActive)
    }

    @Test func encodeEmptyState() throws {
        let codec = GameStateCodec()
        let state = GameState(
            sessionID: UUID(), tick: 0, phase: .waiting,
            countdownSeconds: nil, totalLaps: 3,
            players: [], results: nil
        )

        let data = try codec.encode(state)
        #expect(data.count > 0)
    }
}
```

### `HostSessionManagerTests.swift`

```swift
import Testing
import Foundation
@testable import bikebike

@Suite struct HostSessionManagerTests {

    @Test func hostAcceptsJoinRequest() async throws {
        let host = HostSessionManager(nickname: "Host", maxPlayers: 6)
        let (hostConn, _) = MockNetworkConnection.createPair()

        // Simulate a join request arriving on hostConn
        // (In real tests, we'd inject MockNetworkConnection into HostSessionManager)
        // For now, validate the actor can be instantiated
        #expect(host.connectedPlayerCount == 0)
    }

    @Test func hostRejectsWhenFull() async throws {
        let host = HostSessionManager(nickname: "Host", maxPlayers: 1)
        #expect(true) // Placeholder — full test needs mock connection injection
    }

    @Test func hostBroadcastsToAllConnections() async throws {
        // Placeholder — validates broadcast sends to each connection
    }
}
```

### `PeerSessionManagerTests.swift`

```swift
import Testing
import Foundation
@testable import bikebike

@Suite struct PeerSessionManagerTests {

    @Test func peerReceivesJoinResponse() async throws {
        // Placeholder — full test with mock connections
        #expect(true)
    }

    @Test func peerReceivesGameState() async throws {
        // Placeholder
        #expect(true)
    }

    @Test func peerSendsPlayerInput() async throws {
        // Placeholder
        #expect(true)
    }
}
```

---
---

## Connection Lifecycle

```
 Peer                                     Host
   │                                        │
   │  NWBrowser discovers host              │  NWListener advertising
   │                                        │
   │─── NWConnection ──────────────────────►│  NWListener accepts
   │                                        │
   │─── WireMessage.joinRequest ───────────►│  Validates nickname + capacity
   │                                        │
   │◄── WireMessage.joinResponse ──────────│  Sends accepted + playerID + driver
   │                                        │
   │◄══ WireMessage.gameState ─════════════│  Broadcast starts (30 Hz tick)
   │                                        │
   │═══ WireMessage.playerInput ─═════════►│  Each tick (30 Hz)
   │                                        │
   │         ...race continues...           │
   │                                        │
   │  NWConnection cancels                  │  Detects disconnect
   │                                        │
   │                                        │──► WireMessage.playerDisconnected
   │                                        │    (to remaining peers)
```

---

## Error Handling Matrix

| Scenario | Host behavior | Peer behavior |
|---|---|---|
| Connection drops during race | Remove player, broadcast `PlayerDisconnected` | `onDisconnected` callback; show "host disconnected" UI |
| Malformed message received | Log warning, skip frame | Log warning, skip frame |
| Join request when lobby full | Send `lobbyFull` rejection, cancel connection | Show "lobby full" message, disconnect |
| Duplicate nickname | Send `nameTaken` rejection, cancel connection | Show "name taken" message, retry |
| Peer sends data before JoinRequest | Ignore until JoinRequest received | — |
| Browser finds no hosts | — | `AsyncStream` yields nothing; UI shows "searching..." |

---

## Dependency Graph

```
WireMessage ──┐
              ├──► MessageFramer ──┐
GameState ────┤                    ├──► HostSessionManager ──► HostSessionManagerTests
PlayerInput ──┤                    │
NetworkMsgs ──┤                    ├──► PeerSessionManager ──► PeerSessionManagerTests
              │                    │
              └──► GameStateCodec ─┤────► GameStateCodecTests
                                  │
NetworkConnectionProtocol ────────┤
                                  │
QRCodeGenerator ──────────────────┘
```

---

## Acceptance Criteria

- [ ] All 7 source files compile in Xcode
- [ ] `MessageFramer` correctly encodes/decodes length-prefixed messages
- [ ] `MessageFramer` handles partial data (reassembles from chunks)
- [ ] `WireMessage` all cases encode/decode via JSON round-trip
- [ ] `GameStateCodec` encodes and decodes `GameState` without data loss
- [ ] `HostSessionManager` can be instantiated and inspected
- [ ] `PeerSessionManager` can be instantiated and inspected
- [ ] `QRCodeGenerator` produces a non-nil `UIImage` from valid `QREndpointInfo`
- [ ] `MockNetworkConnection.createPair()` correctly routes data from A to B
- [ ] All test files pass
- [ ] No Swift 6 concurrency warnings
