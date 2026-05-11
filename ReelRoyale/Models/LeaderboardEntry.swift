import Foundation

/// Denormalized leaderboard read model.
struct CaptainRankEntry: Identifiable, Codable, Hashable {
    let id: String           // user id
    let rank: Int
    let captainName: String
    let avatarURL: String?
    let tier: CaptainTier
    let division: Int
    let doubloons: Int
    let glory: Int
    let crownsHeld: Int
    let weeklyDelta: Int     // rank change this week, + = climbed, - = dropped
}

/// Leaderboard filter axes.
enum LeaderboardScope: String, CaseIterable, Identifiable {
    case global   = "Global"
    case regional = "Regional"
    case friends  = "Friends"

    var id: String { rawValue }
}

enum LeaderboardTimeframe: String, CaseIterable, Identifiable {
    case season   = "Season"
    case week     = "Week"
    case allTime  = "All-Time"

    var id: String { rawValue }
}
