import Foundation
import CoreLocation

/// Water body type for fishing spots
enum WaterType: String, Codable, CaseIterable, Identifiable {
    case lake = "lake"
    case river = "river"
    case pond = "pond"
    case stream = "stream"
    case reservoir = "reservoir"
    case bay = "bay"
    case ocean = "ocean"
    case pier = "pier"
    case creek = "creek"
    case canal = "canal"
    
    var id: String { rawValue }
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var icon: String {
        switch self {
        case .lake, .pond, .reservoir: return "drop.fill"
        case .river, .stream, .creek, .canal: return "water.waves"
        case .bay, .ocean: return "water.waves.and.arrow.down"
        case .pier: return "building.columns"
        }
    }
}

/// Fishing spot model
/// Maps to Supabase 'spots' table
struct Spot: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var name: String
    var description: String?
    var latitude: Double
    var longitude: Double
    var waterType: WaterType?
    var territoryId: String?
    var currentKingUserId: String?
    var currentBestCatchId: String?
    var currentBestSize: Double?
    var currentBestUnit: String?
    var imageURL: String?
    var regionName: String?
    let createdAt: Date
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case latitude
        case longitude
        case waterType = "water_type"
        case territoryId = "territory_id"
        case currentKingUserId = "current_king_user_id"
        case currentBestCatchId = "current_best_catch_id"
        case currentBestSize = "current_best_size"
        case currentBestUnit = "current_best_unit"
        case imageURL = "image_url"
        case regionName = "region_name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(
        id: String = UUID().uuidString,
        name: String,
        description: String? = nil,
        latitude: Double,
        longitude: Double,
        waterType: WaterType? = nil,
        territoryId: String? = nil,
        currentKingUserId: String? = nil,
        currentBestCatchId: String? = nil,
        currentBestSize: Double? = nil,
        currentBestUnit: String? = nil,
        imageURL: String? = nil,
        regionName: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.latitude = latitude
        self.longitude = longitude
        self.waterType = waterType
        self.territoryId = territoryId
        self.currentKingUserId = currentKingUserId
        self.currentBestCatchId = currentBestCatchId
        self.currentBestSize = currentBestSize
        self.currentBestUnit = currentBestUnit
        self.imageURL = imageURL
        self.regionName = regionName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
    
    var formattedCoordinates: String {
        String(format: "%.4f, %.4f", latitude, longitude)
    }
    
    var hasKing: Bool {
        currentKingUserId != nil
    }
    
    var bestCatchDisplay: String? {
        guard let size = currentBestSize, let unit = currentBestUnit else { return nil }
        return "\(String(format: "%.1f", size)) \(unit)"
    }
}

/// Spot with additional computed info for display
struct SpotWithDetails: Identifiable, Equatable {
    let spot: Spot
    let kingUser: User?
    let bestCatch: FishCatch?
    let territory: Territory?
    let distance: Double? // in meters from user
    let catchCount: Int
    
    var id: String { spot.id }
}

