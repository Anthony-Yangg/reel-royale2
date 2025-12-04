import Foundation
import CoreLocation

/// Protocol for fishing spot data operations
protocol SpotRepositoryProtocol {
    /// Get all spots
    func getAllSpots() async throws -> [Spot]
    
    /// Get spot by ID
    func getSpot(byId id: String) async throws -> Spot?
    
    /// Get spots for a territory
    func getSpots(forTerritory territoryId: String) async throws -> [Spot]
    
    /// Get spots near a location
    func getSpots(near coordinate: CLLocationCoordinate2D, radiusMeters: Double) async throws -> [Spot]
    
    /// Get spots by water type
    func getSpots(ofType waterType: WaterType) async throws -> [Spot]
    
    /// Create a new spot
    func createSpot(_ spot: Spot) async throws -> Spot
    
    /// Update spot (including king/queen updates)
    func updateSpot(_ spot: Spot) async throws
    
    /// Get spots where user is king
    func getSpotsRuledBy(userId: String) async throws -> [Spot]
    
    /// Search spots by name
    func searchSpots(query: String, limit: Int) async throws -> [Spot]
}

/// Supabase implementation of SpotRepository
final class SupabaseSpotRepository: SpotRepositoryProtocol {
    private let supabase: SupabaseService
    
    init(supabase: SupabaseService) {
        self.supabase = supabase
    }
    
    func getAllSpots() async throws -> [Spot] {
        try await supabase.fetchAll(from: AppConstants.Supabase.Tables.spots)
    }
    
    func getSpot(byId id: String) async throws -> Spot? {
        try await supabase.fetchById(from: AppConstants.Supabase.Tables.spots, id: id)
    }
    
    func getSpots(forTerritory territoryId: String) async throws -> [Spot] {
        try await supabase.database
            .from(AppConstants.Supabase.Tables.spots)
            .select()
            .eq("territory_id", value: territoryId)
            .execute()
            .value
    }
    
    func getSpots(near coordinate: CLLocationCoordinate2D, radiusMeters: Double) async throws -> [Spot] {
        // Supabase PostGIS query for nearby spots
        // Using a simple bounding box approach for now
        // For production, use PostGIS geography functions
        
        let latDelta = radiusMeters / 111000.0 // ~111km per degree of latitude
        let lonDelta = radiusMeters / (111000.0 * cos(coordinate.latitude * .pi / 180))
        
        let minLat = coordinate.latitude - latDelta
        let maxLat = coordinate.latitude + latDelta
        let minLon = coordinate.longitude - lonDelta
        let maxLon = coordinate.longitude + lonDelta
        
        let spots: [Spot] = try await supabase.database
            .from(AppConstants.Supabase.Tables.spots)
            .select()
            .gte("latitude", value: minLat)
            .lte("latitude", value: maxLat)
            .gte("longitude", value: minLon)
            .lte("longitude", value: maxLon)
            .execute()
            .value
        
        // Filter by actual distance and sort
        let filteredSpots = spots
            .map { spot -> (Spot, Double) in
                let distance = coordinate.distance(to: spot.coordinate)
                return (spot, distance)
            }
            .filter { $0.1 <= radiusMeters }
            .sorted { $0.1 < $1.1 }
            .map { $0.0 }
        
        return filteredSpots
    }
    
    func getSpots(ofType waterType: WaterType) async throws -> [Spot] {
        try await supabase.database
            .from(AppConstants.Supabase.Tables.spots)
            .select()
            .eq("water_type", value: waterType.rawValue)
            .execute()
            .value
    }
    
    func createSpot(_ spot: Spot) async throws -> Spot {
        try await supabase.insertAndReturn(spot, into: AppConstants.Supabase.Tables.spots)
    }
    
    func updateSpot(_ spot: Spot) async throws {
        struct SpotUpdate: Encodable {
            let name: String
            let description: String?
            let latitude: Double
            let longitude: Double
            let water_type: String?
            let territory_id: String?
            let current_king_user_id: String?
            let current_best_catch_id: String?
            let current_best_size: Double?
            let current_best_unit: String?
            let image_url: String?
            let region_name: String?
            let updated_at: Date
        }
        
        let update = SpotUpdate(
            name: spot.name,
            description: spot.description,
            latitude: spot.latitude,
            longitude: spot.longitude,
            water_type: spot.waterType?.rawValue,
            territory_id: spot.territoryId,
            current_king_user_id: spot.currentKingUserId,
            current_best_catch_id: spot.currentBestCatchId,
            current_best_size: spot.currentBestSize,
            current_best_unit: spot.currentBestUnit,
            image_url: spot.imageURL,
            region_name: spot.regionName,
            updated_at: Date()
        )
        
        try await supabase.database
            .from(AppConstants.Supabase.Tables.spots)
            .update(update)
            .eq("id", value: spot.id)
            .execute()
    }
    
    func getSpotsRuledBy(userId: String) async throws -> [Spot] {
        try await supabase.database
            .from(AppConstants.Supabase.Tables.spots)
            .select()
            .eq("current_king_user_id", value: userId)
            .execute()
            .value
    }
    
    func searchSpots(query: String, limit: Int = 20) async throws -> [Spot] {
        try await supabase.database
            .from(AppConstants.Supabase.Tables.spots)
            .select()
            .ilike("name", pattern: "%\(query)%")
            .limit(limit)
            .execute()
            .value
    }
}

