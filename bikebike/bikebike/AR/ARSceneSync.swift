import RealityKit
import ARKit

@MainActor
final class ARSceneSync {
    private var bikeEntities: [UUID: Entity] = [:]
    private var driverAssignments: [UUID: Driver] = [:]
    private var nextDriverIndex = 0

    weak var trackRoot: Entity?

    func assignDriver(for playerID: UUID, index: Int?) {
        let driverIndex = index ?? (nextDriverIndex % Driver.allCases.count)
        driverAssignments[playerID] = Driver(rawValue: driverIndex) ?? .green
        if index == nil {
            nextDriverIndex += 1
        }
    }

    func syncPlayers(_ players: [PlayerState]) async {
        guard let trackRoot else { return }

        let activeIDs = Set(players.map(\.playerID))
        for id in bikeEntities.keys where !activeIDs.contains(id) {
            bikeEntities[id]?.removeFromParent()
            bikeEntities.removeValue(forKey: id)
        }

        for player in players {
            if bikeEntities[player.playerID] == nil {
                assignDriver(for: player.playerID, index: nil)
                let driver = driverAssignments[player.playerID] ?? .green
                guard let bike = try? await BikeEntity.load(
                    driver: driver,
                    playerID: player.playerID,
                    nickname: player.nickname,
                    position: player.position
                ) else { continue }
                trackRoot.addChild(bike.entity)
                bikeEntities[player.playerID] = bike.entity
            }

            guard let entity = bikeEntities[player.playerID] else { continue }
            entity.position = player.position
            entity.transform.rotation = simd_quatf(angle: player.rotation, axis: [0, 1, 0])
        }
    }

    func reset() {
        for entity in bikeEntities.values {
            entity.removeFromParent()
        }
        bikeEntities.removeAll()
        driverAssignments.removeAll()
        nextDriverIndex = 0
    }
}
