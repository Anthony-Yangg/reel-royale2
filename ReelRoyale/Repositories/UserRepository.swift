import Foundation

/// Protocol for user data operations
protocol UserRepositoryProtocol {
    /// Get user by ID
    func getUser(byId id: String) async throws -> User?
    
    /// Get user by username
    func getUser(byUsername username: String) async throws -> User?
    
    /// Create a new user profile
    func createUser(_ user: User) async throws
    
    /// Update user profile
    func updateUser(_ user: User) async throws
    
    /// Get all users (for leaderboards)
    func getAllUsers() async throws -> [User]
    
    /// Get multiple users by IDs
    func getUsers(byIds ids: [String]) async throws -> [User]
    
    /// Search users by username
    func searchUsers(query: String, limit: Int) async throws -> [User]
}

/// Supabase implementation of UserRepository
final class SupabaseUserRepository: UserRepositoryProtocol {
    private let supabase: SupabaseService
    
    init(supabase: SupabaseService) {
        self.supabase = supabase
    }
    
    func getUser(byId id: String) async throws -> User? {
        try await supabase.fetchById(from: AppConstants.Supabase.Tables.profiles, id: id)
    }
    
    func getUser(byUsername username: String) async throws -> User? {
        let results: [User] = try await supabase.database
            .from(AppConstants.Supabase.Tables.profiles)
            .select()
            .eq("username", value: username)
            .limit(1)
            .execute()
            .value
        
        return results.first
    }
    
    func createUser(_ user: User) async throws {
        try await supabase.insert(user, into: AppConstants.Supabase.Tables.profiles)
    }
    
    func updateUser(_ user: User) async throws {
        // Create update payload without id and createdAt
        struct UserUpdate: Encodable {
            let username: String
            let avatar_url: String?
            let home_location: String?
            let bio: String?
            let updated_at: Date
        }
        
        let update = UserUpdate(
            username: user.username,
            avatar_url: user.avatarURL,
            home_location: user.homeLocation,
            bio: user.bio,
            updated_at: Date()
        )
        
        try await supabase.database
            .from(AppConstants.Supabase.Tables.profiles)
            .update(update)
            .eq("id", value: user.id)
            .execute()
    }
    
    func getAllUsers() async throws -> [User] {
        try await supabase.fetchAll(from: AppConstants.Supabase.Tables.profiles)
    }
    
    func getUsers(byIds ids: [String]) async throws -> [User] {
        guard !ids.isEmpty else { return [] }
        
        return try await supabase.database
            .from(AppConstants.Supabase.Tables.profiles)
            .select()
            .in("id", values: ids)
            .execute()
            .value
    }
    
    func searchUsers(query: String, limit: Int = 20) async throws -> [User] {
        try await supabase.database
            .from(AppConstants.Supabase.Tables.profiles)
            .select()
            .ilike("username", pattern: "%\(query)%")
            .limit(limit)
            .execute()
            .value
    }
}

