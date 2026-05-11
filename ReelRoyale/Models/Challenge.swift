import Foundation

/// How frequently a challenge resets.
enum ChallengeType: String, Codable, CaseIterable {
    case daily
    case weekly

    var displayName: String { rawValue.capitalized }
}

/// All possible auto-completion conditions. Mirror of challenges.condition_type CHECK.
/// Each case knows how to evaluate against a fresh catch + the user's day/week state.
enum ChallengeCondition: String, Codable, CaseIterable {
    case catchAny = "catch_any"
    case catchWeightOver = "catch_weight_over"
    case catchBeforeNoon = "catch_before_noon"
    case visitNSpots = "visit_n_spots"
    case catchAndRelease = "catch_and_release"
    case catchSpeciesFirst = "catch_species_first"
    case becomeKing = "become_king"
    case catchCountInWindow = "catch_count_in_window"
    case catchInNTerritories = "catch_in_n_territories"
    case holdKingNDays = "hold_king_n_days"
}

/// Challenge catalog entry. Maps to 'challenges' table.
struct Challenge: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let title: String
    let description: String?
    let type: ChallengeType
    let xpReward: Int
    let coinReward: Int
    let conditionType: ChallengeCondition
    /// Free-form payload (e.g. {"min_kg": 1.0} or {"count": 3}). Codable JSON.
    let conditionPayload: [String: AnyJSONValue]
    let isActive: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case type
        case xpReward = "xp_reward"
        case coinReward = "coin_reward"
        case conditionType = "condition_type"
        case conditionPayload = "condition_payload"
        case isActive = "is_active"
        case createdAt = "created_at"
    }

    /// Convenience accessors for typed payload values.
    var minWeightKg: Double? {
        conditionPayload["min_kg"]?.doubleValue
    }

    var requiredCount: Int? {
        conditionPayload["count"]?.intValue
    }

    var windowDays: Int? {
        conditionPayload["window_days"]?.intValue
    }

    var requiredHoldDays: Int? {
        conditionPayload["days"]?.intValue
    }
}

/// Per-user assigned challenge with progress.
/// Maps to 'user_challenges'.
struct UserChallenge: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let userId: String
    let challengeId: String
    let assignedDate: Date
    var progress: [String: AnyJSONValue]
    var completed: Bool
    var completedAt: Date?
    var rewarded: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case challengeId = "challenge_id"
        case assignedDate = "assigned_date"
        case progress
        case completed
        case completedAt = "completed_at"
        case rewarded
        case createdAt = "created_at"
    }
}

/// Joined view: per-user challenge + catalog metadata.
struct UserChallengeWithDetails: Identifiable, Equatable {
    let challenge: Challenge
    var userRecord: UserChallenge

    var id: String { userRecord.id }
}

/// A minimal Codable JSON wrapper for the JSONB payload columns.
/// Supports string/int/double/bool/null. Keeps challenges flexible without
/// pulling a JSON library.
enum AnyJSONValue: Codable, Equatable, Hashable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Bool.self)   { self = .bool(v); return }
        if let v = try? c.decode(Int.self)    { self = .int(v); return }
        if let v = try? c.decode(Double.self) { self = .double(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        self = .null
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v): try c.encode(v)
        case .int(let v):    try c.encode(v)
        case .double(let v): try c.encode(v)
        case .bool(let v):   try c.encode(v)
        case .null:          try c.encodeNil()
        }
    }

    var stringValue: String? { if case .string(let v) = self { return v }; return nil }
    var intValue: Int? {
        switch self {
        case .int(let v):    return v
        case .double(let v): return Int(v)
        default:             return nil
        }
    }
    var doubleValue: Double? {
        switch self {
        case .double(let v): return v
        case .int(let v):    return Double(v)
        default:             return nil
        }
    }
    var boolValue: Bool? { if case .bool(let v) = self { return v }; return nil }
}
