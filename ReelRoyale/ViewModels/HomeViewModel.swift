import Foundation
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var top3: [CaptainRankEntry] = []
    @Published var yourEntry: CaptainRankEntry?
    @Published var todaysBounty: Bounty?
    @Published var dethrones: [DethroneEvent] = []
    @Published var ruledSpots: [Spot] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let bountyService: BountyServiceProtocol
    private let dethroneService: DethroneEventServiceProtocol
    private let leaderboardService: LeaderboardServiceProtocol
    private let spotRepository: SpotRepositoryProtocol

    init(
        bountyService: BountyServiceProtocol,
        dethroneService: DethroneEventServiceProtocol,
        leaderboardService: LeaderboardServiceProtocol,
        spotRepository: SpotRepositoryProtocol
    ) {
        self.bountyService = bountyService
        self.dethroneService = dethroneService
        self.leaderboardService = leaderboardService
        self.spotRepository = spotRepository
    }

    func load(currentUserId: String?) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            async let top3Task: [CaptainRankEntry] = leaderboardService.fetchTop(scope: .global, timeframe: .season, limit: 3)
            async let bountyTask = bountyService.fetchTodaysFeatured(for: currentUserId)
            async let dethroneTask: [DethroneEvent] = dethroneService.fetchRecent(limit: 8)
            async let ruledSpotsTask: [Spot] = fetchRuledSpots(for: currentUserId)
            async let youTask: CaptainRankEntry? = {
                guard let uid = currentUserId else { return nil }
                return try await leaderboardService.fetchUserRank(userId: uid, scope: .global, timeframe: .season)
            }()

            top3 = try await top3Task
            todaysBounty = try await bountyTask
            dethrones = try await dethroneTask
            ruledSpots = try await ruledSpotsTask
            yourEntry = try await youTask
        } catch {
            errorMessage = "Failed to load: \(error.localizedDescription)"
        }
    }

    private func fetchRuledSpots(for userId: String?) async throws -> [Spot] {
        guard let userId, !userId.isEmpty else { return [] }
        return try await spotRepository.getSpotsRuledBy(userId: userId)
    }
}
