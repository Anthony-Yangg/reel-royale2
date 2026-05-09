import Foundation

/// Protocol for king-of-the-hill game logic + progression rewards.
///
/// `processCatch` is the canonical post-catch entry point. It:
///  1. Inserts the catch (Postgres trigger populates xp/coins/dethrone).
///  2. Reads back the enriched row + updated spot.
///  3. Predicts the same numbers client-side as a sanity check.
///  4. Runs challenge evaluation against the catch.
///  5. Returns a `CatchResult` with everything UI needs for the post-catch screen.
protocol GameServiceProtocol {
    /// Persist a new catch + apply all progression rules. Returns the result.
    func processCatch(
        input: CreateCatchInput,
        photoURL: String?,
        weatherSnapshot: String?,
        currentUser: User
    ) async throws -> CatchResult

    /// Get current king for a spot.
    func getKing(for spotId: String) async throws -> User?

    /// Get leaderboard for a spot.
    func getSpotLeaderboard(spotId: String, limit: Int) async throws -> [LeaderboardEntry]

    /// Get territory control info.
    func getTerritoryControl(territoryId: String) async throws -> TerritoryWithControl

    /// Get global leaderboard (by lifetime XP).
    func getGlobalLeaderboard(limit: Int) async throws -> [GlobalLeaderboardEntry]

    /// Get user's crown count.
    func getCrownCount(for userId: String) async throws -> Int

    /// Get user's ruled territories count.
    func getRuledTerritoriesCount(for userId: String) async throws -> Int
}

/// Result of processing a catch. Passed to the celebration UI.
struct CatchResult: Identifiable, Equatable {
    let fishCatch: FishCatch
    let updatedUser: User?
    let isNewKing: Bool
    let previousKingId: String?
    let territoryControlChanged: Bool
    let newTerritoryRulerId: String?
    let xpAwarded: Int
    let coinsAwarded: Int
    let xpBreakdown: XPBreakdown
    let oldRank: RankTier
    let newRank: RankTier
    let leveledUp: Bool
    let xpToNextRank: Int?
    let firstSpeciesEver: Bool
    let completedChallenges: [Challenge]

    var id: String { fishCatch.id }

