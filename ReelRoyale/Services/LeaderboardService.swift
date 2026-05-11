import Foundation

protocol LeaderboardServiceProtocol: AnyObject {
    func fetchTop(scope: LeaderboardScope, timeframe: LeaderboardTimeframe, limit: Int) async throws -> [CaptainRankEntry]
    func fetchUserRank(userId: String, scope: LeaderboardScope, timeframe: LeaderboardTimeframe) async throws -> CaptainRankEntry?
}

final class MockLeaderboardService: LeaderboardServiceProtocol {
    private static let seed: [CaptainRankEntry] = [
        CaptainRankEntry(id: "u-pirateking", rank: 1, captainName: "PirateKing",  avatarURL: nil, tier: .pirateLord, division: 1, doubloons: 248_300, glory: 89_400, crownsHeld: 41, weeklyDelta:  0),
        CaptainRankEntry(id: "u-marlina",    rank: 2, captainName: "Marlina",     avatarURL: nil, tier: .admiral,    division: 1, doubloons: 198_120, glory: 71_220, crownsHeld: 32, weeklyDelta:  1),
        CaptainRankEntry(id: "u-blackbeard", rank: 3, captainName: "Blackbeard",  avatarURL: nil, tier: .admiral,    division: 2, doubloons: 184_900, glory: 67_540, crownsHeld: 28, weeklyDelta: -1),
        CaptainRankEntry(id: "u-anchorace",  rank: 4, captainName: "AnchorAce",   avatarURL: nil, tier: .commodore,  division: 1, doubloons: 156_400, glory: 58_910, crownsHeld: 21, weeklyDelta:  2),
        CaptainRankEntry(id: "u-redhook",    rank: 5, captainName: "RedHook",     avatarURL: nil, tier: .commodore,  division: 2, doubloons: 142_780, glory: 54_220, crownsHeld: 19, weeklyDelta:  0),
        CaptainRankEntry(id: "u-laketamer",  rank: 6, captainName: "LakeTamer",   avatarURL: nil, tier: .commodore,  division: 3, doubloons: 128_650, glory: 49_100, crownsHeld: 16, weeklyDelta:  3),
        CaptainRankEntry(id: "u-saltybill",  rank: 7, captainName: "SaltyBill",   avatarURL: nil, tier: .captain,    division: 1, doubloons: 110_290, glory: 41_400, crownsHeld: 14, weeklyDelta: -2),
        CaptainRankEntry(id: "u-trouthunter",rank: 8, captainName: "TroutHunter", avatarURL: nil, tier: .captain,    division: 2, doubloons:  94_320, glory: 36_770, crownsHeld: 11, weeklyDelta:  1),
        CaptainRankEntry(id: "u-stripenose", rank: 9, captainName: "StripeNose",  avatarURL: nil, tier: .captain,    division: 3, doubloons:  82_540, glory: 31_200, crownsHeld:  9, weeklyDelta:  4),
        CaptainRankEntry(id: "u-jollyroger", rank:10, captainName: "JollyRoger",  avatarURL: nil, tier: .firstMate,  division: 1, doubloons:  71_820, glory: 27_640, crownsHeld:  8, weeklyDelta: -1)
    ]

    func fetchTop(scope: LeaderboardScope, timeframe: LeaderboardTimeframe, limit: Int) async throws -> [CaptainRankEntry] {
        Array(Self.seed.prefix(limit))
    }

    func fetchUserRank(userId: String, scope: LeaderboardScope, timeframe: LeaderboardTimeframe) async throws -> CaptainRankEntry? {
        // Mock: synthesize a "your rank" entry slotted at #234.
        CaptainRankEntry(
            id: userId, rank: 234, captainName: "You",
            avatarURL: nil, tier: .deckhand, division: 1,
            doubloons: 1_240, glory: 480, crownsHeld: 0, weeklyDelta: 0
        )
    }
}
