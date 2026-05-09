import Foundation
import SwiftUI
import Combine

/// ViewModel for Log Catch flow
@MainActor
final class LogCatchViewModel: ObservableObject {
    // MARK: - Published Properties
    
    // Form fields
    @Published var selectedSpotId: String = ""
    @Published var selectedSpot: Spot?
    @Published var catchPhoto: UIImage?
    @Published var species: String = ""
    @Published var speciesId: String?
    @Published var sizeValue: String = ""
    @Published var sizeUnit: SizeUnit = .cm
    @Published var visibility: CatchVisibility = .public
    @Published var hideExactLocation: Bool = false
    @Published var notes: String = ""
    @Published var measuredWithAR: Bool = false
    @Published var releaseFish: Bool = false
    
    // UI State
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var showSpotPicker = false
    @Published var showImagePicker = false
    @Published var showMeasurement = false
    @Published var showFishID = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showSuccess = false
    
    // Result
    @Published var catchResult: CatchResult?
    /// Drives the post-catch celebration `fullScreenCover` (`Identifiable`).
    @Published var celebrationResult: CatchResult?
    
    // Available spots
    @Published var spots: [Spot] = []
    
    // MARK: - Private Properties
    
    private let preselectedSpotId: String?
    private let spotRepository: SpotRepositoryProtocol
    private let catchRepository: CatchRepositoryProtocol
    private let gameService: GameServiceProtocol
    private let imageUploadService: ImageUploadServiceProtocol
    private let measurementService: MeasurementServiceProtocol
    private let fishIDService: FishIDServiceProtocol
    private let weatherService: WeatherServiceProtocol
    
    // MARK: - Computed Properties
    
    var sizeValueDouble: Double {
        Double(sizeValue) ?? 0
    }
    
    var isValid: Bool {
        !selectedSpotId.isEmpty &&
        !species.isEmpty &&
        sizeValueDouble > 0
    }
    
    var isSpotLocked: Bool {
        preselectedSpotId != nil
    }
    
    // MARK: - Initialization
    
    init(
        preselectedSpotId: String? = nil,
        spotRepository: SpotRepositoryProtocol? = nil,
        catchRepository: CatchRepositoryProtocol? = nil,
        gameService: GameServiceProtocol? = nil,
        imageUploadService: ImageUploadServiceProtocol? = nil,
        measurementService: MeasurementServiceProtocol? = nil,
        fishIDService: FishIDServiceProtocol? = nil,
        weatherService: WeatherServiceProtocol? = nil
    ) {
        self.preselectedSpotId = preselectedSpotId
        self.spotRepository = spotRepository ?? AppState.shared.spotRepository
        self.catchRepository = catchRepository ?? AppState.shared.catchRepository
        self.gameService = gameService ?? AppState.shared.gameService
        self.imageUploadService = imageUploadService ?? AppState.shared.imageUploadService
        self.measurementService = measurementService ?? AppState.shared.measurementService
        self.fishIDService = fishIDService ?? AppState.shared.fishIDService
        self.weatherService = weatherService ?? AppState.shared.weatherService
        
        if let spotId = preselectedSpotId {
            selectedSpotId = spotId
        }
    }
    
    // MARK: - Loading
    
