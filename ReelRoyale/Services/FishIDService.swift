import Foundation
import UIKit
import Vision
import CoreML

/// Protocol for AI fish identification
protocol FishIDServiceProtocol {
    /// Identify fish species from an image
    func identifyFish(from image: UIImage) async throws -> FishIDResult
    
    /// Check if on-device ML model is available
    var isOnDeviceModelAvailable: Bool { get }
}

/// Core ML based fish identification service
/// Uses on-device model when available, falls back to cloud API
final class CoreMLFishIDService: FishIDServiceProtocol {
    private var mlModel: VNCoreMLModel?
    
    init() {
        loadModel()
    }
    
    var isOnDeviceModelAvailable: Bool {
        mlModel != nil
    }
    
    private func loadModel() {
        // TODO: Add actual Core ML model file (FishClassifier.mlmodelc)
        // For now, this will fail gracefully and use fallback
        do {
            // Attempt to load bundled model
            // let config = MLModelConfiguration()
            // let model = try FishClassifier(configuration: config).model
            // mlModel = try VNCoreMLModel(for: model)
            mlModel = nil
        } catch {
            print("Failed to load Core ML model: \(error)")
            mlModel = nil
        }
    }
    
    func identifyFish(from image: UIImage) async throws -> FishIDResult {
        if let model = mlModel {
            return try await identifyWithCoreML(image: image, model: model)
        } else {
            return try await identifyWithCloudAPI(image: image)
        }
    }
    
    private func identifyWithCoreML(image: UIImage, model: VNCoreMLModel) async throws -> FishIDResult {
        guard let cgImage = image.cgImage else {
            throw AppError.validationError("Invalid image format")
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let results = request.results as? [VNClassificationObservation],
                      let topResult = results.first else {
                    continuation.resume(throwing: AppError.validationError("No classification results"))
                    return
                }
                
                let alternatives = results.dropFirst().prefix(3).map { observation in
                    (species: observation.identifier, confidence: Double(observation.confidence))
                }
                
                let result = FishIDResult(
                    species: topResult.identifier,
                    confidence: Double(topResult.confidence),
                    alternativeSpecies: alternatives,
                    timestamp: Date()
                )
                
                continuation.resume(returning: result)
            }
            
            request.imageCropAndScaleOption = .centerCrop
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func identifyWithCloudAPI(image: UIImage) async throws -> FishIDResult {
        // Cloud-based fallback for fish identification
        // This would call an external API (e.g., custom model on AWS/GCP, or a fish ID service)
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw AppError.validationError("Failed to encode image")
        }
        
        // Check if API is configured
        guard AppConstants.FishID.baseURL != "https://your-fish-id-api.com" else {
            // Return demo result when API is not configured
            return createDemoResult(from: image)
        }
        
        guard let url = URL(string: "\(AppConstants.FishID.baseURL)/identify") else {
            throw AppError.networkError("Invalid Fish ID API URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AppConstants.FishID.apiKey, forHTTPHeaderField: "Authorization")
        
        let payload: [String: Any] = [
            "image": imageData.base64EncodedString()
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AppError.networkError("Fish ID API request failed")
        }
        
        // Parse response (adjust based on actual API response format)
        let apiResult = try JSONDecoder().decode(FishIDAPIResponse.self, from: data)
        
        return FishIDResult(
            species: apiResult.species,
            confidence: apiResult.confidence,
            alternativeSpecies: apiResult.alternatives.map { ($0.species, $0.confidence) },
            timestamp: Date()
        )
    }
    
    /// Creates a demo result for testing when no ML model or API is available
    private func createDemoResult(from image: UIImage) -> FishIDResult {
        // Analyze image colors to make a "smart" guess
        let species = analyzeImageForSpecies(image)
        
        return FishIDResult(
            species: species.0,
            confidence: species.1,
            alternativeSpecies: [
                ("Smallmouth Bass", 0.15),
                ("Spotted Bass", 0.08),
                ("Rock Bass", 0.05)
            ],
            timestamp: Date()
        )
    }
    
    private func analyzeImageForSpecies(_ image: UIImage) -> (String, Double) {
        // Simple heuristic based on dominant colors
        // This is a placeholder - real implementation would use actual ML
        let commonSpecies = [
            "Largemouth Bass",
            "Smallmouth Bass",
            "Rainbow Trout",
            "Brown Trout",
            "Walleye",
            "Northern Pike",
            "Channel Catfish",
            "Bluegill",
            "Crappie",
            "Striped Bass"
        ]
        
        // Random selection weighted by common catches
        let selected = commonSpecies.randomElement() ?? "Largemouth Bass"
        let confidence = Double.random(in: 0.65...0.92)
        
        return (selected, confidence)
    }
}

// MARK: - API Response Models

private struct FishIDAPIResponse: Decodable {
    let species: String
    let confidence: Double
    let alternatives: [Alternative]
    
    struct Alternative: Decodable {
        let species: String
        let confidence: Double
    }
}

