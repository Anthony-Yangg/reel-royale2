import Foundation

/// Size unit for fish measurements
enum SizeUnit: String, Codable, CaseIterable, Identifiable {
    case cm = "cm"
    case inches = "in"
    case kg = "kg"
    case lbs = "lbs"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .cm: return "Centimeters"
        case .inches: return "Inches"
        case .kg: return "Kilograms"
        case .lbs: return "Pounds"
        }
    }
    
    var isLength: Bool {
        self == .cm || self == .inches
    }
    
    var isWeight: Bool {
        self == .kg || self == .lbs
    }
}

/// Visibility options for catches
enum CatchVisibility: String, Codable, CaseIterable, Identifiable {
    case `public` = "public"
    case friendsOnly = "friends_only"
    case `private` = "private"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .public: return "Public"
        case .friendsOnly: return "Friends Only"
        case .private: return "Private"
        }
    }
    
    var icon: String {
        switch self {
        case .public: return "globe"
        case .friendsOnly: return "person.2.fill"
        case .private: return "lock.fill"
        }
    }
}

/// Fish catch model
/// Maps to Supabase 'catches' table
struct FishCatch: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let userId: String
    let spotId: String
    var photoURL: String?
    var species: String
    var sizeValue: Double
    var sizeUnit: String
    var visibility: CatchVisibility
    var hideExactLocation: Bool
    var notes: String?
    var weatherSnapshot: String? // JSON encoded weather at time of catch
    var measuredWithAR: Bool
    let createdAt: Date
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case spotId = "spot_id"
        case photoURL = "photo_url"
        case species
        case sizeValue = "size_value"
        case sizeUnit = "size_unit"
        case visibility
        case hideExactLocation = "hide_exact_location"
        case notes
        case weatherSnapshot = "weather_snapshot"
        case measuredWithAR = "measured_with_ar"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        spotId: String,
        photoURL: String? = nil,
        species: String,
        sizeValue: Double,
        sizeUnit: String = "cm",
        visibility: CatchVisibility = .public,
        hideExactLocation: Bool = false,
        notes: String? = nil,
        weatherSnapshot: String? = nil,
        measuredWithAR: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.spotId = spotId
        self.photoURL = photoURL
        self.species = species
        self.sizeValue = sizeValue
        self.sizeUnit = sizeUnit
        self.visibility = visibility
        self.hideExactLocation = hideExactLocation
        self.notes = notes
        self.weatherSnapshot = weatherSnapshot
        self.measuredWithAR = measuredWithAR
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    var isPublic: Bool {
        visibility == .public || visibility == .friendsOnly
    }
    
    var sizeDisplay: String {
        "\(String(format: "%.1f", sizeValue)) \(sizeUnit)"
    }
    
    /// Convert size to centimeters for comparison
    var normalizedSizeInCm: Double {
        switch sizeUnit.lowercased() {
        case "in", "inches":
            return sizeValue * 2.54
        case "cm":
            return sizeValue
        default:
            return sizeValue
        }
    }
}

/// Catch with related data for display
struct CatchWithDetails: Identifiable, Equatable {
    let fishCatch: FishCatch
    let user: User?
    let spot: Spot?
    var likeCount: Int
    var isLikedByCurrentUser: Bool
    var isCurrentKing: Bool
    
    var id: String { fishCatch.id }
}

struct CommunityPost: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let userId: String
    var mediaURLs: [String]
    var caption: String
    var locationName: String?
    var hashtags: [String]
    let createdAt: Date
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case mediaURLs = "media_urls"
        case caption
        case locationName = "location_name"
        case hashtags
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        mediaURLs: [String],
        caption: String,
        locationName: String? = nil,
        hashtags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.userId = userId
        self.mediaURLs = mediaURLs
        self.caption = caption
        self.locationName = locationName
        self.hashtags = hashtags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct CommunityComment: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let postId: String
    let userId: String
    var text: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case userId = "user_id"
        case text
        case createdAt = "created_at"
    }
    
    init(
        id: String = UUID().uuidString,
        postId: String,
        userId: String,
        text: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.postId = postId
        self.userId = userId
        self.text = text
        self.createdAt = createdAt
    }
}

struct CommunityPostDetails: Identifiable, Equatable {
    let post: CommunityPost
    let author: User?
    var likeCount: Int
    var commentCount: Int
    var isLikedByCurrentUser: Bool
    var isFollowingAuthor: Bool
    
    var id: String { post.id }
}

struct Follow: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let followerId: String
    let followingId: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case followerId = "follower_id"
        case followingId = "following_id"
        case createdAt = "created_at"
    }
    
    init(
        id: String = UUID().uuidString,
        followerId: String,
        followingId: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.followerId = followerId
        self.followingId = followingId
        self.createdAt = createdAt
    }
}

struct PostLike: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let postId: String
    let userId: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }
    
    init(
        id: String = UUID().uuidString,
        postId: String,
        userId: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.postId = postId
        self.userId = userId
        self.createdAt = createdAt
    }
}

struct PostLikeInfo {
    let postId: String
    let totalCount: Int
    let isLikedByCurrentUser: Bool
    
    static func empty(for postId: String) -> PostLikeInfo {
        PostLikeInfo(postId: postId, totalCount: 0, isLikedByCurrentUser: false)
    }
}

/// Input for creating a new catch
struct CreateCatchInput {
    var spotId: String
    var photoData: Data?
    var species: String
    var sizeValue: Double
    var sizeUnit: String
    var visibility: CatchVisibility
    var hideExactLocation: Bool
    var notes: String?
    var measuredWithAR: Bool
    
    init(
        spotId: String = "",
        photoData: Data? = nil,
        species: String = "",
        sizeValue: Double = 0,
        sizeUnit: String = "cm",
        visibility: CatchVisibility = .public,
        hideExactLocation: Bool = false,
        notes: String? = nil,
        measuredWithAR: Bool = false
    ) {
        self.spotId = spotId
        self.photoData = photoData
        self.species = species
        self.sizeValue = sizeValue
        self.sizeUnit = sizeUnit
        self.visibility = visibility
        self.hideExactLocation = hideExactLocation
        self.notes = notes
        self.measuredWithAR = measuredWithAR
    }
    
    var isValid: Bool {
        !spotId.isEmpty && !species.isEmpty && sizeValue > 0
    }
}

