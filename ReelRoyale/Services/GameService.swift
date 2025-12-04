import Foundation

/// Protocol for king-of-the-hill game logic
protocol GameServiceProtocol {
    /// Process a new catch and update king/territory status
    func processCatch(_ fishCatch: FishCatch, at spot: Spot) async throws -> CatchResult
    
    /// Get current king for a spot
    func getKing(for spotId: String) async throws -> User?
    
    /// Get leaderboard for a spot
    func getSpotLeaderboard(spotId: String, limit: Int) async throws -> [LeaderboardEntry]
    
    /// Get territory control info
    func getTerritoryControl(territoryId: String) async throws -> TerritoryWithControl
    
    /// Get global leaderboard (by number of crowns)
    func getGlobalLeaderboard(limit: Int) async throws -> [GlobalLeaderboardEntry]
    
    /// Get user's crown count
    func getCrownCount(for userId: String) async throws -> Int
    
    /// Get user's ruled territories count
    func getRuledTerritoriesCount(for userId: String) async throws -> Int
}

/// Result of processing a catch
struct CatchResult: Equatable {
    let fishCatch: FishCatch
    let isNewKing: Bool
    let previousKingId: String?
    let territoryControlChanged: Bool
    let newTerritoryRulerId: String?
    
    static func regular(_ fishCatch: FishCatch) -> CatchResult {
        CatchResult(
            fishCatch: fishCatch,
            isNewKing: false,
            previousKingId: nil,
            territoryControlChanged: false,
            newTerritoryRulerId: nil
        )
    }
}

/// Spot leaderboard entry
struct LeaderboardEntry: Identifiable, Equatable {
    let rank: Int
    let userId: String
    let user: User?
    let fishCatch: FishCatch
    let isCurrentKing: Bool
    
    var id: String { "\(rank)-\(userId)" }
}

/// Global leaderboard entry (by crown count)
struct GlobalLeaderboardEntry: Identifiable, Equatable {
    let rank: Int
    let userId: String
    let user: User?
    let crownCount: Int
    let territoriesRuled: Int
    let totalCatchSize: Double
    
    var id: String { "\(rank)-\(userId)" }
}

/// Implementation of game service
final class GameService: GameServiceProtocol {
    private let spotRepository: SpotRepositoryProtocol
    private let catchRepository: CatchRepositoryProtocol
    private let territoryRepository: TerritoryRepositoryProtocol
    
    init(
        spotRepository: SpotRepositoryProtocol,
        catchRepository: CatchRepositoryProtocol,
        territoryRepository: TerritoryRepositoryProtocol
    ) {
        self.spotRepository = spotRepository
        self.catchRepository = catchRepository
        self.territoryRepository = territoryRepository
    }
    
    func processCatch(_ fishCatch: FishCatch, at spot: Spot) async throws -> CatchResult {
        // Only public catches can claim king status
        guard fishCatch.isPublic else {
            return .regular(fishCatch)
        }
        
        var updatedSpot = spot
        let previousKingId = spot.currentKingUserId
        var isNewKing = false
        var territoryControlChanged = false
        var newTerritoryRulerId: String?
        
        // Check if this catch beats the current best
        let currentBestSize = spot.currentBestSize ?? 0
        let newSize = fishCatch.normalizedSizeInCm
        
        if newSize > currentBestSize + AppConstants.Game.minimumSizeDifferenceToWin {
            // New king!
            isNewKing = true
            updatedSpot.currentKingUserId = fishCatch.userId
            updatedSpot.currentBestCatchId = fishCatch.id
            updatedSpot.currentBestSize = fishCatch.sizeValue
            updatedSpot.currentBestUnit = fishCatch.sizeUnit
            updatedSpot.updatedAt = Date()
            
            try await spotRepository.updateSpot(updatedSpot)
            
            // Check if territory control changed
            if let territoryId = spot.territoryId {
                let territoryControl = try await getTerritoryControl(territoryId: territoryId)
                
                // If the new ruler is different from before, territory control changed
                if territoryControl.rulerUserId != previousKingId {
                    territoryControlChanged = true
                    newTerritoryRulerId = territoryControl.rulerUserId
                }
            }
            
            // Post notification
            if isNewKing && previousKingId != nil && previousKingId != fishCatch.userId {
                NotificationCenter.default.post(
                    name: .kingDethroned,
                    object: nil,
                    userInfo: [
                        "spotId": spot.id,
                        "newKingId": fishCatch.userId,
                        "previousKingId": previousKingId as Any
                    ]
                )
            }
        }
        
        return CatchResult(
            fishCatch: fishCatch,
            isNewKing: isNewKing,
            previousKingId: previousKingId,
            territoryControlChanged: territoryControlChanged,
            newTerritoryRulerId: newTerritoryRulerId
        )
    }
    
    func getKing(for spotId: String) async throws -> User? {
        guard let spot = try await spotRepository.getSpot(byId: spotId),
              let kingId = spot.currentKingUserId else {
            return nil
        }
        
        return try await AppState.shared.userRepository.getUser(byId: kingId)
    }
    
