import Foundation
import CoreLocation

/// Type of waterbody
enum WaterbodyType: String, Codable, CaseIterable, Identifiable {
    case lake = "lake"
    case river = "river"
    case pond = "pond"
    case coast = "coast"
    case pier = "pier"
    case reservoir = "reservoir"
    case bay = "bay"
    case stream = "stream"
    case canal = "canal"
    case creek = "creek"
    case ocean = "ocean"
    
    var id: String { rawValue }
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var icon: String {
        switch self {
        case .lake, .pond, .reservoir: return "drop.fill"
        case .river, .stream, .creek, .canal: return "water.waves"
        case .bay, .ocean, .coast: return "water.waves.and.arrow.down"
        case .pier: return "building.columns"
        }
    }
}

/// Size tier for waterbody to determine spot generation
enum WaterbodySizeTier: String, Codable, CaseIterable {
    case tiny
    case small
    case medium
    case large
    
    /// Approximate max spots for this tier
    var maxSpots: Int {
        switch self {
        case .tiny: return 1
        case .small, .medium: return 4
        case .large: return 10
        }
    }
}

/// Represents a named body of water (e.g., "Lake Berryessa")
struct Waterbody: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let name: String
    let type: WaterbodyType
    let latitude: Double
    let longitude: Double
    let sizeTier: WaterbodySizeTier
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case latitude
        case longitude
        case sizeTier = "size_tier"
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
