import Foundation
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var top3: [CaptainRankEntry] = []
    @Published var yourEntry: CaptainRankEntry?
    @Published var todaysBounty: Bounty?
    @Published var dethrones: [DethroneEvent] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let bountyService: BountyServiceProtocol
    private let dethroneService: DethroneEventServiceProtocol
    private let leaderboardService: LeaderboardServiceProtocol

    init(
        bountyService: BountyServiceProtocol,
        dethroneService: DethroneEventServiceProtocol,
        leaderboardService: LeaderboardServiceProtocol
    ) {
        self.bountyService = bountyService
        self.dethroneService = dethroneService
        self.leaderboardService = leaderboardService
    }

    func load(currentUserId: String?) async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let top3Task: [CaptainRankEntry] = leaderboardService.fetchTop(scope: .global, timeframe: .season, limit: 3)
            async let bountyTask = bountyService.fetchTodaysFeatured()
            async let dethroneTask: [DethroneEvent] = dethroneService.fetchRecent(limit: 8)
            async let youTask: CaptainRankEntry? = {
                guard let uid = currentUserId else { return nil }
                return try await leaderboardService.fetchUserRank(userId: uid, scope: .global, timeframe: .season)
            }()

            top3 = try await top3Task
            todaysBounty = try await bountyTask
            dethrones = try await dethroneTask
            yourEntry = try await youTask
        } catch {
            errorMessage = "Failed to load: \(error.localizedDescription)"
        }
    }
}
