import Foundation

protocol DethroneEventServiceProtocol: AnyObject {
    func fetchRecent(limit: Int) async throws -> [DethroneEvent]
}

final class MockDethroneEventService: DethroneEventServiceProtocol {
    func fetchRecent(limit: Int) async throws -> [DethroneEvent] {
        let now = Date()
        let events: [DethroneEvent] = [
            DethroneEvent(
                id: "e1",
                occurredAt: now.addingTimeInterval(-60 * 2),
                spotId: "s1",
                spotName: "Pier 39",
                previousKingId: "u-blackbeard",
                previousKingName: "Blackbeard",
                newKingId: "u-redhook",
                newKingName: "RedHook",
                newKingTier: .commodore,
                newCatchSizeCm: 54.2
            ),
            DethroneEvent(
                id: "e2",
                occurredAt: now.addingTimeInterval(-60 * 14),
                spotId: "s2",
                spotName: "Pacifica Cove",
                previousKingId: "u-saltybill",
                previousKingName: "SaltyBill",
                newKingId: "u-marlina",
                newKingName: "Marlina",
                newKingTier: .captain,
                newCatchSizeCm: 41.0
            ),
            DethroneEvent(
                id: "e3",
                occurredAt: now.addingTimeInterval(-60 * 47),
                spotId: "s3",
                spotName: "Sausalito Dock",
                previousKingId: "u-marlina",
                previousKingName: "Marlina",
                newKingId: "u-anchorace",
                newKingName: "AnchorAce",
                newKingTier: .firstMate,
                newCatchSizeCm: 38.6
            ),
            DethroneEvent(
                id: "e4",
                occurredAt: now.addingTimeInterval(-60 * 90),
                spotId: "s4",
                spotName: "Tahoe South Shore",
                previousKingId: "u-trouthunter",
                previousKingName: "TroutHunter",
                newKingId: "u-laketamer",
                newKingName: "LakeTamer",
                newKingTier: .admiral,
                newCatchSizeCm: 62.1
            ),
            DethroneEvent(
                id: "e5",
                occurredAt: now.addingTimeInterval(-3600 * 3),
                spotId: "s5",
                spotName: "Berkeley Marina",
                previousKingId: "u-jollyroger",
                previousKingName: "JollyRoger",
                newKingId: "u-stripenose",
                newKingName: "StripeNose",
                newKingTier: .sailor,
                newCatchSizeCm: 47.3
            )
        ]
        return Array(events.prefix(limit))
    }
}
