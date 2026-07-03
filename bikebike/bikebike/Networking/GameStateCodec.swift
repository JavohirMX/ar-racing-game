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
