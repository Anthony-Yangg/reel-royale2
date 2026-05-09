import Foundation

/// User model representing an angler in the app
/// Maps to Supabase 'profiles' table (extends auth.users)
struct User: Identifiable, Codable, Equatable, Hashable {
    let id: String
    var username: String
    var avatarURL: String?
    var homeLocation: String?
    var bio: String?
    var xp: Int
    var rankTier: RankTier
    var lureCoins: Int
    var seasonScore: Int
    var equippedRodSkinId: String?
    var equippedBadgeId: String?
    var equippedFlagId: String?
    var equippedFrameId: String?
    var pushToken: String?
    let createdAt: Date
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case avatarURL = "avatar_url"
        case homeLocation = "home_location"
        case bio
        case xp
        case rankTier = "rank_tier"
        case lureCoins = "lure_coins"
        case seasonScore = "season_score"
        case equippedRodSkinId = "equipped_rod_skin_id"
        case equippedBadgeId = "equipped_badge_id"
        case equippedFlagId = "equipped_flag_id"
        case equippedFrameId = "equipped_frame_id"
        case pushToken = "push_token"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(
        id: String,
        username: String,
        avatarURL: String? = nil,
        homeLocation: String? = nil,
        bio: String? = nil,
        xp: Int = 0,
        rankTier: RankTier = .minnow,
        lureCoins: Int = 0,
        seasonScore: Int = 0,
        equippedRodSkinId: String? = nil,
        equippedBadgeId: String? = nil,
        equippedFlagId: String? = nil,
        equippedFrameId: String? = nil,
        pushToken: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.username = username
        self.avatarURL = avatarURL
        self.homeLocation = homeLocation
        self.bio = bio
        self.xp = xp
        self.rankTier = rankTier
        self.lureCoins = lureCoins
        self.seasonScore = seasonScore
        self.equippedRodSkinId = equippedRodSkinId
        self.equippedBadgeId = equippedBadgeId
        self.equippedFlagId = equippedFlagId
        self.equippedFrameId = equippedFrameId
        self.pushToken = pushToken
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Decoder is permissive: server may omit progression columns on older rows.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        username = try c.decode(String.self, forKey: .username)
        avatarURL = try c.decodeIfPresent(String.self, forKey: .avatarURL)
        homeLocation = try c.decodeIfPresent(String.self, forKey: .homeLocation)
        bio = try c.decodeIfPresent(String.self, forKey: .bio)
        xp = try c.decodeIfPresent(Int.self, forKey: .xp) ?? 0
        rankTier = try c.decodeIfPresent(RankTier.self, forKey: .rankTier) ?? .minnow
        lureCoins = try c.decodeIfPresent(Int.self, forKey: .lureCoins) ?? 0
        seasonScore = try c.decodeIfPresent(Int.self, forKey: .seasonScore) ?? 0
        equippedRodSkinId = try c.decodeIfPresent(String.self, forKey: .equippedRodSkinId)
        equippedBadgeId = try c.decodeIfPresent(String.self, forKey: .equippedBadgeId)
        equippedFlagId = try c.decodeIfPresent(String.self, forKey: .equippedFlagId)
        equippedFrameId = try c.decodeIfPresent(String.self, forKey: .equippedFrameId)
        pushToken = try c.decodeIfPresent(String.self, forKey: .pushToken)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt)
    }
}

/// Player progression rank, derived from total XP.
/// Mirror of Postgres `compute_rank_tier()`. Keep in sync.
enum RankTier: String, Codable, CaseIterable, Comparable, Identifiable {
    case minnow = "Minnow"
    case angler = "Angler"
    case veteran = "Veteran"
    case elite = "Elite"
    case master = "Master"
    case legend = "Legend"

    var id: String { rawValue }

    /// Inclusive XP threshold to enter this tier.
    var minXP: Int {
        switch self {
        case .minnow: return 0
        case .angler: return 1_000
        case .veteran: return 5_000
        case .elite: return 15_000
        case .master: return 40_000
        case .legend: return 100_000
        }
    }

    /// XP at which the *next* tier unlocks. nil for `legend` (terminal).
    var nextTierXP: Int? {
        switch self {
        case .minnow: return RankTier.angler.minXP
        case .angler: return RankTier.veteran.minXP
        case .veteran: return RankTier.elite.minXP
        case .elite: return RankTier.master.minXP
        case .master: return RankTier.legend.minXP
        case .legend: return nil
        }
    }

    var rankOrder: Int {
        switch self {
        case .minnow: return 0
        case .angler: return 1
        case .veteran: return 2
        case .elite: return 3
        case .master: return 4
        case .legend: return 5
        }
    }

    static func < (lhs: RankTier, rhs: RankTier) -> Bool {
        lhs.rankOrder < rhs.rankOrder
    }

    /// Compute rank from total XP. Single source of truth on the client.
    static func from(xp: Int) -> RankTier {
        if xp >= RankTier.legend.minXP { return .legend }
        if xp >= RankTier.master.minXP { return .master }
        if xp >= RankTier.elite.minXP { return .elite }
        if xp >= RankTier.veteran.minXP { return .veteran }
        if xp >= RankTier.angler.minXP { return .angler }
        return .minnow
    }

    /// Progress (0...1) within the current tier toward the next.
    func progress(xp: Int) -> Double {
        guard let next = nextTierXP else { return 1.0 }
        let span = Double(next - minXP)
        guard span > 0 else { return 1.0 }
        return min(1.0, max(0.0, Double(xp - minXP) / span))
    }

    /// XP remaining to reach the next tier; nil if at terminal tier.
    func xpToNext(currentXP: Int) -> Int? {
        guard let next = nextTierXP else { return nil }
        return max(0, next - currentXP)
    }

    var icon: String {
        switch self {
        case .minnow: return "fish"
        case .angler: return "fish.fill"
        case .veteran: return "fish.circle.fill"
        case .elite: return "rosette"
        case .master: return "crown"
        case .legend: return "crown.fill"
        }
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
    let speciesDiscovered: Int
    let releaseCount: Int
    let trophyCount: Int

    static let empty = UserStats(
        totalCatches: 0,
        publicCatches: 0,
        crownedSpots: 0,
        ruledTerritories: 0,
        largestCatch: nil,
        largestCatchUnit: nil,
        favoriteSpecies: nil,
        speciesDiscovered: 0,
        releaseCount: 0,
        trophyCount: 0
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
