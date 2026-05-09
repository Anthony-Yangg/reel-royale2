import Foundation

/// Size unit for fish measurements
enum SizeUnit: String, Codable, CaseIterable, Identifiable {
    case cm = "cm"
    case inches = "in"
    case kg = "kg"
    case lbs = "lbs"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .cm: return "Centimeters"
        case .inches: return "Inches"
        case .kg: return "Kilograms"
        case .lbs: return "Pounds"
        }
    }
    
    var isLength: Bool {
        self == .cm || self == .inches
    }
    
    var isWeight: Bool {
        self == .kg || self == .lbs
    }
}

/// Visibility options for catches
enum CatchVisibility: String, Codable, CaseIterable, Identifiable {
    case `public` = "public"
    case friendsOnly = "friends_only"
    case `private` = "private"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .public: return "Public"
        case .friendsOnly: return "Friends Only"
        case .private: return "Private"
        }
    }
    
    var icon: String {
        switch self {
        case .public: return "globe"
        case .friendsOnly: return "person.2.fill"
        case .private: return "lock.fill"
        }
    }
}

/// Fish catch model
/// Maps to Supabase 'catches' table
struct FishCatch: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let userId: String
    let spotId: String
    var photoURL: String?
    var species: String
    var speciesId: String?
    var sizeValue: Double
    var sizeUnit: String
    var visibility: CatchVisibility
    var hideExactLocation: Bool
    var notes: String?
    var weatherSnapshot: String? // JSON encoded weather at time of catch
    var measuredWithAR: Bool
    var released: Bool
    var xpAwarded: Int
    var coinsAwarded: Int
    var dethronedUserId: String?
    var seasonId: String?
    let createdAt: Date
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case spotId = "spot_id"
        case photoURL = "photo_url"
        case species
        case speciesId = "species_id"
        case sizeValue = "size_value"
        case sizeUnit = "size_unit"
        case visibility
        case hideExactLocation = "hide_exact_location"
        case notes
        case weatherSnapshot = "weather_snapshot"
        case measuredWithAR = "measured_with_ar"
        case released
        case xpAwarded = "xp_awarded"
        case coinsAwarded = "coins_awarded"
        case dethronedUserId = "dethroned_user_id"
        case seasonId = "season_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: String = UUID().uuidString,
        userId: String,
        spotId: String,
        photoURL: String? = nil,
        species: String,
        speciesId: String? = nil,
        sizeValue: Double,
        sizeUnit: String = "cm",
        visibility: CatchVisibility = .public,
        hideExactLocation: Bool = false,
        notes: String? = nil,
        weatherSnapshot: String? = nil,
        measuredWithAR: Bool = false,
        released: Bool = false,
        xpAwarded: Int = 0,
        coinsAwarded: Int = 0,
        dethronedUserId: String? = nil,
        seasonId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.spotId = spotId
        self.photoURL = photoURL
        self.species = species
        self.speciesId = speciesId
        self.sizeValue = sizeValue
        self.sizeUnit = sizeUnit
        self.visibility = visibility
        self.hideExactLocation = hideExactLocation
        self.notes = notes
        self.weatherSnapshot = weatherSnapshot
        self.measuredWithAR = measuredWithAR
        self.released = released
        self.xpAwarded = xpAwarded
        self.coinsAwarded = coinsAwarded
        self.dethronedUserId = dethronedUserId
        self.seasonId = seasonId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        userId = try c.decode(String.self, forKey: .userId)
        spotId = try c.decode(String.self, forKey: .spotId)
        photoURL = try c.decodeIfPresent(String.self, forKey: .photoURL)
        species = try c.decode(String.self, forKey: .species)
        speciesId = try c.decodeIfPresent(String.self, forKey: .speciesId)
        sizeValue = try c.decode(Double.self, forKey: .sizeValue)
        sizeUnit = try c.decode(String.self, forKey: .sizeUnit)
        visibility = try c.decode(CatchVisibility.self, forKey: .visibility)
        hideExactLocation = try c.decodeIfPresent(Bool.self, forKey: .hideExactLocation) ?? false
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        weatherSnapshot = try c.decodeIfPresent(String.self, forKey: .weatherSnapshot)
        measuredWithAR = try c.decodeIfPresent(Bool.self, forKey: .measuredWithAR) ?? false
        released = try c.decodeIfPresent(Bool.self, forKey: .released) ?? false
        xpAwarded = try c.decodeIfPresent(Int.self, forKey: .xpAwarded) ?? 0
        coinsAwarded = try c.decodeIfPresent(Int.self, forKey: .coinsAwarded) ?? 0
        dethronedUserId = try c.decodeIfPresent(String.self, forKey: .dethronedUserId)
        seasonId = try c.decodeIfPresent(String.self, forKey: .seasonId)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
    
    var isPublic: Bool {
        visibility == .public || visibility == .friendsOnly
    }
    
    var sizeDisplay: String {
        "\(String(format: "%.1f", sizeValue)) \(sizeUnit)"
    }
    
    /// Convert size to centimeters for comparison
    var normalizedSizeInCm: Double {
        switch sizeUnit.lowercased() {
        case "in", "inches":
            return sizeValue * 2.54
        case "cm":
            return sizeValue
        default:
            return sizeValue
        }
    }
}

/// Catch with related data for display
struct CatchWithDetails: Identifiable, Equatable {
    let fishCatch: FishCatch
    let user: User?
    let spot: Spot?
    var likeCount: Int
    var isLikedByCurrentUser: Bool
    var isCurrentKing: Bool
    
    var id: String { fishCatch.id }
}

/// Input for creating a new catch
struct CreateCatchInput {
    var spotId: String
    var photoData: Data?
    var species: String
    var speciesId: String?
    var sizeValue: Double
    var sizeUnit: String
    var visibility: CatchVisibility
    var hideExactLocation: Bool
    var notes: String?
    var measuredWithAR: Bool
    var released: Bool

    init(
        spotId: String = "",
        photoData: Data? = nil,
        species: String = "",
        speciesId: String? = nil,
        sizeValue: Double = 0,
        sizeUnit: String = "cm",
        visibility: CatchVisibility = .public,
        hideExactLocation: Bool = false,
        notes: String? = nil,
        measuredWithAR: Bool = false,
        released: Bool = false
    ) {
        self.spotId = spotId
        self.photoData = photoData
        self.species = species
        self.speciesId = speciesId
        self.sizeValue = sizeValue
        self.sizeUnit = sizeUnit
        self.visibility = visibility
        self.hideExactLocation = hideExactLocation
        self.notes = notes
        self.measuredWithAR = measuredWithAR
        self.released = released
    }

    var isValid: Bool {
        !spotId.isEmpty && !species.isEmpty && sizeValue > 0
    }
}

