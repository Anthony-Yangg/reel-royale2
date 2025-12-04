import Foundation
import CoreLocation

/// Protocol for weather data operations
protocol WeatherServiceProtocol {
    /// Fetch current weather for coordinates
    func getWeather(latitude: Double, longitude: Double) async throws -> WeatherConditions
    
    /// Fetch current weather for a spot
    func getWeather(for spot: Spot) async throws -> WeatherConditions
}

/// OpenWeatherMap implementation of WeatherService
final class OpenWeatherService: WeatherServiceProtocol {
    private let session: URLSession
    private let decoder: JSONDecoder
    
    // Cache weather data for 10 minutes
    private var cache: [String: (weather: WeatherConditions, fetchedAt: Date)] = [:]
    private let cacheTimeout: TimeInterval = 600
    
    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .secondsSince1970
    }
    
    func getWeather(latitude: Double, longitude: Double) async throws -> WeatherConditions {
        let cacheKey = "\(latitude),\(longitude)"
        
        // Check cache
        if let cached = cache[cacheKey],
           Date().timeIntervalSince(cached.fetchedAt) < cacheTimeout {
            return cached.weather
        }
        
        // Build URL
        var components = URLComponents(string: "\(AppConstants.Weather.baseURL)/weather")!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lon", value: String(longitude)),
            URLQueryItem(name: "appid", value: AppConstants.Weather.apiKey),
            URLQueryItem(name: "units", value: "metric")
        ]
        
        guard let url = components.url else {
            throw AppError.networkError("Invalid URL")
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AppError.networkError("Weather API request failed")
        }
        
        let apiResponse = try decoder.decode(OpenWeatherResponse.self, from: data)
        let weather = mapToWeatherConditions(apiResponse)
        
        // Cache result
        cache[cacheKey] = (weather, Date())
        
        return weather
    }
    
    func getWeather(for spot: Spot) async throws -> WeatherConditions {
        try await getWeather(latitude: spot.latitude, longitude: spot.longitude)
    }
    
    private func mapToWeatherConditions(_ response: OpenWeatherResponse) -> WeatherConditions {
        // Calculate approximate moon phase based on date
        let moonPhase = calculateMoonPhase(for: Date())
        
        return WeatherConditions(
            temperature: response.main.temp,
            temperatureUnit: "C",
            humidity: response.main.humidity,
            pressure: response.main.pressure,
            windSpeed: response.wind.speed,
            windDirection: response.wind.deg ?? 0,
            description: response.weather.first?.description ?? "Unknown",
            icon: mapWeatherIcon(response.weather.first?.icon ?? "01d"),
            moonPhase: moonPhase,
            sunrise: Date(timeIntervalSince1970: TimeInterval(response.sys.sunrise)),
            sunset: Date(timeIntervalSince1970: TimeInterval(response.sys.sunset)),
            fetchedAt: Date()
        )
    }
    
    private func mapWeatherIcon(_ apiIcon: String) -> String {
        switch apiIcon {
        case "01d", "01n": return "sun.max.fill"
        case "02d", "02n": return "cloud.sun.fill"
        case "03d", "03n": return "cloud.fill"
        case "04d", "04n": return "smoke.fill"
        case "09d", "09n": return "cloud.drizzle.fill"
        case "10d", "10n": return "cloud.rain.fill"
        case "11d", "11n": return "cloud.bolt.fill"
        case "13d", "13n": return "cloud.snow.fill"
        case "50d", "50n": return "cloud.fog.fill"
        default: return "questionmark.circle.fill"
        }
    }
    
    private func calculateMoonPhase(for date: Date) -> MoonPhase {
        // Simple moon phase calculation based on synodic month
        let synodicMonth = 29.53058867
        let referenceNewMoon = Date(timeIntervalSince1970: 947182440) // Known new moon: Jan 6, 2000
        
        let daysSinceReference = date.timeIntervalSince(referenceNewMoon) / 86400
        let phase = daysSinceReference.truncatingRemainder(dividingBy: synodicMonth)
        let normalizedPhase = phase / synodicMonth
        
        switch normalizedPhase {
        case 0..<0.0625, 0.9375..<1.0:
            return .newMoon
        case 0.0625..<0.1875:
            return .waxingCrescent
        case 0.1875..<0.3125:
            return .firstQuarter
        case 0.3125..<0.4375:
            return .waxingGibbous
        case 0.4375..<0.5625:
            return .fullMoon
        case 0.5625..<0.6875:
            return .waningGibbous
        case 0.6875..<0.8125:
            return .lastQuarter
        case 0.8125..<0.9375:
            return .waningCrescent
        default:
            return .newMoon
        }
    }
}

// MARK: - OpenWeatherMap API Response Models

private struct OpenWeatherResponse: Decodable {
    let main: MainWeather
    let weather: [WeatherDescription]
    let wind: Wind
    let sys: Sys
    
    struct MainWeather: Decodable {
        let temp: Double
        let humidity: Double
        let pressure: Double
    }
    
    struct WeatherDescription: Decodable {
        let description: String
        let icon: String
    }
    
    struct Wind: Decodable {
        let speed: Double
        let deg: Double?
    }
    
    struct Sys: Decodable {
        let sunrise: Int
        let sunset: Int
    }
}

