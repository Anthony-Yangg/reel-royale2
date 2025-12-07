import Foundation
import CoreLocation
import MapKit
import Combine

/// ViewModel for Spots list/map screen
@MainActor
final class SpotsViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var spots: [SpotWithDetails] = []
    @Published var filteredSpots: [SpotWithDetails] = []
    @Published var selectedSpot: Spot?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // View mode
    @Published var viewMode: ViewMode = .map
    
    // Filters
    @Published var searchQuery = ""
    @Published var selectedWaterType: WaterType?
    @Published var distanceFilter: DistanceFilter = .all
    
    // Map region
    @Published var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )
    
    // User location
    @Published var userLocation: CLLocationCoordinate2D?
    
    // MARK: - Private Properties
    
    private let spotRepository: SpotRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let catchRepository: CatchRepositoryProtocol
    private let territoryRepository: TerritoryRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()
    private static let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    
    // MARK: - Enums
    
    enum ViewMode: String, CaseIterable {
        case map = "Map"
        case list = "List"
        
        var icon: String {
            switch self {
            case .map: return "map.fill"
            case .list: return "list.bullet"
            }
        }
    }
    
    enum DistanceFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case nearby = "Nearby" // < 10km
        case within50km = "< 50 km"
        case within100km = "< 100 km"
        
        var id: String { rawValue }
        
        var maxDistance: Double? {
            switch self {
            case .all: return nil
            case .nearby: return 10_000
            case .within50km: return 50_000
            case .within100km: return 100_000
            }
        }
    }
    
    // MARK: - Initialization
    
    init(
        spotRepository: SpotRepositoryProtocol? = nil,
        userRepository: UserRepositoryProtocol? = nil,
        catchRepository: CatchRepositoryProtocol? = nil,
        territoryRepository: TerritoryRepositoryProtocol? = nil
    ) {
        let previewRepos = Self.previewRepositories()
        self.spotRepository = Self.resolve(
            injected: spotRepository,
            appValue: AppState.shared.spotRepository,
            previewValue: previewRepos?.spotRepository
        )
        self.userRepository = Self.resolve(
            injected: userRepository,
            appValue: AppState.shared.userRepository,
            previewValue: previewRepos?.userRepository
        )
        self.catchRepository = Self.resolve(
            injected: catchRepository,
            appValue: AppState.shared.catchRepository,
            previewValue: previewRepos?.catchRepository
        )
        self.territoryRepository = Self.resolve(
            injected: territoryRepository,
            appValue: AppState.shared.territoryRepository,
            previewValue: previewRepos?.territoryRepository
        )
        
        setupBindings()
    }
    
    private static func resolve<T>(
        injected: T?,
        appValue: T?,
        previewValue: T?
    ) -> T {
        if let injected = injected { return injected }
        if let appValue = appValue { return appValue }
        if let previewValue = previewValue { return previewValue }
        fatalError("Dependencies not configured")
    }
    
    private static func previewRepositories() -> (
        spotRepository: SpotRepositoryProtocol,
        userRepository: UserRepositoryProtocol,
        catchRepository: CatchRepositoryProtocol,
        territoryRepository: TerritoryRepositoryProtocol
    )? {
        #if DEBUG
        guard isPreview else { return nil }
        let dependencies = SpotsPreviewDependencies.make()
        return (
            spotRepository: dependencies.spotRepository,
            userRepository: dependencies.userRepository,
            catchRepository: dependencies.catchRepository,
            territoryRepository: dependencies.territoryRepository
        )
        #else
        return nil
        #endif
    }
    
    private func setupBindings() {
        // Filter spots when search/filter changes
        Publishers.CombineLatest3($searchQuery, $selectedWaterType, $distanceFilter)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] query, waterType, distance in
                self?.applyFilters(query: query, waterType: waterType, distance: distance)
            }
            .store(in: &cancellables)
        
        // Listen for spot updates
        NotificationCenter.default.publisher(for: .spotUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task {
                    await self?.loadSpots()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    
    func loadSpots() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let rawSpots = try await spotRepository.getAllSpots()
            
            // Fetch additional data for each spot
            var spotsWithDetails: [SpotWithDetails] = []
            
            for spot in rawSpots {
                var kingUser: User?
                var bestCatch: FishCatch?
                var territory: Territory?
                var distance: Double?
                
                // Get king user
                if let kingId = spot.currentKingUserId {
                    kingUser = try? await userRepository.getUser(byId: kingId)
                }
                
                // Get best catch
                if let bestCatchId = spot.currentBestCatchId {
                    bestCatch = try? await catchRepository.getCatch(byId: bestCatchId)
                }
                
                // Get territory
                if let territoryId = spot.territoryId {
                    territory = try? await territoryRepository.getTerritory(byId: territoryId)
                }
                
                // Calculate distance from user
                if let userLoc = userLocation {
                    distance = userLoc.distance(to: spot.coordinate)
                }
                
                // Get catch count
                let catches = try? await catchRepository.getCatches(forSpot: spot.id)
                let catchCount = catches?.count ?? 0
                
                spotsWithDetails.append(SpotWithDetails(
                    spot: spot,
                    kingUser: kingUser,
                    bestCatch: bestCatch,
                    territory: territory,
                    distance: distance,
                    catchCount: catchCount
                ))
            }
            
            spots = spotsWithDetails
            applyFilters(query: searchQuery, waterType: selectedWaterType, distance: distanceFilter)
            
            // Update map region to show all spots
            if let firstSpot = spots.first {
                updateMapRegion(center: firstSpot.spot.coordinate)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Filtering
    
    private func applyFilters(query: String, waterType: WaterType?, distance: DistanceFilter) {
        var filtered = spots
        
        // Search filter
        if !query.isEmpty {
            filtered = filtered.filter { spotDetails in
                spotDetails.spot.name.localizedCaseInsensitiveContains(query) ||
                spotDetails.spot.regionName?.localizedCaseInsensitiveContains(query) == true
            }
        }
        
        // Water type filter
        if let waterType = waterType {
            filtered = filtered.filter { $0.spot.waterType == waterType }
        }
        
        // Distance filter
        if let maxDistance = distance.maxDistance {
            filtered = filtered.filter { spotDetails in
                guard let spotDistance = spotDetails.distance else { return true }
                return spotDistance <= maxDistance
            }
        }
        
        // Sort by distance if available
        filteredSpots = filtered.sorted { lhs, rhs in
            guard let lhsDistance = lhs.distance else { return false }
            guard let rhsDistance = rhs.distance else { return true }
            return lhsDistance < rhsDistance
        }
    }
    
    func clearFilters() {
        searchQuery = ""
        selectedWaterType = nil
        distanceFilter = .all
    }
    
    // MARK: - Map
    
    func updateMapRegion(center: CLLocationCoordinate2D) {
        mapRegion = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
    }
    
    func updateUserLocation(_ location: CLLocationCoordinate2D) {
        userLocation = location
        
        // Recalculate distances
        for i in spots.indices {
            let distance = location.distance(to: spots[i].spot.coordinate)
            spots[i] = SpotWithDetails(
                spot: spots[i].spot,
                kingUser: spots[i].kingUser,
                bestCatch: spots[i].bestCatch,
                territory: spots[i].territory,
                distance: distance,
                catchCount: spots[i].catchCount
            )
        }
        
        applyFilters(query: searchQuery, waterType: selectedWaterType, distance: distanceFilter)
    }
    
    func selectSpot(_ spot: Spot) {
        selectedSpot = spot
    }
}

#if DEBUG
private struct SpotsPreviewDependencies {
    let spotRepository: SpotRepositoryProtocol
    let userRepository: UserRepositoryProtocol
    let catchRepository: CatchRepositoryProtocol
    let territoryRepository: TerritoryRepositoryProtocol
    
    static func make() -> SpotsPreviewDependencies {
        let data = SpotsPreviewData.sample
        let spotRepository = MockSpotRepository(spots: data.spots)
        let userRepository = MockUserRepository(users: data.users)
        let catchRepository = MockCatchRepository(catches: data.catches)
        let territoryRepository = MockTerritoryRepository(territories: data.territories)
        return SpotsPreviewDependencies(
            spotRepository: spotRepository,
            userRepository: userRepository,
            catchRepository: catchRepository,
            territoryRepository: territoryRepository
        )
    }
}

private struct SpotsPreviewData {
    let spots: [Spot]
    let users: [User]
    let catches: [FishCatch]
    let territories: [Territory]
    
    static let sample: SpotsPreviewData = {
        let user = User(
            id: "user-preview",
            username: "RiverKing",
            avatarURL: nil,
            homeLocation: "Bay Area",
            bio: "Local angler"
        )
        let spot = Spot(
            name: "Clearwater Lake",
            description: "Crystal clear water with trophy trout.",
            latitude: 37.7749,
            longitude: -122.4194,
            waterType: .lake,
            territoryId: "territory-preview",
            currentKingUserId: user.id,
            currentBestCatchId: "catch-preview",
            currentBestSize: 24,
            currentBestUnit: "in",
            imageURL: nil,
            regionName: "California"
        )
        let fishCatch = FishCatch(
            id: "catch-preview",
            userId: user.id,
            spotId: spot.id,
            photoURL: nil,
            species: "Rainbow Trout",
            sizeValue: 24,
            sizeUnit: "in",
            visibility: .public,
            hideExactLocation: false,
            notes: "Caught near the inlet",
            weatherSnapshot: nil,
            measuredWithAR: false
        )
        let territory = Territory(
            id: "territory-preview",
            name: "Preview Territory",
            description: "Sample region for previews",
            spotIds: [spot.id],
            imageURL: nil,
            regionName: "Northern Bay",
            centerLatitude: spot.latitude,
            centerLongitude: spot.longitude
        )
        return SpotsPreviewData(
            spots: [spot],
            users: [user],
            catches: [fishCatch],
            territories: [territory]
        )
    }()
}

private final class MockSpotRepository: SpotRepositoryProtocol {
    private var spots: [Spot]
    
    init(spots: [Spot]) {
        self.spots = spots
    }
    
    func getAllSpots() async throws -> [Spot] {
        spots
    }
    
    func getSpot(byId id: String) async throws -> Spot? {
        spots.first { $0.id == id }
    }
    
    func getSpots(forTerritory territoryId: String) async throws -> [Spot] {
        spots.filter { $0.territoryId == territoryId }
    }
    
    func getSpots(near coordinate: CLLocationCoordinate2D, radiusMeters: Double) async throws -> [Spot] {
        spots
    }
    
    func getSpots(ofType waterType: WaterType) async throws -> [Spot] {
        spots.filter { $0.waterType == waterType }
    }
    
    func createSpot(_ spot: Spot) async throws -> Spot {
        spot
    }
    
    func updateSpot(_ spot: Spot) async throws {
        if let index = spots.firstIndex(where: { $0.id == spot.id }) {
            spots[index] = spot
        }
    }
    
    func getSpotsRuledBy(userId: String) async throws -> [Spot] {
        spots.filter { $0.currentKingUserId == userId }
    }
    
    func searchSpots(query: String, limit: Int) async throws -> [Spot] {
        Array(spots.filter { $0.name.localizedCaseInsensitiveContains(query) }.prefix(limit))
    }
}

private final class MockUserRepository: UserRepositoryProtocol {
    private var usersById: [String: User]
    
    init(users: [User]) {
        self.usersById = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
    }
    
    func getUser(byId id: String) async throws -> User? {
        usersById[id]
    }
    
    func getUser(byUsername username: String) async throws -> User? {
        usersById.values.first { $0.username == username }
    }
    
    func createUser(_ user: User) async throws {
        usersById[user.id] = user
    }
    
    func updateUser(_ user: User) async throws {
        usersById[user.id] = user
    }
    
    func getAllUsers() async throws -> [User] {
        Array(usersById.values)
    }
    
    func getUsers(byIds ids: [String]) async throws -> [User] {
        ids.compactMap { usersById[$0] }
    }
    
    func searchUsers(query: String, limit: Int) async throws -> [User] {
        let filtered = usersById.values.filter { $0.username.localizedCaseInsensitiveContains(query) }
        return Array(filtered.prefix(limit))
    }
}

private final class MockCatchRepository: CatchRepositoryProtocol {
    private var catches: [FishCatch]
    
    init(catches: [FishCatch]) {
        self.catches = catches
    }
    
    func createCatch(_ fishCatch: FishCatch) async throws -> FishCatch {
        catches.append(fishCatch)
        return fishCatch
    }
    
    func getCatch(byId id: String) async throws -> FishCatch? {
        catches.first { $0.id == id }
    }
    
    func updateCatch(_ fishCatch: FishCatch) async throws {
        if let index = catches.firstIndex(where: { $0.id == fishCatch.id }) {
            catches[index] = fishCatch
        }
    }
    
    func deleteCatch(id: String) async throws {
        catches.removeAll { $0.id == id }
    }
    
    func getCatches(forSpot spotId: String) async throws -> [FishCatch] {
        catches.filter { $0.spotId == spotId }
    }
    
    func getCatches(forUser userId: String) async throws -> [FishCatch] {
        catches.filter { $0.userId == userId }
    }
    
    func getRecentPublicCatches(limit: Int, offset: Int) async throws -> [FishCatch] {
        Array(catches.dropFirst(offset).prefix(limit))
    }
    
    func getBestCatch(forSpot spotId: String) async throws -> FishCatch? {
        catches
            .filter { $0.spotId == spotId }
            .sorted { $0.sizeValue > $1.sizeValue }
            .first
    }
    
    func getPublicCatches(forSpot spotId: String, limit: Int) async throws -> [FishCatch] {
        Array(catches.filter { $0.spotId == spotId }.prefix(limit))
    }
}

private final class MockTerritoryRepository: TerritoryRepositoryProtocol {
    private var territories: [Territory]
    
    init(territories: [Territory]) {
        self.territories = territories
    }
    
    func getAllTerritories() async throws -> [Territory] {
        territories
    }
    
    func getTerritory(byId id: String) async throws -> Territory? {
        territories.first { $0.id == id }
    }
    
    func getTerritory(forSpot spotId: String) async throws -> Territory? {
        territories.first { $0.spotIds.contains(spotId) }
    }
    
    func createTerritory(_ territory: Territory) async throws -> Territory {
        territories.append(territory)
        return territory
    }
    
    func updateTerritory(_ territory: Territory) async throws {
        if let index = territories.firstIndex(where: { $0.id == territory.id }) {
            territories[index] = territory
        }
    }
    
    func addSpot(_ spotId: String, to territoryId: String) async throws {
        if let index = territories.firstIndex(where: { $0.id == territoryId }) {
            if !territories[index].spotIds.contains(spotId) {
                territories[index].spotIds.append(spotId)
            }
        }
    }
    
    func removeSpot(_ spotId: String, from territoryId: String) async throws {
        if let index = territories.firstIndex(where: { $0.id == territoryId }) {
            territories[index].spotIds.removeAll { $0 == spotId }
        }
    }
    
    func searchTerritories(query: String, limit: Int) async throws -> [Territory] {
        Array(territories.filter { $0.name.localizedCaseInsensitiveContains(query) }.prefix(limit))
    }
}
#endif

