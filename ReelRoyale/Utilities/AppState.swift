import Foundation
import SwiftUI
import Combine

protocol CommunityPostRepositoryProtocol {
    func createPost(_ post: CommunityPost) async throws -> CommunityPost
    func getFeed(limit: Int, offset: Int) async throws -> [CommunityPost]
    func getPost(by id: String) async throws -> CommunityPost?
    func getComments(for postId: String) async throws -> [CommunityComment]
    func addComment(_ comment: CommunityComment) async throws -> CommunityComment
    func toggleLike(postId: String, userId: String) async throws -> Bool
    func getLikeInfo(for postIds: [String], currentUserId: String) async throws -> [String: PostLikeInfo]
}

final class SupabaseCommunityPostRepository: CommunityPostRepositoryProtocol {
    private let supabase: SupabaseService
    
    init(supabase: SupabaseService) {
        self.supabase = supabase
    }
    
    func createPost(_ post: CommunityPost) async throws -> CommunityPost {
        try await supabase.insertAndReturn(post, into: AppConstants.Supabase.Tables.communityPosts)
    }
    
    func getFeed(limit: Int, offset: Int) async throws -> [CommunityPost] {
        try await supabase.database
            .from(AppConstants.Supabase.Tables.communityPosts)
            .select()
            .order("created_at", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
            .value
    }
    
    func getPost(by id: String) async throws -> CommunityPost? {
        try await supabase.fetchById(from: AppConstants.Supabase.Tables.communityPosts, id: id)
    }
    
    func getComments(for postId: String) async throws -> [CommunityComment] {
        try await supabase.database
            .from(AppConstants.Supabase.Tables.postComments)
            .select()
            .eq("post_id", value: postId)
            .order("created_at", ascending: true)
            .execute()
            .value
    }
    
    func addComment(_ comment: CommunityComment) async throws -> CommunityComment {
        try await supabase.insertAndReturn(comment, into: AppConstants.Supabase.Tables.postComments)
    }
    
    func toggleLike(postId: String, userId: String) async throws -> Bool {
        let hasLiked = try await hasUserLiked(postId: postId, userId: userId)
        if hasLiked {
            try await removeLike(postId: postId, userId: userId)
            return false
        } else {
            _ = try await addLike(postId: postId, userId: userId)
            return true
        }
    }
    
    func getLikeInfo(for postIds: [String], currentUserId: String) async throws -> [String: PostLikeInfo] {
        guard !postIds.isEmpty else { return [:] }
        let likes: [PostLike] = try await supabase.database
            .from(AppConstants.Supabase.Tables.postLikes)
            .select()
            .in("post_id", values: postIds)
            .execute()
            .value
        var likeInfo: [String: PostLikeInfo] = [:]
        for postId in postIds {
            let postLikes = likes.filter { $0.postId == postId }
            let isLiked = postLikes.contains { $0.userId == currentUserId }
            likeInfo[postId] = PostLikeInfo(postId: postId, totalCount: postLikes.count, isLikedByCurrentUser: isLiked)
        }
        return likeInfo
    }
    
    private func addLike(postId: String, userId: String) async throws -> PostLike {
        let like = PostLike(postId: postId, userId: userId)
        return try await supabase.insertAndReturn(like, into: AppConstants.Supabase.Tables.postLikes)
    }
    
    private func removeLike(postId: String, userId: String) async throws {
        try await supabase.database
            .from(AppConstants.Supabase.Tables.postLikes)
            .delete()
            .eq("post_id", value: postId)
            .eq("user_id", value: userId)
            .execute()
    }
    
    private func hasUserLiked(postId: String, userId: String) async throws -> Bool {
        let likes: [PostLike] = try await supabase.database
            .from(AppConstants.Supabase.Tables.postLikes)
            .select()
            .eq("post_id", value: postId)
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        return !likes.isEmpty
    }
}

protocol FollowRepositoryProtocol {
    func isFollowing(followerId: String, followingId: String) async throws -> Bool
    func toggleFollow(followerId: String, followingId: String) async throws -> Bool
}

final class SupabaseFollowRepository: FollowRepositoryProtocol {
    private let supabase: SupabaseService
    
    init(supabase: SupabaseService) {
        self.supabase = supabase
    }
    
    func isFollowing(followerId: String, followingId: String) async throws -> Bool {
        let follows: [Follow] = try await supabase.database
            .from(AppConstants.Supabase.Tables.follows)
            .select()
            .eq("follower_id", value: followerId)
            .eq("following_id", value: followingId)
            .limit(1)
            .execute()
            .value
        return !follows.isEmpty
    }
    
    func toggleFollow(followerId: String, followingId: String) async throws -> Bool {
        let currentlyFollowing = try await isFollowing(followerId: followerId, followingId: followingId)
        if currentlyFollowing {
            try await supabase.database
                .from(AppConstants.Supabase.Tables.follows)
                .delete()
                .eq("follower_id", value: followerId)
                .eq("following_id", value: followingId)
                .execute()
            return false
        } else {
            let follow = Follow(followerId: followerId, followingId: followingId)
            _ = try await supabase.insertAndReturn(follow, into: AppConstants.Supabase.Tables.follows)
            return true
        }
    }
}

/// Global application state
@MainActor
final class AppState: ObservableObject {
    /// Shared instance for dependency injection
    static let shared = AppState()
    
