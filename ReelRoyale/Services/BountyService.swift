import Foundation

protocol BountyServiceProtocol: AnyObject {
    func fetchActive() async throws -> [Bounty]
    func fetchTodaysFeatured() async throws -> Bounty?
}

final class MockBountyService: BountyServiceProtocol {
    func fetchActive() async throws -> [Bounty] {
        let now = Date()
        return [
            Bounty(
                id: "b-daily-bass",
                title: "Trophy Hunt: Largemouth Bass",
                detail: "Catch a Largemouth Bass over 50cm. Reward scales with size.",
                bountyType: .dailyChallenge,
                startsAt: now.addingTimeInterval(-3600 * 6),
                endsAt:   now.addingTimeInterval(3600 * 18),
                criteria: "Largemouth Bass · 50cm+",
                rewardDoubloons: 500,
                rewardGlory: 150,
                regionName: nil,
                iconSystemName: "fish.fill"
            ),
            Bounty(
                id: "b-weekly-tahoe",
                title: "Battle for Lake Tahoe",
                detail: "Claim 3 spots in the Tahoe region this week.",
                bountyType: .regionalBattle,
                startsAt: now.addingTimeInterval(-86400 * 2),
                endsAt:   now.addingTimeInterval(86400 * 5),
                criteria: "3 spots · Lake Tahoe",
                rewardDoubloons: 1500,
                rewardGlory: 600,
                regionName: "Lake Tahoe",
                iconSystemName: "flag.fill"
            ),
            Bounty(
                id: "b-weekly-trout",
                title: "Trout Master Tournament",
                detail: "Top 10 biggest trout catches this week win.",
                bountyType: .weeklyTournament,
                startsAt: now.addingTimeInterval(-86400),
                endsAt:   now.addingTimeInterval(86400 * 6),
                criteria: "Trout (any) · Top 10 by size",
                rewardDoubloons: 2000,
                rewardGlory: 800,
                regionName: nil,
                iconSystemName: "trophy.fill"
            )
        ]
    }

    func fetchTodaysFeatured() async throws -> Bounty? {
        try await fetchActive().first
    }
}
