import Foundation

/// A time-limited challenge that drives engagement (Tavern Hub + Home).
struct Bounty: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let detail: String
    let bountyType: BountyType
    let startsAt: Date
    let endsAt: Date
    let criteria: String
    let rewardDoubloons: Int
    let rewardGlory: Int
    let regionName: String?      // nil = global
    let iconSystemName: String   // SF Symbol

    var timeRemaining: TimeInterval { endsAt.timeIntervalSinceNow }
    var isExpired: Bool { timeRemaining <= 0 }
    var isActive: Bool { Date() >= startsAt && !isExpired }
}

enum BountyType: String, Codable, CaseIterable {
    case dailyChallenge   = "daily"
    case weeklyTournament = "weekly"
    case regionalBattle   = "regional"
    case seasonalGoal     = "seasonal"

    var displayName: String {
        switch self {
        case .dailyChallenge:   return "Daily"
        case .weeklyTournament: return "Tournament"
        case .regionalBattle:   return "Regional"
        case .seasonalGoal:     return "Seasonal"
        }
    }
}