    /// Current authentication state
    @Published var isAuthenticated = false
    
    /// Current user (nil if not logged in)
    @Published var currentUser: User?
    
    /// Whether profile setup is needed after signup
    @Published var needsProfileSetup = false
    
    /// Loading state for initial app launch
    @Published var isLoading = true
    
    /// Global error message
    @Published var errorMessage: String?
    
    /// Show error alert
    @Published var showError = false
    
    /// Selected tab
    @Published var selectedTab: AppTab = .spots
    
    /// Navigation path for spots tab
    @Published var spotsNavigationPath = NavigationPath()
    
    /// Navigation path for community tab
    @Published var communityNavigationPath = NavigationPath()
    
    /// Navigation path for profile tab
    @Published var profileNavigationPath = NavigationPath()
    
    /// Services (injected)
    private(set) var supabaseService: SupabaseService!
    private(set) var authService: AuthServiceProtocol!
    private(set) var userRepository: UserRepositoryProtocol!
    private(set) var spotRepository: SpotRepositoryProtocol!
    private(set) var catchRepository: CatchRepositoryProtocol!
    private(set) var territoryRepository: TerritoryRepositoryProtocol!
    private(set) var likeRepository: LikeRepositoryProtocol!
    private(set) var communityPostRepository: CommunityPostRepositoryProtocol!
    private(set) var followRepository: FollowRepositoryProtocol!
    private(set) var weatherService: WeatherServiceProtocol!
    private(set) var regulationsService: RegulationsServiceProtocol!
    private(set) var fishIDService: FishIDServiceProtocol!
    private(set) var measurementService: MeasurementServiceProtocol!
    private(set) var gameService: GameServiceProtocol!
    private(set) var imageUploadService: ImageUploadServiceProtocol!
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    /// Initialize services (call from App.init)
    func configure() {
        // Initialize Supabase
        supabaseService = SupabaseService()
        
        // Initialize repositories
        userRepository = SupabaseUserRepository(supabase: supabaseService)
        spotRepository = SupabaseSpotRepository(supabase: supabaseService)
        catchRepository = SupabaseCatchRepository(supabase: supabaseService)
        territoryRepository = SupabaseTerritoryRepository(supabase: supabaseService)
        likeRepository = SupabaseLikeRepository(supabase: supabaseService)
        communityPostRepository = SupabaseCommunityPostRepository(supabase: supabaseService)
        followRepository = SupabaseFollowRepository(supabase: supabaseService)
        
        // Initialize services
        authService = SupabaseAuthService(supabase: supabaseService, userRepository: userRepository)
        weatherService = OpenWeatherService()
        regulationsService = SupabaseRegulationsService(supabase: supabaseService)
        fishIDService = OpenRouterFishIDService()
        measurementService = ARMeasurementService()
        imageUploadService = SupabaseImageUploadService(supabase: supabaseService)
        gameService = GameService(
            spotRepository: spotRepository,
            catchRepository: catchRepository,
            territoryRepository: territoryRepository
        )
        
        // Set up auth state listener
        setupAuthStateListener()
    }
    
    private func setupAuthStateListener() {
        // Check initial auth state
        Task {
            await checkAuthState()
        }
        
        // Listen for auth changes
        NotificationCenter.default.publisher(for: .userDidLogin)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.checkAuthState()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .userDidLogout)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleLogout()
            }
            .store(in: &cancellables)
    }
    
    private func checkAuthState() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            if let user = try await authService.getCurrentUser() {
                currentUser = user
                isAuthenticated = true
                needsProfileSetup = user.username.isEmpty
            } else {
                isAuthenticated = false
                currentUser = nil
            }
        } catch {
            print("Error checking auth state: \(error)")
            isAuthenticated = false
            currentUser = nil
        }
    }
    
    private func handleLogout() {
        isAuthenticated = false
        currentUser = nil
        needsProfileSetup = false
        
        // Reset navigation
        spotsNavigationPath = NavigationPath()
        communityNavigationPath = NavigationPath()
        profileNavigationPath = NavigationPath()
        selectedTab = .spots
    }
    
    func showError(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    func updateCurrentUser(_ user: User) {
        currentUser = user
        needsProfileSetup = false
    }
    
    func signOut() async {
        do {
            try await authService.signOut()
            handleLogout()
        } catch {
            showError("Failed to sign out: \(error.localizedDescription)")
        }
    }
}

/// App tabs
enum AppTab: String, CaseIterable, Identifiable {
    case spots = "Spots"
    case community = "Community"
    case profile = "Profile"
    case more = "More"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .spots: return "map.fill"
        case .community: return "person.3.fill"
        case .profile: return "person.circle.fill"
        case .more: return "ellipsis.circle.fill"
        }
    }
}

/// Navigation destinations
enum NavigationDestination: Hashable {
    case spotDetail(spotId: String)
    case catchDetail(catchId: String)
    case logCatch(spotId: String?)
    case userProfile(userId: String)
    case territory(territoryId: String)
    case regulations(spotId: String?)
    case fishID
    case measureFish
    case leaderboard
    case settings
    case createPost
    case postDetail(postId: String)
}

