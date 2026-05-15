import Foundation
import Combine

/// ViewModel for Profile screen
@MainActor
final class ProfileViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var user: User?
    @Published var stats: UserStats = .empty
    @Published var crownedSpots: [Spot] = []
    @Published var recentCatches: [CatchWithDetails] = []
    @Published var fishMasteryPoints = 0
    @Published var fishLogStatus: FishLogStatus = .beginner
    @Published var topFishMastery: FishMasteryTier = .unranked
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Edit mode
    @Published var isEditing = false
    @Published var editUsername = ""
    @Published var editBio = ""
    @Published var editHomeLocation = ""
    @Published var isSaving = false
    
    // MARK: - Private Properties
    
    private let userId: String?
    private let userRepository: UserRepositoryProtocol
    private let spotRepository: SpotRepositoryProtocol
    private let catchRepository: CatchRepositoryProtocol
    private let gameService: GameServiceProtocol
    private let authService: AuthServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var isCurrentUser: Bool {
        guard let userId = userId else { return true }
        return AppState.shared.currentUser?.id == userId
    }
    
    var displayName: String {
        user?.username ?? "Unknown"
    }
    
    // MARK: - Initialization
    
    init(
        userId: String? = nil,
        userRepository: UserRepositoryProtocol? = nil,
        spotRepository: SpotRepositoryProtocol? = nil,
        catchRepository: CatchRepositoryProtocol? = nil,
        gameService: GameServiceProtocol? = nil,
        authService: AuthServiceProtocol? = nil
    ) {
        self.userId = userId
        self.userRepository = userRepository ?? AppState.shared.userRepository
        self.spotRepository = spotRepository ?? AppState.shared.spotRepository
        self.catchRepository = catchRepository ?? AppState.shared.catchRepository
        self.gameService = gameService ?? AppState.shared.gameService
        self.authService = authService ?? AppState.shared.authService
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Listen for catch creation
        NotificationCenter.default.publisher(for: .catchCreated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let catchUserId = notification.userInfo?["userId"] as? String {
                    let profileUserId = self?.userId ?? AppState.shared.currentUser?.id
                    if catchUserId == profileUserId {
                        Task {
                            await self?.loadProfile()
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    
    func loadProfile() async {
        let targetUserId = userId ?? AppState.shared.currentUser?.id
        guard let targetUserId = targetUserId else {
            errorMessage = "No user to load"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Load user, falling back to AppState's cached user if the repo lookup fails
            // (resilient to network outages when viewing your own profile).
            do {
                user = try await userRepository.getUser(byId: targetUserId)
            } catch {
                if isCurrentUser, let cached = AppState.shared.currentUser, cached.id == targetUserId {
                    user = cached
                } else {
                    throw error
                }
            }

            // Load crowned spots (tolerate failure)
            crownedSpots = (try? await spotRepository.getSpotsRuledBy(userId: targetUserId)) ?? []

            // Load catches (tolerate failure)
            let catches = (try? await catchRepository.getCatches(forUser: targetUserId)) ?? []
            
            // For current user, show all catches; for others, only public
            let visibleCatches = isCurrentUser ? catches : catches.filter { $0.isPublic }
            
            // Enrich with spot data
            recentCatches = await enrichCatches(Array(visibleCatches.prefix(20)))
            
            // Calculate stats
            await calculateStats(
                userId: targetUserId,
                allCatches: catches,
                crownedSpots: crownedSpots
            )
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func enrichCatches(_ catches: [FishCatch]) async -> [CatchWithDetails] {
        var enriched: [CatchWithDetails] = []
        
        for fishCatch in catches {
            let spot = try? await spotRepository.getSpot(byId: fishCatch.spotId)
            let isKing = spot?.currentKingUserId == fishCatch.userId
            
            enriched.append(CatchWithDetails(
                fishCatch: fishCatch,
                user: user,
                spot: spot,
                likeCount: 0, // Not showing likes on profile
                isLikedByCurrentUser: false,
                isCurrentKing: isKing
            ))
        }
        
        return enriched
    }
    
    private func calculateStats(
        userId: String,
        allCatches: [FishCatch],
        crownedSpots: [Spot]
    ) async {
        let publicCatches = allCatches.filter { $0.isPublic }
        
        // Find largest catch
        let sortedBySize = allCatches.sorted { $0.sizeValue > $1.sizeValue }
        let largestCatch = sortedBySize.first
        
        // Find favorite species (most caught)
        let speciesCounts = Dictionary(grouping: allCatches, by: { $0.species })
            .mapValues { $0.count }
        let favoriteSpecies = speciesCounts.max(by: { $0.value < $1.value })?.key
        
        // Count ruled territories
        let territoriesRuled = (try? await gameService.getRuledTerritoriesCount(for: userId)) ?? 0

        // Progression-derived stats
        let releaseCount = allCatches.filter { $0.released }.count
        let codexEntries = (try? await AppState.shared.codexService.getCodex(for: userId)) ?? []
        let speciesDiscovered = codexEntries.filter(\.isDiscovered).count
        fishMasteryPoints = codexEntries.reduce(0) { $0 + $1.masteryPoints }
        fishLogStatus = FishLogStatus.status(for: fishMasteryPoints, discoveredCount: speciesDiscovered)
        topFishMastery = codexEntries
            .map(\.masteryTier)
            .max() ?? .unranked
        let trophyCount = await countTrophies(in: allCatches)

        stats = UserStats(
            totalCatches: allCatches.count,
            publicCatches: publicCatches.count,
            crownedSpots: crownedSpots.count,
            ruledTerritories: territoriesRuled,
            largestCatch: largestCatch?.sizeValue,
            largestCatchUnit: largestCatch?.sizeUnit,
            favoriteSpecies: favoriteSpecies,
            speciesDiscovered: speciesDiscovered,
            releaseCount: releaseCount,
            trophyCount: trophyCount
        )
    }

    /// Count catches whose species is `trophy`-tier in the catalog.
    private func countTrophies(in catches: [FishCatch]) async -> Int {
        guard let codex = AppState.shared.codexService else {
            return 0
        }
        var count = 0
        var cache: [String: FishRarity] = [:]
        for c in catches {
            let key = c.species.lowercased()
            if let r = cache[key] {
                if r == .trophy { count += 1 }
                continue
            }
            let species = try? await codex.resolveSpecies(named: c.species)
            let rarity = species?.rarityTier ?? .common
            cache[key] = rarity
            if rarity == .trophy { count += 1 }
        }
        return count
    }
    
    // MARK: - Editing
    
    func startEditing() {
        guard let user = user else { return }
        editUsername = user.username
        editBio = user.bio ?? ""
        editHomeLocation = user.homeLocation ?? ""
        isEditing = true
    }
    
    func cancelEditing() {
        isEditing = false
    }
    
    func saveProfile() async {
        guard var updatedUser = user else { return }
        
        isSaving = true
        
        do {
            updatedUser.username = editUsername
            updatedUser.bio = editBio.isEmpty ? nil : editBio
            updatedUser.homeLocation = editHomeLocation.isEmpty ? nil : editHomeLocation
            updatedUser.updatedAt = Date()
            
            try await userRepository.updateUser(updatedUser)
            user = updatedUser
            
            if isCurrentUser {
                AppState.shared.updateCurrentUser(updatedUser)
            }
            
            isEditing = false
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isSaving = false
    }
    
    // MARK: - Actions
    
    func signOut() async {
        await AppState.shared.signOut()
    }
    
    func refresh() async {
        await loadProfile()
    }
}
