import Foundation
import Combine

/// ViewModel for Spot Detail screen
@MainActor
final class SpotDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var spot: Spot?
    @Published var kingUser: User?
    @Published var bestCatch: FishCatch?
    @Published var territory: TerritoryWithControl?
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var weather: WeatherConditions?
    @Published var isLoading = false
    @Published var isLoadingWeather = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    
    private let spotId: String
    private let spotRepository: SpotRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let catchRepository: CatchRepositoryProtocol
    private let gameService: GameServiceProtocol
    private let weatherService: WeatherServiceProtocol
    private let territoryRepository: TerritoryRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var currentUserId: String? {
        AppState.shared.currentUser?.id
    }
    
    var isCurrentUserKing: Bool {
        guard let userId = currentUserId else { return false }
        return spot?.currentKingUserId == userId
    }
    
    var territoryRulerDisplay: String {
        guard let territory = territory else { return "No territory" }
        if let ruler = territory.rulerUser {
            return "\(ruler.username) rules \(territory.territory.name)"
        }
        return "\(territory.territory.name) - No ruler yet"
    }
    
    var userTerritoryProgress: String {
        guard let territory = territory else { return "" }
        return "You control \(territory.currentUserCrowns)/\(territory.totalSpots) spots"
    }
    
    // MARK: - Initialization
    
    init(
        spotId: String,
        spotRepository: SpotRepositoryProtocol? = nil,
        userRepository: UserRepositoryProtocol? = nil,
        catchRepository: CatchRepositoryProtocol? = nil,
        gameService: GameServiceProtocol? = nil,
        weatherService: WeatherServiceProtocol? = nil,
        territoryRepository: TerritoryRepositoryProtocol? = nil
    ) {
        self.spotId = spotId
        self.spotRepository = spotRepository ?? AppState.shared.spotRepository
        self.userRepository = userRepository ?? AppState.shared.userRepository
        self.catchRepository = catchRepository ?? AppState.shared.catchRepository
        self.gameService = gameService ?? AppState.shared.gameService
        self.weatherService = weatherService ?? AppState.shared.weatherService
        self.territoryRepository = territoryRepository ?? AppState.shared.territoryRepository
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Listen for catch creation
        NotificationCenter.default.publisher(for: .catchCreated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let catchSpotId = notification.userInfo?["spotId"] as? String,
                   catchSpotId == self?.spotId {
                    Task {
                        await self?.loadSpotDetails()
                    }
                }
            }
            .store(in: &cancellables)
        
        // Listen for king dethroned
        NotificationCenter.default.publisher(for: .kingDethroned)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let dethronedSpotId = notification.userInfo?["spotId"] as? String,
                   dethronedSpotId == self?.spotId {
                    Task {
                        await self?.loadSpotDetails()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    
    func loadSpotDetails() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load spot
            guard let loadedSpot = try await spotRepository.getSpot(byId: spotId) else {
                errorMessage = "Spot not found"
                isLoading = false
                return
            }
            spot = loadedSpot
            
            // Load king user
            if let kingId = loadedSpot.currentKingUserId {
                kingUser = try await userRepository.getUser(byId: kingId)
            }
            
            // Load best catch
            if let catchId = loadedSpot.currentBestCatchId {
                bestCatch = try await catchRepository.getCatch(byId: catchId)
            }
            
            // Load leaderboard
            leaderboard = try await gameService.getSpotLeaderboard(spotId: spotId, limit: 10)
            
            // Load territory info
            if let territoryId = loadedSpot.territoryId {
                territory = try await gameService.getTerritoryControl(territoryId: territoryId)
            }
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
        
        // Load weather separately (non-blocking)
        await loadWeather()
    }
    
    func loadWeather() async {
        guard let spot = spot else { return }
        
        isLoadingWeather = true
        
        do {
            weather = try await weatherService.getWeather(for: spot)
        } catch {
            print("Failed to load weather: \(error)")
            // Don't show error for weather - it's not critical
        }
        
        isLoadingWeather = false
    }
    
    func refreshData() async {
        await loadSpotDetails()
    }
}

