import Foundation

/// Protocol for territory data operations
protocol TerritoryRepositoryProtocol {
    /// Get all territories
    func getAllTerritories() async throws -> [Territory]
    
    /// Get territory by ID
    func getTerritory(byId id: String) async throws -> Territory?
    
    /// Get territory for a spot
    func getTerritory(forSpot spotId: String) async throws -> Territory?
    
    /// Create a new territory
    func createTerritory(_ territory: Territory) async throws -> Territory
    
    /// Update territory
    func updateTerritory(_ territory: Territory) async throws
    
    /// Add spot to territory
    func addSpot(_ spotId: String, to territoryId: String) async throws
    
    /// Remove spot from territory
    func removeSpot(_ spotId: String, from territoryId: String) async throws
    
    /// Search territories by name
    func searchTerritories(query: String, limit: Int) async throws -> [Territory]
}

/// Supabase implementation of TerritoryRepository
final class SupabaseTerritoryRepository: TerritoryRepositoryProtocol {
    private let supabase: SupabaseService
    
    /// Encodable payloads to avoid type-mismatch issues when updating via dictionaries
    private struct TerritoryUpdatePayload: Encodable {
        let name: String
        let description: String?
        let spot_ids: [String]
        let image_url: String?
        let region_name: String?
        let center_latitude: Double?
        let center_longitude: Double?
        let updated_at: Date
        
        init(from territory: Territory) {
            self.name = territory.name
            self.description = territory.description
            self.spot_ids = territory.spotIds
            self.image_url = territory.imageURL
            self.region_name = territory.regionName
            self.center_latitude = territory.centerLatitude
            self.center_longitude = territory.centerLongitude
            self.updated_at = Date()
        }
    }
    
    private struct SpotTerritoryUpdate: Encodable {
        let territory_id: String?
        let updated_at: Date
    }
    
    init(supabase: SupabaseService) {
        self.supabase = supabase
    }
    
    func getAllTerritories() async throws -> [Territory] {
        try await supabase.fetchAll(from: AppConstants.Supabase.Tables.territories)
    }
    
    func getTerritory(byId id: String) async throws -> Territory? {
        try await supabase.fetchById(from: AppConstants.Supabase.Tables.territories, id: id)
    }
    
    func getTerritory(forSpot spotId: String) async throws -> Territory? {
        // Get the spot first to find its territory ID
        let spot: Spot? = try await supabase.fetchById(
            from: AppConstants.Supabase.Tables.spots,
            id: spotId
        )
        
        guard let territoryId = spot?.territoryId else { return nil }
        
        return try await getTerritory(byId: territoryId)
    }
    
    func createTerritory(_ territory: Territory) async throws -> Territory {
        try await supabase.insertAndReturn(territory, into: AppConstants.Supabase.Tables.territories)
    }
    
    func updateTerritory(_ territory: Territory) async throws {
        try await supabase.database
            .from(AppConstants.Supabase.Tables.territories)
            .update(TerritoryUpdatePayload(from: territory))
            .eq("id", value: territory.id)
            .execute()
    }
    
    func addSpot(_ spotId: String, to territoryId: String) async throws {
        guard var territory = try await getTerritory(byId: territoryId) else {
            throw AppError.notFound("Territory")
        }
        
        if !territory.spotIds.contains(spotId) {
            territory.spotIds.append(spotId)
            try await updateTerritory(territory)
        }
        
        // Also update the spot's territory reference
        try await supabase.database
            .from(AppConstants.Supabase.Tables.spots)
            .update(SpotTerritoryUpdate(territory_id: territoryId, updated_at: Date()))
            .eq("id", value: spotId)
            .execute()
    }
    
    func removeSpot(_ spotId: String, from territoryId: String) async throws {
        guard var territory = try await getTerritory(byId: territoryId) else {
            throw AppError.notFound("Territory")
        }
        
        territory.spotIds.removeAll { $0 == spotId }
        try await updateTerritory(territory)
        
        // Also clear the spot's territory reference
        try await supabase.database
            .from(AppConstants.Supabase.Tables.spots)
            .update(SpotTerritoryUpdate(territory_id: nil, updated_at: Date()))
            .eq("id", value: spotId)
            .execute()
    }
    
    func searchTerritories(query: String, limit: Int = 20) async throws -> [Territory] {
        try await supabase.database
            .from(AppConstants.Supabase.Tables.territories)
            .select()
            .ilike("name", pattern: "%\(query)%")
            .limit(limit)
            .execute()
            .value
    }
}

