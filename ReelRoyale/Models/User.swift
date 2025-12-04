import Foundation

/// User model representing an angler in the app
/// Maps to Supabase 'profiles' table (extends auth.users)
struct User: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var username: String
    var avatarURL: String?
    var homeLocation: String?
    var bio: String?
    let createdAt: Date
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case avatarURL = "avatar_url"
        case homeLocation = "home_location"
        case bio
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(
        id: String,
        username: String,
        avatarURL: String? = nil,
        homeLocation: String? = nil,
        bio: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.username = username
        self.avatarURL = avatarURL
        self.homeLocation = homeLocation
        self.bio = bio
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// User statistics computed from catches and spots
struct UserStats: Equatable {
    let totalCatches: Int
    let publicCatches: Int
    let crownedSpots: Int
    let ruledTerritories: Int
    let largestCatch: Double?
    let largestCatchUnit: String?
    let favoriteSpecies: String?
    
    static let empty = UserStats(
        totalCatches: 0,
        publicCatches: 0,
        crownedSpots: 0,
        ruledTerritories: 0,
        largestCatch: nil,
        largestCatchUnit: nil,
        favoriteSpecies: nil
    )
}

/// Represents the current authenticated session
struct AuthSession: Codable {
    let accessToken: String
    let refreshToken: String
    let userId: String
    let expiresAt: Date
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case userId = "user_id"
        case expiresAt = "expires_at"
    }
}

