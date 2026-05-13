import Foundation

protocol DethroneEventServiceProtocol: AnyObject {
    func fetchRecent(limit: Int) async throws -> [DethroneEvent]
}

final class SupabaseDethroneEventService: DethroneEventServiceProtocol {
    private let catchRepository: CatchRepositoryProtocol
    private let spotRepository: SpotRepositoryProtocol
    private let userRepository: UserRepositoryProtocol

    init(
        catchRepository: CatchRepositoryProtocol,
        spotRepository: SpotRepositoryProtocol,
        userRepository: UserRepositoryProtocol
    ) {
        self.catchRepository = catchRepository
        self.spotRepository = spotRepository
        self.userRepository = userRepository
    }

    func fetchRecent(limit: Int) async throws -> [DethroneEvent] {
        let scanLimit = max(limit * 8, 40)
        let recent = try await catchRepository.getRecentPublicCatches(limit: scanLimit, offset: 0)
        let dethrones = recent
            .filter { $0.dethronedUserId != nil }
            .prefix(limit)

        var events: [DethroneEvent] = []
        events.reserveCapacity(dethrones.count)

        for fishCatch in dethrones {
            guard let previousKingId = fishCatch.dethronedUserId else { continue }
            let spot = try? await spotRepository.getSpot(byId: fishCatch.spotId)
            let newKing = try? await userRepository.getUser(byId: fishCatch.userId)
            let previousKing = try? await userRepository.getUser(byId: previousKingId)

            events.append(DethroneEvent(
                id: fishCatch.id,
                occurredAt: fishCatch.createdAt,
                spotId: fishCatch.spotId,
                spotName: spot?.name ?? "Unknown Waters",
                previousKingId: previousKingId,
                previousKingName: previousKing?.username.nonEmpty ?? "Former Captain",
                newKingId: fishCatch.userId,
                newKingName: newKing?.username.nonEmpty ?? "New Captain",
                newKingTier: CaptainTier.from(rankTier: newKing?.rankTier ?? .minnow),
                newCatchSizeCm: fishCatch.normalizedSizeInCm
            ))
        }

        return events
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
