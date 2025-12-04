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
        self.spotRepository = spotRepository ?? AppState.shared.spotRepository
        self.userRepository = userRepository ?? AppState.shared.userRepository
        self.catchRepository = catchRepository ?? AppState.shared.catchRepository
        self.territoryRepository = territoryRepository ?? AppState.shared.territoryRepository
        
        setupBindings()
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

