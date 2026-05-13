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

    #if DEBUG
    /// Local-only login bypass for development builds.
    @Published private(set) var isUsingAuthBypass = false
    #endif

    /// Current user (nil if not logged in)
    @Published var currentUser: User?
    @Published var needsProfileSetup = false
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var showError = false

    /// Selected tab. Defaults to Home.
    @Published var selectedTab: AppTab = .home
    @Published var spotsNavigationPath = NavigationPath()
    @Published var communityNavigationPath = NavigationPath()
    @Published var profileNavigationPath = NavigationPath()
    @Published var homeNavigationPath = NavigationPath()
    @Published var fishLogNavigationPath = NavigationPath()

    // MARK: - Progression badges

    @Published var unreadNotifications: Int = 0
    @Published var activeSeason: Season?

    // MARK: - Live HUD (persistent identity-header status)

    /// Number of spots where the current user currently holds the crown.
    @Published var crownsHeld: Int = 0

    /// Current user's placement on the active season's global leaderboard, 1-indexed. nil while unknown.
    @Published var seasonRank: Int?

    /// Rolling daily-catch streak (consecutive days with at least one public catch). 0 if not loaded.
    @Published var dailyStreak: Int = 0

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
    // UI feedback + mock services from the redesign waves
    private(set) var haptics: HapticsServiceProtocol!
    private(set) var sounds: SoundServiceProtocol!
    private(set) var bountyService: BountyServiceProtocol!
    private(set) var dethroneEventService: DethroneEventServiceProtocol!
    private(set) var leaderboardService: LeaderboardServiceProtocol!

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

    /// DEBUG-only preview bypass.
    /// Setting UserDefaults RR_PREVIEW_AUTH_BYPASS=YES skips Supabase auth
    /// and injects a mock captain for visual QA.
    #if DEBUG
    private var previewBypassEnabled: Bool {
        UserDefaults.standard.bool(forKey: "RR_PREVIEW_AUTH_BYPASS")
            || ProcessInfo.processInfo.environment["RR_PREVIEW_AUTH_BYPASS"] == "1"
    }
    #endif

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

        // UI feedback + mock-backed services from the redesign waves
        haptics = HapticsService()
        sounds = SoundService()
        bountyService = MockBountyService()
        dethroneEventService = MockDethroneEventService()
        leaderboardService = MockLeaderboardService()

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
                Task {
                    await self?.refreshUnreadCount()
                    await self?.refreshHUD()
                }
            }
            .store(in: &cancellables)

        // A dethrone anywhere may change our crown count — re-pull the HUD.
        NotificationCenter.default.publisher(for: .kingDethroned)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.refreshHUD() }
            }
            .store(in: &cancellables)
    }

    private func checkAuthState() async {
        #if DEBUG
        guard !isUsingAuthBypass else {
            isLoading = false
            return
        }

        if previewBypassEnabled {
            isLoading = false
            currentUser = User(
                id: "preview-captain",
                username: "Blackbeard",
                avatarURL: nil,
                homeLocation: "San Francisco Bay",
                bio: "Looking for the biggest catch.",
                createdAt: Date()
            )
            isAuthenticated = true
            needsProfileSetup = false
            if let tabRaw = UserDefaults.standard.string(forKey: "RR_PREVIEW_TAB"),
               let tab = AppTab(rawValue: tabRaw) {
                selectedTab = tab
            }
            return
        }
        #endif

        isLoading = true
        defer { isLoading = false }

        do {
            if let user = try await authService.getCurrentUser() {
                currentUser = user
                isAuthenticated = true
                needsProfileSetup = user.username.isEmpty
                // Always land on Home after login.
                selectedTab = .home
                homeNavigationPath = NavigationPath()

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
        async let assignmentsTask = challengeService.assignedCount(for: userId)
        async let seasonTask = seasonService.getActiveSeason()
        async let unreadTask = notificationService.unreadCount(forUser: userId)

        _ = try? await assignmentsTask
        self.activeSeason = try? await seasonTask
        self.unreadNotifications = (try? await unreadTask) ?? 0

        _ = await notificationService.requestAuthorization()

        await refreshHUD()
    }

    /// Pulls fresh unread-notification count for the current user.
    func refreshUnreadCount() async {
        guard let userId = currentUser?.id else { return }
        unreadNotifications = (try? await notificationService.unreadCount(forUser: userId)) ?? 0
    }

    /// Repopulates the persistent identity-header HUD: crowns held, season rank, daily streak.
    /// Best-effort; failures leave previous values intact.
    func refreshHUD() async {
        guard let userId = currentUser?.id else { return }

        async let crownsTask: Int? = (try? await gameService.getCrownCount(for: userId))
        async let rankTask: CaptainRankEntry? = (try? await leaderboardService.fetchUserRank(
            userId: userId,
            scope: .global,
            timeframe: .season
        ))
        async let streakTask: Int = computeDailyStreak(for: userId)

        let (crowns, rank, streak) = await (crownsTask, rankTask, streakTask)

        if let crowns { self.crownsHeld = crowns }
        self.seasonRank = rank?.rank
        self.dailyStreak = streak
    }

    /// Consecutive calendar days, ending today, on which the user logged a public catch.
    /// Stops at the first gap. Capped at 60 days for cheapness.
    private func computeDailyStreak(for userId: String) async -> Int {
        guard let catches = try? await catchRepository.getCatches(forUser: userId) else { return 0 }
        let cal = Calendar.current
        let days: Set<Date> = Set(
            catches
                .filter { $0.isPublic }
                .map { cal.startOfDay(for: $0.createdAt) }
        )
        var streak = 0
        var cursor = cal.startOfDay(for: Date())
        while days.contains(cursor), streak < 60 {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    /// Pulls a fresh user row (useful after a catch or shop purchase).
    func refreshCurrentUser() async {
        guard let userId = currentUser?.id else { return }
        if let updated = try? await userRepository.getUser(byId: userId) {
            currentUser = updated
        }
    }

    private func handleLogout() {
        #if DEBUG
        isUsingAuthBypass = false
        #endif

        isAuthenticated = false
        currentUser = nil
        needsProfileSetup = false
        unreadNotifications = 0
        activeSeason = nil
        crownsHeld = 0
        seasonRank = nil
        dailyStreak = 0

        spotsNavigationPath = NavigationPath()
        communityNavigationPath = NavigationPath()
        profileNavigationPath = NavigationPath()
        homeNavigationPath = NavigationPath()
        fishLogNavigationPath = NavigationPath()
        selectedTab = .home
    }

    func showError(_ message: String) {
        errorMessage = message
        showError = true
    }

    func updateCurrentUser(_ user: User) {
        currentUser = user
        needsProfileSetup = false
    }

    #if DEBUG
    func bypassAuthenticationForDevelopment() {
        isUsingAuthBypass = true
        currentUser = User(
            id: "dev-bypass-user",
            username: "Dev Angler",
            avatarURL: nil,
            homeLocation: "Local Simulator",
            bio: "Temporary development account"
        )
        isAuthenticated = true
        needsProfileSetup = false
        isLoading = false
        selectedTab = .spots
    }
    #endif

    func signOut() async {
        #if DEBUG
        if isUsingAuthBypass {
            handleLogout()
            return
        }
        #endif

        do {
            try await authService.signOut()
            handleLogout()
        } catch {
            showError("Failed to sign out: \(error.localizedDescription)")
        }
    }
}

/// App tabs (4 primary + center FAB action).
enum AppTab: String, CaseIterable, Identifiable {
    case home      = "Home"
    case spots     = "Map"
    case fishLog   = "Log"
    case community = "Community"
    case profile   = "Profile"
    case more      = "More"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home:      return "house.fill"
        case .spots:     return "map.fill"
        case .fishLog:   return "books.vertical.fill"
        case .community: return "person.3.fill"
        case .profile:   return "person.crop.circle.fill"
        case .more:      return "ellipsis.circle.fill"
        }
    }

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
    case codex
    case shop
    case challenges
    case notifications
    case season
}
