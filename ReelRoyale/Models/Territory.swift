import Foundation
import CoreLocation

/// Territory model - groups multiple spots into a controllable region
/// Maps to Supabase 'territories' table
struct Territory: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var name: String
    var description: String?
    var spotIds: [String]
    var imageURL: String?
    var regionName: String?
    var centerLatitude: Double?
    var centerLongitude: Double?
    let createdAt: Date
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case spotIds = "spot_ids"
        case imageURL = "image_url"
        case regionName = "region_name"
        case centerLatitude = "center_latitude"
        case centerLongitude = "center_longitude"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(
        id: String = UUID().uuidString,
        name: String,
        description: String? = nil,
        spotIds: [String] = [],
        imageURL: String? = nil,
        regionName: String? = nil,
        centerLatitude: Double? = nil,
        centerLongitude: Double? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.spotIds = spotIds
        self.imageURL = imageURL
        self.regionName = regionName
        self.centerLatitude = centerLatitude
        self.centerLongitude = centerLongitude
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    var spotCount: Int {
        spotIds.count
    }
    
    var centerCoordinate: CLLocationCoordinate2D? {
        guard let lat = centerLatitude, let lon = centerLongitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

/// Territory with computed ruler information
struct TerritoryWithControl: Identifiable, Equatable {
    let territory: Territory
    let spots: [Spot]
    let rulerUserId: String?
    let rulerUser: User?
    let crownCounts: [String: Int] // userId -> number of crowned spots
    let currentUserCrowns: Int
    
    var id: String { territory.id }
    
    var totalSpots: Int { spots.count }
    
    var rulerCrownCount: Int {
        guard let rulerId = rulerUserId else { return 0 }
        return crownCounts[rulerId] ?? 0
    }
    
    /// Determines the ruler as the user with most crowned spots
    /// In case of tie, the one with highest total catch size wins
    static func calculateRuler(
        spots: [Spot],
        catches: [FishCatch]
    ) -> (rulerId: String?, crownCounts: [String: Int]) {
        var crownCounts: [String: Int] = [:]
        var totalSizes: [String: Double] = [:]
        
        for spot in spots {
            if let kingId = spot.currentKingUserId {
                crownCounts[kingId, default: 0] += 1
                
                // Sum up total catch sizes for tiebreaker
                if let bestSize = spot.currentBestSize {
                    totalSizes[kingId, default: 0] += bestSize
                }
            }
        }
        
        // Find user with most crowns
        let sorted = crownCounts.sorted { lhs, rhs in
            if lhs.value != rhs.value {
                return lhs.value > rhs.value
            }
            // Tiebreaker: total size
            return (totalSizes[lhs.key] ?? 0) > (totalSizes[rhs.key] ?? 0)
        }
        
        let rulerId = sorted.first?.key
        return (rulerId, crownCounts)
    }
}

/// Leaderboard entry for territory control
struct TerritoryLeaderboardEntry: Identifiable, Equatable {
    let userId: String
    let user: User?
    let crownCount: Int
    let territoriesRuled: Int
    let rank: Int
    
    var id: String { "\(userId)-\(rank)" }
}

