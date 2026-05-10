import Foundation
import SwiftUI
import Combine

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
    private(set) var weatherService: WeatherServiceProtocol!
    private(set) var regulationsService: RegulationsServiceProtocol!
    private(set) var fishIDService: FishIDServiceProtocol!
    private(set) var measurementService: MeasurementServiceProtocol!
    private(set) var gameService: GameServiceProtocol!
    private(set) var imageUploadService: ImageUploadServiceProtocol!
    private(set) var haptics: HapticsServiceProtocol!
    private(set) var sounds: SoundServiceProtocol!

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
        
        // Initialize services
        authService = SupabaseAuthService(supabase: supabaseService, userRepository: userRepository)
        weatherService = OpenWeatherService()
        regulationsService = SupabaseRegulationsService(supabase: supabaseService)
        fishIDService = CoreMLFishIDService()
        measurementService = ARMeasurementService()
        imageUploadService = SupabaseImageUploadService(supabase: supabaseService)
        gameService = GameService(
            spotRepository: spotRepository,
            catchRepository: catchRepository,
            territoryRepository: territoryRepository
        )
        haptics = HapticsService()
        sounds = SoundService()

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

/// App tabs (4 primary + center FAB action).
/// Wave 1 keeps existing screens — `.home` is declared but not yet selected by default.
/// Wave 2 will set `.home` as the default selected tab when HomeView ships.
enum AppTab: String, CaseIterable, Identifiable {
    case home      = "Home"
    case spots     = "Map"        // renamed display label; Wave 1 still uses SpotsView
    case community = "Community"
    case profile   = "Profile"
    case more      = "More"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home:      return "house.fill"
        case .spots:     return "map.fill"
        case .community: return "person.3.fill"
        case .profile:   return "person.crop.circle.fill"
        case .more:      return "ellipsis.circle.fill"
        }
    }

    /// Tabs that appear in the visible custom tab bar in Wave 1.
    /// (Home is declared but not rendered yet — comes in Wave 2.)
    static var visibleInWave1: [AppTab] {
        [.spots, .community, .profile, .more]
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
}

