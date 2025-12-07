import Foundation
import CoreLocation

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
    var spotId: String? // Optional now, as assignment might fail or be pending
    
    // Location data
    var latitude: Double
    var longitude: Double
    
    var photoURL: String?
    var species: String
    var sizeValue: Double
    var sizeUnit: String
    var visibility: CatchVisibility
    var hideExactLocation: Bool
    var notes: String?
    var weatherSnapshot: String? // JSON encoded weather at time of catch
    var measuredWithAR: Bool
    let createdAt: Date
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case spotId = "spot_id"
        case latitude
        case longitude
        case photoURL = "photo_url"
        case species
        case sizeValue = "size_value"
        case sizeUnit = "size_unit"
        case visibility
        case hideExactLocation = "hide_exact_location"
        case notes
        case weatherSnapshot = "weather_snapshot"
        case measuredWithAR = "measured_with_ar"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        spotId: String? = nil,
        latitude: Double,
        longitude: Double,
        photoURL: String? = nil,
        species: String,
        sizeValue: Double,
        sizeUnit: String = "cm",
        visibility: CatchVisibility = .public,
        hideExactLocation: Bool = false,
        notes: String? = nil,
        weatherSnapshot: String? = nil,
        measuredWithAR: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.spotId = spotId
        self.latitude = latitude
        self.longitude = longitude
        self.photoURL = photoURL
        self.species = species
        self.sizeValue = sizeValue
        self.sizeUnit = sizeUnit
        self.visibility = visibility
        self.hideExactLocation = hideExactLocation
        self.notes = notes
        self.weatherSnapshot = weatherSnapshot
        self.measuredWithAR = measuredWithAR
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
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
    var spotId: String?
    var latitude: Double
    var longitude: Double
    var photoData: Data?
    var species: String
    var sizeValue: Double
    var sizeUnit: String
    var visibility: CatchVisibility
    var hideExactLocation: Bool
    var notes: String?
    var measuredWithAR: Bool
    
    init(
        spotId: String? = nil,
        latitude: Double = 0,
        longitude: Double = 0,
        photoData: Data? = nil,
        species: String = "",
        sizeValue: Double = 0,
        sizeUnit: String = "cm",
        visibility: CatchVisibility = .public,
        hideExactLocation: Bool = false,
        notes: String? = nil,
        measuredWithAR: Bool = false
    ) {
        self.spotId = spotId
        self.latitude = latitude
        self.longitude = longitude
        self.photoData = photoData
        self.species = species
        self.sizeValue = sizeValue
        self.sizeUnit = sizeUnit
        self.visibility = visibility
        self.hideExactLocation = hideExactLocation
        self.notes = notes
        self.measuredWithAR = measuredWithAR
    }
    
    var isValid: Bool {
        !species.isEmpty && sizeValue > 0 && (latitude != 0 || longitude != 0)
    }
}
