import Foundation
import UIKit

protocol FishIDServiceProtocol {
    func identifyFish(from image: UIImage) async throws -> FishIDResult
    var isOnDeviceModelAvailable: Bool { get }
}

final class OpenRouterFishIDService: FishIDServiceProtocol {
    private let session: URLSession
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    var isOnDeviceModelAvailable: Bool {
        false
    }
    
    func identifyFish(from image: UIImage) async throws -> FishIDResult {
        guard let imageData = image.jpegData(compressionQuality: 0.9) else {
            throw AppError.validationError("Failed to encode image")
        }
        
        guard !AppConstants.FishID.apiKey.isEmpty else {
            throw AppError.validationError("Add OPENROUTER_API_KEY to .env")
        }
        
        let request = try buildRequest(imageData: imageData)
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.networkError("Invalid response")
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw AppError.networkError("Fish ID request failed (\(httpResponse.statusCode))")
        }
        
        let content = try extractContent(from: data)
        let parsed = try parseLLMResponse(content)
        
        let species = parsed.species.trimmingCharacters(in: .whitespacesAndNewlines)
        let confidence = clamp(parsed.confidence ?? 0.5)
        let alternatives = parsed.alternatives?.map { alt in
            (species: alt.species.trimmingCharacters(in: .whitespacesAndNewlines), confidence: clamp(alt.confidence ?? 0.3))
        } ?? []
        
        return FishIDResult(
            species: species.isEmpty ? "Unknown" : species,
            confidence: confidence,
            alternativeSpecies: alternatives,
            timestamp: Date()
        )
    }
    
    private func buildRequest(imageData: Data) throws -> URLRequest {
        guard let url = URL(string: "\(AppConstants.FishID.baseURL)/chat/completions") else {
            throw AppError.validationError("Invalid Fish ID URL")
        }
        
        let imageBase64 = imageData.base64EncodedString()
        var body: [String: Any] = [
            "model": AppConstants.FishID.model,
            "messages": [
                [
                    "role": "system",
                    "content": "You are an expert fish species identifier. Return concise JSON."
                ],
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": "Identify the fish species. Respond only with JSON: {\"species\": \"<common name>\", \"confidence\": <0-1>, \"alternatives\": [{\"species\": \"name\", \"confidence\": <0-1>}]}"],
                        ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(imageBase64)"]]
                    ]
                ]
            ],
            "temperature": 0.2,
            "max_tokens": 400
        ]
        
        if #available(iOS 17.0, *), !AppConstants.FishID.model.isEmpty {
            body["response_format"] = ["type": "json_object"]
        }
        
        let bodyData = try JSONSerialization.data(withJSONObject: body)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(AppConstants.FishID.apiKey)", forHTTPHeaderField: "Authorization")
        if !AppConstants.FishID.site.isEmpty {
            request.setValue(AppConstants.FishID.site, forHTTPHeaderField: "X-Title")
        }
        if !AppConstants.FishID.referer.isEmpty {
            request.setValue(AppConstants.FishID.referer, forHTTPHeaderField: "HTTP-Referer")
        }
        return request
    }
    
    private func extractContent(from data: Data) throws -> String {
        let decoder = JSONDecoder()
        let response = try decoder.decode(OpenRouterChatResponse.self, from: data)
        guard let choice = response.choices.first else {
            throw AppError.networkError("Empty response from Fish ID model")
        }
        let content = choice.message.content.stringValue
        guard !content.isEmpty else {
            throw AppError.networkError("No content from Fish ID model")
        }
        return content
    }
    
    private func parseLLMResponse(_ content: String) throws -> ParsedFishIDLLMResponse {
        let cleaned = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = cleaned.data(using: .utf8) else {
            throw AppError.networkError("Unable to read Fish ID response")
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(ParsedFishIDLLMResponse.self, from: data)
    }
    
    private func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
    
    private func createDemoResult(from image: UIImage) -> FishIDResult {
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
        
        let selected = commonSpecies.randomElement() ?? "Largemouth Bass"
        let confidence = Double.random(in: 0.65...0.92)
        
        return (selected, confidence)
    }
}

struct ParsedFishIDLLMResponse: Decodable {
    struct Alternative: Decodable {
        let species: String
        let confidence: Double?
    }
    
    let species: String
    let confidence: Double?
    let alternatives: [Alternative]?
}

struct OpenRouterChatResponse: Decodable {
    struct Choice: Decodable {
        let message: OpenRouterMessage
    }
    
    let choices: [Choice]
}

struct OpenRouterMessage: Decodable {
    let content: OpenRouterMessageContent
}

enum OpenRouterMessageContent: Decodable {
    case string(String)
    case parts([OpenRouterContentPart])
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
            return
        }
        if let parts = try? container.decode([OpenRouterContentPart].self) {
            self = .parts(parts)
            return
        }
        throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported content type"))
    }
    
    var stringValue: String {
        switch self {
        case .string(let string):
            return string
        case .parts(let parts):
            return parts.compactMap { $0.text }.joined(separator: "\n")
        }
    }
}

struct OpenRouterContentPart: Decodable {
    let type: String?
    let text: String?
}