    static func regular(_ fishCatch: FishCatch, user: User?) -> CatchResult {
        let rank = user?.rankTier ?? .minnow
        return CatchResult(
            fishCatch: fishCatch,
            updatedUser: user,
            isNewKing: false,
            previousKingId: nil,
            territoryControlChanged: false,
            newTerritoryRulerId: nil,
            xpAwarded: 0,
            coinsAwarded: 0,
            xpBreakdown: .zero,
            oldRank: rank,
            newRank: rank,
            leveledUp: false,
            xpToNextRank: rank.xpToNext(currentXP: user?.xp ?? 0),
            firstSpeciesEver: false,
            completedChallenges: []
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

/// Global leaderboard entry (by lifetime XP).
struct GlobalLeaderboardEntry: Identifiable, Equatable {
    let rank: Int
    let userId: String
    let user: User?
    let xp: Int
    let rankTier: RankTier
    let crownCount: Int
    let territoriesRuled: Int

    var id: String { "\(rank)-\(userId)" }
}

/// Implementation of game service
final class GameService: GameServiceProtocol {
    private let spotRepository: SpotRepositoryProtocol
    private let catchRepository: CatchRepositoryProtocol
    private let territoryRepository: TerritoryRepositoryProtocol
    private let userRepository: UserRepositoryProtocol
    private let speciesRepository: SpeciesRepositoryProtocol?
    private let challengeService: ChallengeServiceProtocol?

    init(
        spotRepository: SpotRepositoryProtocol,
        catchRepository: CatchRepositoryProtocol,
        territoryRepository: TerritoryRepositoryProtocol,
        userRepository: UserRepositoryProtocol,
        speciesRepository: SpeciesRepositoryProtocol? = nil,
        challengeService: ChallengeServiceProtocol? = nil
    ) {
        self.spotRepository = spotRepository
        self.catchRepository = catchRepository
        self.territoryRepository = territoryRepository
        self.userRepository = userRepository
        self.speciesRepository = speciesRepository
        self.challengeService = challengeService
    }

    func processCatch(
        input: CreateCatchInput,
        photoURL: String?,
        weatherSnapshot: String?,
        currentUser: User
    ) async throws -> CatchResult {
        // Resolve species from catalog (best-effort).
        var species: Species? = nil
        if let repo = speciesRepository {
            if let id = input.speciesId {
                species = try? await repo.getSpecies(byId: id)
            }
            if species == nil {
                species = try? await repo.getSpecies(byName: input.species)
            }
        }

        // Read pre-state needed for client prediction + challenge context.
        async let preSpotTask = spotRepository.getSpot(byId: input.spotId)
        async let userCatchesTask = catchRepository.getCatches(forUser: currentUser.id)
        let (preSpot, userCatches) = try await (preSpotTask, userCatchesTask)

        let normalizedNewSize: Double = {
            switch input.sizeUnit.lowercased() {
            case "in", "inches": return input.sizeValue * 2.54
            default: return input.sizeValue
            }
        }()
        let isNewKingPredicted = (preSpot?.currentBestSize ?? 0) + AppConstants.Game.minimumSizeDifferenceToWin < normalizedNewSize
        let dethroningPrediction = isNewKingPredicted
            && (preSpot?.currentKingUserId != nil)
            && (preSpot?.currentKingUserId != currentUser.id)
        let firstSpeciesPrediction = !userCatches.contains {
            $0.species.lowercased() == input.species.lowercased()
        }

        // Build the catch row. xp_awarded / coins_awarded set by the trigger.
        let now = Date()
        let row = FishCatch(
            userId: currentUser.id,
            spotId: input.spotId,
            photoURL: photoURL,
            species: input.species,
            speciesId: species?.id ?? input.speciesId,
            sizeValue: input.sizeValue,
            sizeUnit: input.sizeUnit,
            visibility: input.visibility,
            hideExactLocation: input.hideExactLocation,
            notes: input.notes,
            weatherSnapshot: weatherSnapshot,
            measuredWithAR: input.measuredWithAR,
            released: input.released,
            createdAt: now
        )

        // INSERT triggers update_spot_king() server-side. Returning row carries
        // xp_awarded, coins_awarded, dethroned_user_id, season_id.
        let inserted = try await catchRepository.createCatch(row)
        let isNewKing = (inserted.dethronedUserId != nil) || ((preSpot?.currentBestSize ?? 0) < inserted.sizeValue)
        let previousKingId = inserted.dethronedUserId ?? preSpot?.currentKingUserId

        // Refresh spot + user state.
        async let updatedSpotTask = spotRepository.getSpot(byId: input.spotId)
        async let updatedUserTask = userRepository.getUser(byId: currentUser.id)
        let (updatedSpot, refreshedUser) = try await (updatedSpotTask, updatedUserTask)

        // Territory ruler change?
        var territoryControlChanged = false
        var newTerritoryRulerId: String?
        if isNewKing, let territoryId = updatedSpot?.territoryId {
            let control = try? await getTerritoryControl(territoryId: territoryId)
            if let control, control.rulerUserId != previousKingId {
                territoryControlChanged = true
                newTerritoryRulerId = control.rulerUserId
            }
        }

        // Client-side breakdown for celebration UI.
        let breakdown = XPCalculator.compute(input: XPInput(
            weightKg: XPCalculator.weightKg(sizeValue: inserted.sizeValue, sizeUnit: inserted.sizeUnit),
            sizeUnit: inserted.sizeUnit,
            species: species,
            isReleased: inserted.released,
            isDethrone: dethroningPrediction,
            previouslyHeldKing: preSpot?.currentKingUserId == currentUser.id,
            firstSpeciesForUser: firstSpeciesPrediction,
            firstCatchOfDay: isFirstCatchOfDay(in: userCatches, on: now),
            firstCatchInTerritory: isFirstCatchInTerritory(territoryId: updatedSpot?.territoryId, in: userCatches),
            isPublic: inserted.isPublic
        ))

        // Rank delta
        let oldRank = currentUser.rankTier
        let newRank = refreshedUser?.rankTier ?? RankTier.from(xp: currentUser.xp + inserted.xpAwarded)
        let leveledUp = newRank > oldRank
        let xpToNext = newRank.xpToNext(currentXP: refreshedUser?.xp ?? (currentUser.xp + inserted.xpAwarded))

        // Run challenges (best-effort).
        var completedChallenges: [Challenge] = []
        if let challengeService, inserted.isPublic, let updatedSpot {
            do {
                let context = ChallengeContext(
                    userId: currentUser.id,
                    now: now,
                    fishCatch: inserted,
                    spot: updatedSpot,
                    isNewKing: isNewKing,
                    distinctSpotsToday: distinctSpots(in: userCatches, on: now) + 1,
                    distinctTerritoriesThisWeek: distinctTerritories(in: userCatches, currentTerritory: updatedSpot.territoryId, in: 7),
                    catchesInLast7Days: catchesInLast(days: 7, in: userCatches) + 1,
                    longestActiveKingStreakDays: 0,
                    isFirstSpecies: firstSpeciesPrediction
                )
                let result = try await challengeService.evaluate(context)
                completedChallenges = result.completed
            } catch {
                #if DEBUG
                print("ChallengeService.evaluate failed: \(error)")
                #endif
            }
        }

        // Local broadcast for in-app listeners (profile, feed, etc.)
        NotificationCenter.default.post(
            name: .catchCreated,
            object: nil,
            userInfo: ["userId": currentUser.id, "catchId": inserted.id]
        )
        if isNewKing, let prev = previousKingId, prev != currentUser.id {
            NotificationCenter.default.post(
                name: .kingDethroned,
                object: nil,
                userInfo: [
                    "spotId": inserted.spotId,
                    "newKingId": currentUser.id,
                    "previousKingId": prev
                ]
            )
        }

        return CatchResult(
            fishCatch: inserted,
            updatedUser: refreshedUser,
            isNewKing: isNewKing,
            previousKingId: previousKingId,
            territoryControlChanged: territoryControlChanged,
            newTerritoryRulerId: newTerritoryRulerId,
            xpAwarded: inserted.xpAwarded,
            coinsAwarded: inserted.coinsAwarded,
            xpBreakdown: breakdown,
            oldRank: oldRank,
            newRank: newRank,
            leveledUp: leveledUp,
            xpToNextRank: xpToNext,
            firstSpeciesEver: firstSpeciesPrediction,
            completedChallenges: completedChallenges
        )
    }

    func getKing(for spotId: String) async throws -> User? {
        guard let spot = try await spotRepository.getSpot(byId: spotId),
              let kingId = spot.currentKingUserId else {
            return nil
        }
        return try await userRepository.getUser(byId: kingId)
    }

    func getSpotLeaderboard(spotId: String, limit: Int = 10) async throws -> [LeaderboardEntry] {
        let catches = try await catchRepository.getCatches(forSpot: spotId)
        let spot = try await spotRepository.getSpot(byId: spotId)
        let publicCatches = catches.filter { $0.isPublic }

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
        let sortedCatches = bestCatchByUser.values.sorted {
            $0.normalizedSizeInCm > $1.normalizedSizeInCm
        }

        var entries: [LeaderboardEntry] = []
        for (index, fishCatch) in sortedCatches.prefix(limit).enumerated() {
            let user = try await userRepository.getUser(byId: fishCatch.userId)
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
        let spots = try await spotRepository.getSpots(forTerritory: territoryId)
        var allCatches: [FishCatch] = []
        for spot in spots {
            let catches = try await catchRepository.getCatches(forSpot: spot.id)
            allCatches.append(contentsOf: catches)
        }
        let (rulerId, crownCounts) = TerritoryWithControl.calculateRuler(
            spots: spots,
            catches: allCatches
        )
        var rulerUser: User?
        if let rulerId {
            rulerUser = try await userRepository.getUser(byId: rulerId)
        }
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
        let topUsers = try await userRepository.getTopUsersByXP(limit: limit)
        let allSpots = try await spotRepository.getAllSpots()
        let territories = try await territoryRepository.getAllTerritories()

        var crownCounts: [String: Int] = [:]
        for spot in allSpots {
            if let kingId = spot.currentKingUserId {
                crownCounts[kingId, default: 0] += 1
            }
        }

        var territoriesRuled: [String: Int] = [:]
        for territory in territories {
            let spots = allSpots.filter { $0.territoryId == territory.id }
            let (rulerId, _) = TerritoryWithControl.calculateRuler(spots: spots, catches: [])
            if let rulerId = rulerId {
                territoriesRuled[rulerId, default: 0] += 1
            }
        }

        return topUsers.enumerated().map { idx, user in
            GlobalLeaderboardEntry(
                rank: idx + 1,
                userId: user.id,
                user: user,
                xp: user.xp,
                rankTier: user.rankTier,
                crownCount: crownCounts[user.id] ?? 0,
                territoriesRuled: territoriesRuled[user.id] ?? 0
            )
        }
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
            if rulerId == userId { count += 1 }
        }
        return count
    }

    // MARK: - Helpers

    private func isFirstCatchOfDay(in catches: [FishCatch], on day: Date) -> Bool {
        let cal = Calendar.current
        return !catches.contains { cal.isDate($0.createdAt, inSameDayAs: day) }
    }

    private func isFirstCatchInTerritory(territoryId: String?, in catches: [FishCatch]) -> Bool {
        guard let territoryId, !territoryId.isEmpty else { return false }
        // Without catches.territory_id we cannot answer this exactly client-side;
        // server-side trigger is authoritative. Conservative answer: false.
        return false
    }

    private func distinctSpots(in catches: [FishCatch], on day: Date) -> Int {
        let cal = Calendar.current
        let today = catches.filter { cal.isDate($0.createdAt, inSameDayAs: day) }
        return Set(today.map { $0.spotId }).count
    }

    private func distinctTerritories(in catches: [FishCatch], currentTerritory: String?, in days: Int) -> Int {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        let recent = catches.filter { $0.createdAt >= cutoff }
        let baseline = Set(recent.map { $0.spotId }).count
        if let currentTerritory, !currentTerritory.isEmpty { return max(1, baseline) }
        return baseline
    }

    private func catchesInLast(days: Int, in catches: [FishCatch]) -> Int {
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)
        return catches.filter { $0.createdAt >= cutoff }.count
    }
}