    func getSpotLeaderboard(spotId: String, limit: Int = 10) async throws -> [LeaderboardEntry] {
        let catches = try await catchRepository.getCatches(forSpot: spotId)
        let spot = try await spotRepository.getSpot(byId: spotId)
        
        // Filter to public catches only
        let publicCatches = catches.filter { $0.isPublic }
        
        // Group by user and get best catch per user
        // Design decision: Show only best catch per user on leaderboard
        var bestCatchByUser: [String: FishCatch] = [:]
        for fishCatch in publicCatches {
            if let existing = bestCatchByUser[fishCatch.userId] {
                if fishCatch.normalizedSizeInCm > existing.normalizedSizeInCm {
                    bestCatchByUser[fishCatch.userId] = fishCatch
                }
            } else {
                bestCatchByUser[fishCatch.userId] = fishCatch
            }
        }
        
        // Sort by size descending
        let sortedCatches = bestCatchByUser.values.sorted {
            $0.normalizedSizeInCm > $1.normalizedSizeInCm
        }
        
        // Build leaderboard entries
        var entries: [LeaderboardEntry] = []
        for (index, fishCatch) in sortedCatches.prefix(limit).enumerated() {
            let user = try await AppState.shared.userRepository.getUser(byId: fishCatch.userId)
            entries.append(LeaderboardEntry(
                rank: index + 1,
                userId: fishCatch.userId,
                user: user,
                fishCatch: fishCatch,
                isCurrentKing: fishCatch.userId == spot?.currentKingUserId
            ))
        }
        
        return entries
    }
    
    func getTerritoryControl(territoryId: String) async throws -> TerritoryWithControl {
        guard let territory = try await territoryRepository.getTerritory(byId: territoryId) else {
            throw AppError.notFound("Territory")
        }
        
        // Get all spots in this territory
        let spots = try await spotRepository.getSpots(forTerritory: territoryId)
        
        // Get all catches for these spots (for tiebreaker calculation)
        var allCatches: [FishCatch] = []
        for spot in spots {
            let catches = try await catchRepository.getCatches(forSpot: spot.id)
            allCatches.append(contentsOf: catches)
        }
        
        // Calculate ruler
        let (rulerId, crownCounts) = TerritoryWithControl.calculateRuler(
            spots: spots,
            catches: allCatches
        )
        
        // Get ruler user info
        var rulerUser: User?
        if let rulerId = rulerId {
            rulerUser = try await AppState.shared.userRepository.getUser(byId: rulerId)
        }
        
        // Get current user's crown count in this territory
        let currentUserId = await AppState.shared.supabaseService.currentUserId ?? ""
        let currentUserCrowns = crownCounts[currentUserId] ?? 0
        
        return TerritoryWithControl(
            territory: territory,
            spots: spots,
            rulerUserId: rulerId,
            rulerUser: rulerUser,
            crownCounts: crownCounts,
            currentUserCrowns: currentUserCrowns
        )
    }
    
    func getGlobalLeaderboard(limit: Int = 20) async throws -> [GlobalLeaderboardEntry] {
        // Get all spots with kings
        let allSpots = try await spotRepository.getAllSpots()
        
        // Count crowns per user
        var crownCounts: [String: Int] = [:]
        var totalSizes: [String: Double] = [:]
        
        for spot in allSpots {
            if let kingId = spot.currentKingUserId {
                crownCounts[kingId, default: 0] += 1
                if let size = spot.currentBestSize {
                    totalSizes[kingId, default: 0] += size
                }
            }
        }
        
        // Get all territories and count territories ruled per user
        let territories = try await territoryRepository.getAllTerritories()
        var territoriesRuled: [String: Int] = [:]
        
        for territory in territories {
            let spots = allSpots.filter { $0.territoryId == territory.id }
            let (rulerId, _) = TerritoryWithControl.calculateRuler(spots: spots, catches: [])
            if let rulerId = rulerId {
                territoriesRuled[rulerId, default: 0] += 1
            }
        }
        
        // Sort users by crown count
        let sortedUsers = crownCounts.sorted { lhs, rhs in
            if lhs.value != rhs.value {
                return lhs.value > rhs.value
            }
            return (totalSizes[lhs.key] ?? 0) > (totalSizes[rhs.key] ?? 0)
        }
        
        // Build entries
        var entries: [GlobalLeaderboardEntry] = []
        for (index, (userId, crowns)) in sortedUsers.prefix(limit).enumerated() {
            let user = try await AppState.shared.userRepository.getUser(byId: userId)
            entries.append(GlobalLeaderboardEntry(
                rank: index + 1,
                userId: userId,
                user: user,
                crownCount: crowns,
                territoriesRuled: territoriesRuled[userId] ?? 0,
                totalCatchSize: totalSizes[userId] ?? 0
            ))
        }
        
        return entries
    }
    
    func getCrownCount(for userId: String) async throws -> Int {
        let spots = try await spotRepository.getAllSpots()
        return spots.filter { $0.currentKingUserId == userId }.count
    }
    
    func getRuledTerritoriesCount(for userId: String) async throws -> Int {
        let territories = try await territoryRepository.getAllTerritories()
        let spots = try await spotRepository.getAllSpots()
        
        var count = 0
        for territory in territories {
            let territorySpots = spots.filter { $0.territoryId == territory.id }
            let (rulerId, _) = TerritoryWithControl.calculateRuler(spots: territorySpots, catches: [])
            if rulerId == userId {
                count += 1
            }
        }
        
        return count
    }
}

