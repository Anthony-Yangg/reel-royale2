import Foundation
import CoreLocation

/// Fishing spot model
/// Represents a specific fishing location within a waterbody
struct Spot: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var name: String
    var description: String?
    var latitude: Double
    var longitude: Double
    var radius: Double // Radius in meters
    var waterbodyId: String?
    var territoryId: String?
    var waterType: WaterbodyType? // Can inherit from waterbody if nil
    
    // Game state
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
        case radius
        case waterbodyId = "waterbody_id"
        case territoryId = "territory_id"
        case waterType = "water_type"
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
        radius: Double = 200,
        waterbodyId: String? = nil,
        territoryId: String? = nil,
        waterType: WaterbodyType? = nil,
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
        self.radius = radius
        self.waterbodyId = waterbodyId
        self.territoryId = territoryId
        self.waterType = waterType
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
    
    /// Checks if a coordinate falls within this spot's radius
    func contains(coordinate: CLLocationCoordinate2D) -> Bool {
        let spotLocation = CLLocation(latitude: latitude, longitude: longitude)
        let otherLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return spotLocation.distance(from: otherLocation) <= radius
    }
}

/// Spot with additional computed info for display
struct SpotWithDetails: Identifiable, Equatable {
    let spot: Spot
    let kingUser: User?
    let bestCatch: FishCatch?
    let distance: Double? // in meters from user
    let catchCount: Int
    let waterbody: Waterbody?
    
    var id: String { spot.id }
}