    func loadInitialData() async {
        isLoading = true
        
        do {
            // Load all spots for picker
            spots = try await spotRepository.getAllSpots()
            
            // Load preselected spot details
            if let spotId = preselectedSpotId {
                selectedSpot = try await spotRepository.getSpot(byId: spotId)
            }
        } catch {
            showError(message: "Failed to load spots: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    // MARK: - Spot Selection
    
    func selectSpot(_ spot: Spot) {
        selectedSpotId = spot.id
        selectedSpot = spot
        showSpotPicker = false
    }
    
    // MARK: - Photo
    
    func setPhoto(_ image: UIImage) {
        catchPhoto = image
        showImagePicker = false
    }
    
    // MARK: - Measurement
    
    func applyMeasurement(_ lengthInCm: Double) {
        sizeValue = String(format: "%.1f", lengthInCm)
        sizeUnit = .cm
        measuredWithAR = true
        showMeasurement = false
    }
    
    // MARK: - Fish ID
    
    func applyFishIDResult(_ result: FishIDResult) {
        species = result.species
        showFishID = false
    }
    
    func identifyFishFromPhoto() async {
        guard let photo = catchPhoto else {
            showError(message: "Please add a photo first")
            return
        }
        
        do {
            let result = try await fishIDService.identifyFish(from: photo)
            applyFishIDResult(result)
        } catch {
            showError(message: "Fish identification failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Submit
    
    func submitCatch() async {
        guard isValid else {
            if selectedSpotId.isEmpty {
                showError(message: "Please select a fishing spot")
            } else if species.isEmpty {
                showError(message: "Please enter the fish species")
            } else if sizeValueDouble <= 0 {
                showError(message: "Please enter a valid size")
            }
            return
        }

        guard let currentUser = AppState.shared.currentUser else {
            showError(message: "You must be logged in to log a catch")
            return
        }

        // Resolve spot (either already selected or fetched)
        let spot: Spot
        if let currentSpot = selectedSpot {
            spot = currentSpot
        } else {
            do {
                guard let fetched = try await spotRepository.getSpot(byId: selectedSpotId) else {
                    showError(message: "Selected spot not found")
                    return
                }
                spot = fetched
                selectedSpot = fetched
            } catch {
                showError(message: "Failed to load selected spot: \(error.localizedDescription)")
                return
            }
        }

        isSubmitting = true

        do {
            // Upload photo if present (use temp ID; trigger sets server id on insert)
            var photoURL: String?
            let photoStubId = UUID().uuidString

            if let photo = catchPhoto {
                photoURL = try await imageUploadService.uploadCatchPhoto(photo, for: photoStubId)
            }

            // Snapshot weather at the spot
            var weatherSnapshot: String?
            if let weather = try? await weatherService.getWeather(for: spot) {
                let encoder = JSONEncoder()
                if let data = try? encoder.encode(weather) {
                    weatherSnapshot = String(data: data, encoding: .utf8)
                }
            }

            // GameService is now the canonical entry point. It inserts the catch,
            // the SQL trigger awards XP/coins, and the result carries everything
            // the celebration screen needs.
            let input = CreateCatchInput(
                spotId: selectedSpotId,
                photoData: nil,
                species: species,
                speciesId: speciesId,
                sizeValue: sizeValueDouble,
                sizeUnit: sizeUnit.rawValue,
                visibility: visibility,
                hideExactLocation: hideExactLocation,
                notes: notes.isEmpty ? nil : notes,
                measuredWithAR: measuredWithAR,
                released: releaseFish
            )

            let result = try await gameService.processCatch(
                input: input,
                photoURL: photoURL,
                weatherSnapshot: weatherSnapshot,
                currentUser: currentUser
            )
            catchResult = result
            celebrationResult = result

            // Refresh AppState user so XP/coin badges update everywhere.
            await AppState.shared.refreshCurrentUser()
            await AppState.shared.refreshUnreadCount()

            // Surface progression deltas to UI listeners (e.g. coin/XP popovers).
            if result.xpAwarded > 0 {
                NotificationCenter.default.post(
                    name: .xpAwarded,
                    object: nil,
                    userInfo: ["amount": result.xpAwarded]
                )
            }
            if result.coinsAwarded > 0 {
                NotificationCenter.default.post(
                    name: .coinsAwarded,
                    object: nil,
                    userInfo: ["amount": result.coinsAwarded]
                )
            }
            if result.leveledUp {
                NotificationCenter.default.post(
                    name: .rankedUp,
                    object: nil,
                    userInfo: ["from": result.oldRank.rawValue, "to": result.newRank.rawValue]
                )
            }
            for completed in result.completedChallenges {
                NotificationCenter.default.post(
                    name: .challengeCompleted,
                    object: nil,
                    userInfo: [
                        "challengeId": completed.id,
                        "title": completed.title,
                        "xp": completed.xpReward,
                        "coins": completed.coinReward
                    ]
                )
            }

            showSuccess = true

        } catch {
            showError(message: "Failed to save catch: \(error.localizedDescription)")
        }

        isSubmitting = false
    }
    
    // MARK: - Helpers
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
    
    func reset() {
        if !isSpotLocked {
            selectedSpotId = ""
            selectedSpot = nil
        }
        catchPhoto = nil
        species = ""
        speciesId = nil
        sizeValue = ""
        sizeUnit = .cm
        visibility = .public
        hideExactLocation = false
        notes = ""
        measuredWithAR = false
        releaseFish = false
        catchResult = nil
    }
}

