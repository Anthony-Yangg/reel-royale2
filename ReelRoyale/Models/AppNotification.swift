import Foundation

/// Domain notification (push or in-app feed entry).
/// Named `AppNotification` to avoid collision with Foundation.Notification.
struct AppNotification: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let userId: String
    let type: NotificationType
    let title: String
    let body: String?
    let payload: [String: AnyJSONValue]?
    var read: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type
        case title
        case body
        case payload
        case read
        case createdAt = "created_at"
    }

    /// Type-safe payload accessors used by UI.
    var spotId: String?     { payload?["spot_id"]?.stringValue }
    var newKingId: String?  { payload?["new_king_id"]?.stringValue }
    var newCatchId: String? { payload?["new_catch_id"]?.stringValue }
    var newSize: Double?    { payload?["new_size"]?.doubleValue }
    var newSpecies: String? { payload?["new_species"]?.stringValue }
}

enum NotificationType: String, Codable, CaseIterable {
    case dethroned
    case defended
    case challengeComplete = "challenge_complete"
    case seasonEnd = "season_end"
    case rankUp = "rank_up"
    case crownTaken = "crown_taken"
    case streakBonus = "streak_bonus"
    case newTerritory = "new_territory"

    var icon: String {
        switch self {
        case .dethroned, .crownTaken: return "crown.fill"
        case .defended:               return "shield.fill"
        case .challengeComplete:      return "checkmark.seal.fill"
        case .seasonEnd:              return "flag.checkered"
        case .rankUp:                 return "arrow.up.circle.fill"
        case .streakBonus:            return "flame.fill"
        case .newTerritory:           return "map.fill"
        }
    }

    var defaultTitle: String {
        switch self {
        case .dethroned:         return "You've been dethroned!"
        case .crownTaken:        return "Crown taken"
        case .defended:          return "You defended your spot"
        case .challengeComplete: return "Challenge complete!"
        case .seasonEnd:         return "Season ended"
        case .rankUp:            return "Rank up!"
        case .streakBonus:       return "Streak bonus"
        case .newTerritory:      return "New territory unlocked"
        }
    }
}
