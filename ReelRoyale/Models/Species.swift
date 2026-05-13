import Foundation

/// Rarity tier controls XP multiplier and codex visualization.
/// Mirrors the `rarity_tier` CHECK on the species table.
enum FishRarity: String, Codable, CaseIterable, Identifiable, Comparable {
    case common
    case uncommon
    case rare
    case trophy

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    var xpMultiplier: Double {
        switch self {
        case .common: return 1.0
        case .uncommon: return 1.5
        case .rare: return 2.5
        case .trophy: return 5.0
        }
    }

    /// Sort order - higher tier sorts first.
    private var rank: Int {
        switch self {
        case .common: return 0
        case .uncommon: return 1
        case .rare: return 2
        case .trophy: return 3
        }
    }

    static func < (lhs: FishRarity, rhs: FishRarity) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// Species reference data (catalog).
/// Maps to Supabase 'species' table. Read-mostly.
struct Species: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var name: String
    var commonName: String?
    var rarityTier: FishRarity
    var xpMultiplier: Double
    var description: String?
    var habitat: String?
    var averageSize: Double?
    var family: String?
    var imageURL: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case commonName = "common_name"
        case rarityTier = "rarity_tier"
        case xpMultiplier = "xp_multiplier"
        case description
        case habitat
        case averageSize = "average_size"
        case family
        case imageURL = "image_url"
        case createdAt = "created_at"
    }

    var displayName: String { commonName ?? name }
}

/// Per-user species capture record (codex).
/// Maps to Supabase 'user_species' table.
struct UserSpecies: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let userId: String
    let speciesId: String
    var personalBestSize: Double?
    var personalBestUnit: String?
    var personalBestCatchId: String?
    var totalCaught: Int
    let firstCaughtAt: Date
    var firstCaughtSpotId: String?
    var lastCaughtAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case speciesId = "species_id"
        case personalBestSize = "personal_best_size"
        case personalBestUnit = "personal_best_unit"
        case personalBestCatchId = "personal_best_catch_id"
        case totalCaught = "total_caught"
        case firstCaughtAt = "first_caught_at"
        case firstCaughtSpotId = "first_caught_spot_id"
        case lastCaughtAt = "last_caught_at"
    }
}

/// Combined codex entry for display: pairs catalog data with user record.
/// `userRecord == nil` means the species is "undiscovered" by this user.
struct CodexEntry: Identifiable, Equatable {
    let species: Species
    let userRecord: UserSpecies?

    var id: String { species.id }
    var isDiscovered: Bool { userRecord != nil }
    var totalCaught: Int { userRecord?.totalCaught ?? 0 }

    var personalBestDisplay: String? {
        guard let record = userRecord,
              let size = record.personalBestSize,
              let unit = record.personalBestUnit
        else { return nil }
        return String(format: "%.1f %@", size, unit)
    }

    /// Mastery tier derived from how many of this species the user has caught.
    /// Locked when undiscovered; bronze on first catch; scales up to diamond.
    var masteryTier: FishMasteryTier {
        FishMasteryTier.from(totalCaught: totalCaught)
    }
}

/// Per-species mastery progression. Pokemon-Go-style tiered badge that
/// summarizes how many of a given species the user has caught.
enum FishMasteryTier: Int, Codable, CaseIterable, Identifiable, Comparable {
    case locked   = 0
    case bronze   = 1
    case silver   = 2
    case gold     = 3
    case platinum = 4
    case diamond  = 5

    var id: Int { rawValue }

    /// Inclusive lower bound of catches to enter this tier.
    var minCatches: Int {
        switch self {
        case .locked:   return 0
        case .bronze:   return 1
        case .silver:   return 5
        case .gold:     return 15
        case .platinum: return 35
        case .diamond:  return 75
        }
    }

    /// First-catch count of the next tier, or `nil` at terminal tier.
    var nextTierCatches: Int? {
        switch self {
        case .locked:   return FishMasteryTier.bronze.minCatches
        case .bronze:   return FishMasteryTier.silver.minCatches
        case .silver:   return FishMasteryTier.gold.minCatches
        case .gold:     return FishMasteryTier.platinum.minCatches
        case .platinum: return FishMasteryTier.diamond.minCatches
        case .diamond:  return nil
        }
    }

    var displayName: String {
        switch self {
        case .locked:   return "Locked"
        case .bronze:   return "Bronze"
        case .silver:   return "Silver"
        case .gold:     return "Gold"
        case .platinum: return "Platinum"
        case .diamond:  return "Diamond"
        }
    }

    var shortLabel: String {
        switch self {
        case .locked:   return "—"
        case .bronze:   return "B"
        case .silver:   return "S"
        case .gold:     return "G"
        case .platinum: return "P"
        case .diamond:  return "D"
        }
    }

    var iconName: String {
        switch self {
        case .locked:   return "lock.fill"
        case .bronze:   return "shield.fill"
        case .silver:   return "shield.lefthalf.filled"
        case .gold:     return "rosette"
        case .platinum: return "trophy.fill"
        case .diamond:  return "diamond.fill"
        }
    }

    /// 0...1 progress toward next tier. Diamond stays full.
    func progress(catches: Int) -> Double {
        guard let next = nextTierCatches else { return 1.0 }
        let span = Double(next - minCatches)
        guard span > 0 else { return 1.0 }
        return min(1.0, max(0.0, Double(catches - minCatches) / span))
    }

    /// Catches remaining to reach the next tier, or nil if already maxed.
    func catchesToNext(current: Int) -> Int? {
        guard let next = nextTierCatches else { return nil }
        return max(0, next - current)
    }

    static func from(totalCaught: Int) -> FishMasteryTier {
        if totalCaught >= FishMasteryTier.diamond.minCatches  { return .diamond }
        if totalCaught >= FishMasteryTier.platinum.minCatches { return .platinum }
        if totalCaught >= FishMasteryTier.gold.minCatches     { return .gold }
        if totalCaught >= FishMasteryTier.silver.minCatches   { return .silver }
        if totalCaught >= FishMasteryTier.bronze.minCatches   { return .bronze }
        return .locked
    }

    private var rank: Int { rawValue }

    static func < (lhs: FishMasteryTier, rhs: FishMasteryTier) -> Bool {
        lhs.rank < rhs.rank
    }
}
