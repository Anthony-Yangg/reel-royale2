import Foundation
import SwiftUI
import Combine
import CoreLocation

/// ViewModel for Log Catch flow
@MainActor
final class LogCatchViewModel: ObservableObject {
    // MARK: - Published Properties
    
    // Form fields
    @Published var selectedSpotId: String = ""
    @Published var selectedSpot: Spot?
    @Published var catchPhoto: UIImage?
    @Published var species: String = ""
    @Published var sizeValue: String = ""
    @Published var sizeUnit: SizeUnit = .cm
    @Published var visibility: CatchVisibility = .public
    @Published var hideExactLocation: Bool = false
    @Published var notes: String = ""
    @Published var measuredWithAR: Bool = false
    @Published var catchLocation: CLLocationCoordinate2D?
    
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
    
    // Available spots for ambiguous selection
    @Published var nearbySpots: [Spot] = []
    
    // MARK: - Private Properties
    
    private let preselectedSpotId: String?
    private let spotRepository: SpotRepositoryProtocol
    private let catchRepository: CatchRepositoryProtocol
    private let gameService: GameServiceProtocol
    private let imageUploadService: ImageUploadServiceProtocol
    private let measurementService: MeasurementServiceProtocol
    private let fishIDService: FishIDServiceProtocol
    private let weatherService: WeatherServiceProtocol
    private let spotAssignmentService: SpotAssignmentServiceProtocol
    
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
        weatherService: WeatherServiceProtocol? = nil,
        spotAssignmentService: SpotAssignmentServiceProtocol? = nil
    ) {
        self.preselectedSpotId = preselectedSpotId
        self.spotRepository = spotRepository ?? AppState.shared.spotRepository
        self.catchRepository = catchRepository ?? AppState.shared.catchRepository
        self.gameService = gameService ?? AppState.shared.gameService
        self.imageUploadService = imageUploadService ?? AppState.shared.imageUploadService
        self.measurementService = measurementService ?? AppState.shared.measurementService
        self.fishIDService = fishIDService ?? AppState.shared.fishIDService
        self.weatherService = weatherService ?? AppState.shared.weatherService
        self.spotAssignmentService = spotAssignmentService ?? AppState.shared.spotAssignmentService
        
        if let spotId = preselectedSpotId {
            selectedSpotId = spotId
        }
    }
    
    // MARK: - Loading
    
    func loadInitialData() async {
        isLoading = true
        
        do {
            // Load preselected spot details if exists
            if let spotId = preselectedSpotId {
                selectedSpot = try await spotRepository.getSpot(byId: spotId)
            } else {
                // Try to auto-assign spot based on location if we have one
                // Assuming view will update catchLocation or we request it here
                // For now, let the view trigger updateLocation()
            }
        } catch {
            showError(message: "Failed to load spot: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    func updateLocation(_ location: CLLocationCoordinate2D) async {
        guard catchLocation == nil else { return } // Update only once or on demand
        catchLocation = location
        
        // If spot is locked or already selected, don't auto-assign
        guard !isSpotLocked && selectedSpotId.isEmpty else { return }
        
        let result = await spotAssignmentService.assignSpot(for: location, waterbodyId: nil)
        
        switch result {
        case .assigned(let spot):
            selectedSpot = spot
            selectedSpotId = spot.id
        case .ambiguous(let spots):
            nearbySpots = spots
            showSpotPicker = true
        case .none:
            // No spot found nearby
            // Could prompt user to create one or select manually from wider list
            errorMessage = "No fishing spot detected nearby. Please select one manually."
            showSpotPicker = true // Show all spots or map picker
            // We need to fetch all spots if we want to show a general picker
            if nearbySpots.isEmpty {
                 nearbySpots = (try? await spotRepository.getAllSpots()) ?? []
            }
        }
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
        
        guard let userId = AppState.shared.currentUser?.id else {
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
            // Upload photo if present
            var photoURL: String?
            let catchId = UUID().uuidString
            
            if let photo = catchPhoto {
                photoURL = try await imageUploadService.uploadCatchPhoto(photo, for: catchId)
            }
            
            // Get weather snapshot
            var weatherSnapshot: String?
            if let weather = try? await weatherService.getWeather(for: spot) {
                let encoder = JSONEncoder()
                if let data = try? encoder.encode(weather) {
                    weatherSnapshot = String(data: data, encoding: .utf8)
                }
            }
            
            // Default location if missing (use spot center)
            let lat = catchLocation?.latitude ?? spot.latitude
            let lon = catchLocation?.longitude ?? spot.longitude
            
            // Create catch
            let fishCatch = FishCatch(
                id: catchId,
                userId: userId,
                spotId: selectedSpotId,
                latitude: lat,
                longitude: lon,
                photoURL: photoURL,
                species: species,
                sizeValue: sizeValueDouble,
                sizeUnit: sizeUnit.rawValue,
                visibility: visibility,
                hideExactLocation: hideExactLocation,
                notes: notes.isEmpty ? nil : notes,
                weatherSnapshot: weatherSnapshot,
                measuredWithAR: measuredWithAR
            )
            
            // Save catch
            let savedCatch = try await catchRepository.createCatch(fishCatch)
            
            // Process game logic (king updates)
            let result = try await gameService.processCatch(savedCatch, at: spot)
            catchResult = result
            
            // Notify
            NotificationCenter.default.post(
                name: .catchCreated,
                object: nil,
                userInfo: ["catchId": savedCatch.id, "spotId": savedCatch.spotId ?? ""]
            )
            
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
        sizeValue = ""
        sizeUnit = .cm
        visibility = .public
        hideExactLocation = false
        notes = ""
        measuredWithAR = false
        catchResult = nil
        catchLocation = nil
    }
}
