import Foundation

/// A 30-day competitive cycle.
/// Maps to Supabase 'seasons' table.
struct Season: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let seasonNumber: Int
    let startDate: Date
    var endDate: Date
    var isActive: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case seasonNumber = "season_number"
        case startDate = "start_date"
        case endDate = "end_date"
        case isActive = "is_active"
        case createdAt = "created_at"
    }

    var daysRemaining: Int {
        let interval = endDate.timeIntervalSince(Date())
        return max(0, Int(interval / 86400))
    }

    var isOngoing: Bool {
        let now = Date()
        return isActive && now >= startDate && now <= endDate
    }

    /// Progress 0...1 from startDate -> endDate.
    var progress: Double {
        let total = endDate.timeIntervalSince(startDate)
        guard total > 0 else { return 0 }
        let elapsed = Date().timeIntervalSince(startDate)
        return min(1.0, max(0.0, elapsed / total))
    }
}

/// Permanent record of top finishers per territory per season.
/// Maps to Supabase 'season_champions' table.
struct SeasonChampion: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let seasonId: String
    let userId: String
    let territoryId: String?
    let rank: Int
    let seasonScore: Int
    let awardedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case seasonId = "season_id"
        case userId = "user_id"
        case territoryId = "territory_id"
        case rank
        case seasonScore = "season_score"
        case awardedAt = "awarded_at"
    }
}

/// One row of a season leaderboard for a single territory.
struct SeasonLeaderboardEntry: Identifiable, Equatable {
    let rank: Int
    let user: User
    let seasonScore: Int

    var id: String { "\(rank)-\(user.id)" }
}
