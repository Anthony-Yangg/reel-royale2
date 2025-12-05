import Foundation

/// Protocol for catch data operations
protocol CatchRepositoryProtocol {
    /// Create a new catch
    func createCatch(_ fishCatch: FishCatch) async throws -> FishCatch
    
    /// Get catch by ID
    func getCatch(byId id: String) async throws -> FishCatch?
    
    /// Update a catch
    func updateCatch(_ fishCatch: FishCatch) async throws
    
    /// Delete a catch
    func deleteCatch(id: String) async throws
    
    /// Get catches for a spot
    func getCatches(forSpot spotId: String) async throws -> [FishCatch]
    
    /// Get catches for a user
    func getCatches(forUser userId: String) async throws -> [FishCatch]
    
    /// Get recent public catches (for community feed)
    func getRecentPublicCatches(limit: Int, offset: Int) async throws -> [FishCatch]
    
    /// Get best catch for a spot (for king determination)
    func getBestCatch(forSpot spotId: String) async throws -> FishCatch?
    
    /// Get public catches for spot (for leaderboard)
    func getPublicCatches(forSpot spotId: String, limit: Int) async throws -> [FishCatch]
}

/// Supabase implementation of CatchRepository
final class SupabaseCatchRepository: CatchRepositoryProtocol {
    private let supabase: SupabaseService
    
    init(supabase: SupabaseService) {
        self.supabase = supabase
    }
    
    func createCatch(_ fishCatch: FishCatch) async throws -> FishCatch {
        try await supabase.insertAndReturn(fishCatch, into: AppConstants.Supabase.Tables.catches)
    }
    
    func getCatch(byId id: String) async throws -> FishCatch? {
        try await supabase.fetchById(from: AppConstants.Supabase.Tables.catches, id: id)
    }
    
    func updateCatch(_ fishCatch: FishCatch) async throws {
        struct CatchUpdate: Encodable {
            let photo_url: String?
            let species: String
            let size_value: Double
            let size_unit: String
            let visibility: String
            let hide_exact_location: Bool
            let notes: String?
            let weather_snapshot: String?
            let measured_with_ar: Bool
            let updated_at: Date
        }
        
        let update = CatchUpdate(
            photo_url: fishCatch.photoURL,
            species: fishCatch.species,
            size_value: fishCatch.sizeValue,
            size_unit: fishCatch.sizeUnit,
            visibility: fishCatch.visibility.rawValue,
            hide_exact_location: fishCatch.hideExactLocation,
            notes: fishCatch.notes,
            weather_snapshot: fishCatch.weatherSnapshot,
            measured_with_ar: fishCatch.measuredWithAR,
            updated_at: Date()
        )
        
        try await supabase.client
            .from(AppConstants.Supabase.Tables.catches)
            .update(update)
            .eq("id", value: fishCatch.id)
            .execute()
    }
    
    func deleteCatch(id: String) async throws {
        try await supabase.delete(from: AppConstants.Supabase.Tables.catches, id: id)
    }
    
    func getCatches(forSpot spotId: String) async throws -> [FishCatch] {
        try await supabase.client
            .from(AppConstants.Supabase.Tables.catches)
            .select()
            .eq("spot_id", value: spotId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }
    
    func getCatches(forUser userId: String) async throws -> [FishCatch] {
        try await supabase.client
            .from(AppConstants.Supabase.Tables.catches)
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }
    
    func getRecentPublicCatches(limit: Int = 20, offset: Int = 0) async throws -> [FishCatch] {
        try await supabase.client
            .from(AppConstants.Supabase.Tables.catches)
            .select()
            .or("visibility.eq.public,visibility.eq.friends_only")
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
    }
    
    func getBestCatch(forSpot spotId: String) async throws -> FishCatch? {
        let catches: [FishCatch] = try await supabase.client
            .from(AppConstants.Supabase.Tables.catches)
            .select()
            .eq("spot_id", value: spotId)
            .or("visibility.eq.public,visibility.eq.friends_only")
            .order("size_value", ascending: false)
            .limit(1)
            .execute()
            .value
        
        return catches.first
    }
    
    func getPublicCatches(forSpot spotId: String, limit: Int = 20) async throws -> [FishCatch] {
        try await supabase.client
            .from(AppConstants.Supabase.Tables.catches)
            .select()
            .eq("spot_id", value: spotId)
            .or("visibility.eq.public,visibility.eq.friends_only")
            .order("size_value", ascending: false)
            .limit(limit)
            .execute()
            .value
    }
}

