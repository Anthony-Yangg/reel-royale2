import Foundation

/// Protocol for fishing regulations data
protocol RegulationsServiceProtocol {
    /// Get regulations for a specific spot
    func getRegulations(for spotId: String) async throws -> RegulationInfo?
    
    /// Get regulations for a territory/region
    func getRegulations(forTerritory territoryId: String) async throws -> RegulationInfo?
    
    /// Get regulations by region name
    func getRegulations(forRegion regionName: String) async throws -> RegulationInfo?
    
    /// Get all regulations
    func getAllRegulations() async throws -> [RegulationInfo]
}

/// Supabase implementation of RegulationsService
final class SupabaseRegulationsService: RegulationsServiceProtocol {
    private let supabase: SupabaseService
    
    init(supabase: SupabaseService) {
        self.supabase = supabase
    }
    
    func getRegulations(for spotId: String) async throws -> RegulationInfo? {
        let results: [RegulationInfo] = try await supabase.database
            .from(AppConstants.Supabase.Tables.regulations)
            .select()
            .eq("spot_id", value: spotId)
            .limit(1)
            .execute()
            .value
        
        return results.first
    }
    
    func getRegulations(forTerritory territoryId: String) async throws -> RegulationInfo? {
        let results: [RegulationInfo] = try await supabase.database
            .from(AppConstants.Supabase.Tables.regulations)
            .select()
            .eq("territory_id", value: territoryId)
            .limit(1)
            .execute()
            .value
        
        return results.first
    }
    
    func getRegulations(forRegion regionName: String) async throws -> RegulationInfo? {
        let results: [RegulationInfo] = try await supabase.database
            .from(AppConstants.Supabase.Tables.regulations)
            .select()
            .ilike("region_name", pattern: "%\(regionName)%")
            .limit(1)
            .execute()
            .value
        
        return results.first
    }
    
    func getAllRegulations() async throws -> [RegulationInfo] {
        try await supabase.fetchAll(from: AppConstants.Supabase.Tables.regulations)
    }
}

