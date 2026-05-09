import Foundation
import SwiftUI
import Combine

/// Global application state
@MainActor
final class AppState: ObservableObject {
    /// Shared instance for dependency injection
    static let shared = AppState()

    // MARK: - Auth & UI state

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var needsProfileSetup = false
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var showError = false

    @Published var selectedTab: AppTab = .spots
    @Published var spotsNavigationPath = NavigationPath()
    @Published var communityNavigationPath = NavigationPath()
    @Published var profileNavigationPath = NavigationPath()

    // MARK: - Progression badges

    @Published var unreadNotifications: Int = 0
    @Published var activeSeason: Season?

    // MARK: - Services (injected)

    private(set) var supabaseService: SupabaseService!
    private(set) var authService: AuthServiceProtocol!
    private(set) var weatherService: WeatherServiceProtocol!
    private(set) var regulationsService: RegulationsServiceProtocol!
    private(set) var fishIDService: FishIDServiceProtocol!
    private(set) var measurementService: MeasurementServiceProtocol!
    private(set) var gameService: GameServiceProtocol!
    private(set) var imageUploadService: ImageUploadServiceProtocol!
    private(set) var challengeService: ChallengeServiceProtocol!
    private(set) var seasonService: SeasonServiceProtocol!
    private(set) var shopService: ShopServiceProtocol!
    private(set) var codexService: CodexServiceProtocol!
    private(set) var notificationService: NotificationServiceProtocol!

    // MARK: - Repositories (injected)

    private(set) var userRepository: UserRepositoryProtocol!
    private(set) var spotRepository: SpotRepositoryProtocol!
    private(set) var catchRepository: CatchRepositoryProtocol!
    private(set) var territoryRepository: TerritoryRepositoryProtocol!
    private(set) var likeRepository: LikeRepositoryProtocol!
    private(set) var speciesRepository: SpeciesRepositoryProtocol!
    private(set) var seasonRepository: SeasonRepositoryProtocol!
    private(set) var shopRepository: ShopRepositoryProtocol!
    private(set) var challengeRepository: ChallengeRepositoryProtocol!
    private(set) var notificationRepository: NotificationRepositoryProtocol!

    private var cancellables = Set<AnyCancellable>()

    private init() {}

    /// Initialize services (call from App.init)
    func configure() {
        // Core
        supabaseService = SupabaseService()

        // Repositories
        userRepository = SupabaseUserRepository(supabase: supabaseService)
        spotRepository = SupabaseSpotRepository(supabase: supabaseService)
        catchRepository = SupabaseCatchRepository(supabase: supabaseService)
        territoryRepository = SupabaseTerritoryRepository(supabase: supabaseService)
        likeRepository = SupabaseLikeRepository(supabase: supabaseService)
        speciesRepository = SupabaseSpeciesRepository(supabase: supabaseService)
        seasonRepository = SupabaseSeasonRepository(supabase: supabaseService)
        shopRepository = SupabaseShopRepository(supabase: supabaseService)
        challengeRepository = SupabaseChallengeRepository(supabase: supabaseService)
        notificationRepository = SupabaseNotificationRepository(supabase: supabaseService)

        // Services
        authService = SupabaseAuthService(supabase: supabaseService, userRepository: userRepository)
        weatherService = OpenWeatherService()
        regulationsService = SupabaseRegulationsService(supabase: supabaseService)
        fishIDService = CoreMLFishIDService()
        measurementService = ARMeasurementService()
        imageUploadService = SupabaseImageUploadService(supabase: supabaseService)

        // Progression services
        challengeService = ChallengeService(challengeRepository: challengeRepository)
        seasonService = SeasonService(
            seasonRepository: seasonRepository,
            userRepository: userRepository
        )
        shopService = ShopService(shopRepository: shopRepository)
        codexService = CodexService(speciesRepository: speciesRepository)
        notificationService = NotificationService(
            notificationRepository: notificationRepository
        )

        // GameService depends on multiple repos + ChallengeService for evaluation.
        gameService = GameService(
            spotRepository: spotRepository,
            catchRepository: catchRepository,
            territoryRepository: territoryRepository,
            userRepository: userRepository,
            speciesRepository: speciesRepository,
            challengeService: challengeService
        )

        // Auth state listener
        setupAuthStateListener()
    }

    private func setupAuthStateListener() {
        Task {
            await checkAuthState()
        }

        NotificationCenter.default.publisher(for: .userDidLogin)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.checkAuthState() }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .userDidLogout)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleLogout()
            }
            .store(in: &cancellables)

        // Refresh notification badge whenever a server-side write may have produced one.
        NotificationCenter.default.publisher(for: .catchCreated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.refreshUnreadCount() }
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

                // Bootstrap progression-side state.
                await bootstrapProgressionState(for: user.id)
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

    /// Runs after login. Idempotent. Best-effort - failures don't block the session.
    private func bootstrapProgressionState(for userId: String) async {
        // Standard `async let` form: bind to the call, then `try? await` at use-site.
        async let assignmentsTask = challengeService.assignedCount(for: userId)
        async let seasonTask = seasonService.getActiveSeason()
        async let unreadTask = notificationService.unreadCount(forUser: userId)

        _ = try? await assignmentsTask
        self.activeSeason = try? await seasonTask
        self.unreadNotifications = (try? await unreadTask) ?? 0

        // Ask for notification permission once. iOS dedups subsequent calls.
        // Required so dethrone alerts can land via UNUserNotificationCenter.
        _ = await notificationService.requestAuthorization()
    }

    /// Pulls fresh unread-notification count for the current user.
    func refreshUnreadCount() async {
        guard let userId = currentUser?.id else { return }
        unreadNotifications = (try? await notificationService.unreadCount(forUser: userId)) ?? 0
    }

    /// Pulls a fresh user row (useful after a catch or shop purchase).
    func refreshCurrentUser() async {
        guard let userId = currentUser?.id else { return }
        if let updated = try? await userRepository.getUser(byId: userId) {
            currentUser = updated
        }
    }

    private func handleLogout() {
        isAuthenticated = false
        currentUser = nil
        needsProfileSetup = false
        unreadNotifications = 0
        activeSeason = nil

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
        case .spots:     return "map.fill"
        case .community: return "person.3.fill"
        case .profile:   return "person.circle.fill"
        case .more:      return "ellipsis.circle.fill"
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
    case codex
    case shop
    case challenges
    case notifications
    case season
}
