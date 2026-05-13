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
        do {
            guard let modelURL = Bundle.main.urls(forResourcesWithExtension: "mlmodelc", subdirectory: nil)?.first else {
                mlModel = nil
                return
            }
            let model = try MLModel(contentsOf: modelURL)
            mlModel = try VNCoreMLModel(for: model)
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
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw AppError.validationError("Failed to encode image")
        }
        
        guard SecretsConfig.hasFishIDKey else {
            throw AppError.validationError("Fish ID needs a bundled Core ML model or a configured Fish ID API key.")
        }

        guard let url = URL(string: "\(SecretsConfig.fishIDBaseURL)/identify") else {
            throw AppError.networkError("Invalid Fish ID API URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(SecretsConfig.fishIDAPIKey ?? "", forHTTPHeaderField: "Authorization")
        
        let payload: [String: Any] = [
            "image": imageData.base64EncodedString()
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AppError.networkError("Fish ID API request failed")
        }
        
        let apiResult = try JSONDecoder().decode(FishIDAPIResponse.self, from: data)
        
        return FishIDResult(
            species: apiResult.species,
            confidence: apiResult.confidence,
            alternativeSpecies: apiResult.alternatives.map { ($0.species, $0.confidence) },
            timestamp: Date()
        )
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
