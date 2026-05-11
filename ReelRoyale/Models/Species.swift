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

    var personalBestDisplay: String? {
        guard let record = userRecord,
              let size = record.personalBestSize,
              let unit = record.personalBestUnit
        else { return nil }
        return String(format: "%.1f %@", size, unit)
    }
}
