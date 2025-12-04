import Foundation
import SwiftUI

/// ViewModel for Fish ID screen
@MainActor
final class FishIDViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var selectedImage: UIImage?
    @Published var identificationResult: FishIDResult?
    @Published var isIdentifying = false
    @Published var showImagePicker = false
    @Published var showCamera = false
    @Published var errorMessage: String?
    @Published var showError = false
    
    // MARK: - Private Properties
    
    private let fishIDService: FishIDServiceProtocol
    
    // MARK: - Computed Properties
    
    var hasResult: Bool {
        identificationResult != nil
    }
    
    var canIdentify: Bool {
        selectedImage != nil && !isIdentifying
    }
    
    var confidenceColor: Color {
        guard let result = identificationResult else { return .gray }
        if result.confidence >= 0.8 {
            return .green
        } else if result.confidence >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
    
    // MARK: - Initialization
    
    init(fishIDService: FishIDServiceProtocol? = nil) {
        self.fishIDService = fishIDService ?? AppState.shared.fishIDService
    }
    
    // MARK: - Actions
    
    func setImage(_ image: UIImage) {
        selectedImage = image
        identificationResult = nil
        showImagePicker = false
        showCamera = false
    }
    
    func identifyFish() async {
        guard let image = selectedImage else {
            showError(message: "Please select an image first")
            return
        }
        
        isIdentifying = true
        identificationResult = nil
        errorMessage = nil
        
        do {
            let result = try await fishIDService.identifyFish(from: image)
            identificationResult = result
        } catch {
            showError(message: "Failed to identify fish: \(error.localizedDescription)")
        }
        
        isIdentifying = false
    }
    
    func reset() {
        selectedImage = nil
        identificationResult = nil
        errorMessage = nil
    }
    
    // MARK: - Helpers
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

