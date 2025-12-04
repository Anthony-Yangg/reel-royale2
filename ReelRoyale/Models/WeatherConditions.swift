import Foundation

/// Moon phase for fishing conditions
enum MoonPhase: String, Codable, CaseIterable {
    case newMoon = "new_moon"
    case waxingCrescent = "waxing_crescent"
    case firstQuarter = "first_quarter"
    case waxingGibbous = "waxing_gibbous"
    case fullMoon = "full_moon"
    case waningGibbous = "waning_gibbous"
    case lastQuarter = "last_quarter"
    case waningCrescent = "waning_crescent"
    
    var displayName: String {
        switch self {
        case .newMoon: return "New Moon"
        case .waxingCrescent: return "Waxing Crescent"
        case .firstQuarter: return "First Quarter"
        case .waxingGibbous: return "Waxing Gibbous"
        case .fullMoon: return "Full Moon"
        case .waningGibbous: return "Waning Gibbous"
        case .lastQuarter: return "Last Quarter"
        case .waningCrescent: return "Waning Crescent"
        }
    }
    
    var icon: String {
        switch self {
        case .newMoon: return "moon.fill"
        case .waxingCrescent: return "moon.stars.fill"
        case .firstQuarter: return "moon.haze.fill"
        case .waxingGibbous: return "moon.haze.fill"
        case .fullMoon: return "moon.circle.fill"
        case .waningGibbous: return "moon.haze.fill"
        case .lastQuarter: return "moon.haze.fill"
        case .waningCrescent: return "moon.stars.fill"
        }
    }
    
    /// Good fishing phases (fish are more active)
    var isFavorable: Bool {
        switch self {
        case .newMoon, .fullMoon:
            return true
        default:
            return false
        }
    }
}

/// Weather conditions at a fishing spot
struct WeatherConditions: Codable, Equatable {
    let temperature: Double // Celsius
    let temperatureUnit: String
    let humidity: Double // Percentage
    let pressure: Double // hPa
    let windSpeed: Double // m/s
    let windDirection: Double // degrees
    let description: String
    let icon: String
    let moonPhase: MoonPhase
    let sunrise: Date?
    let sunset: Date?
    let fetchedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case temperature
        case temperatureUnit = "temperature_unit"
        case humidity
        case pressure
        case windSpeed = "wind_speed"
        case windDirection = "wind_direction"
        case description
        case icon
        case moonPhase = "moon_phase"
        case sunrise
        case sunset
        case fetchedAt = "fetched_at"
    }
    
    init(
        temperature: Double,
        temperatureUnit: String = "C",
        humidity: Double,
        pressure: Double,
        windSpeed: Double,
        windDirection: Double,
        description: String,
        icon: String,
        moonPhase: MoonPhase,
        sunrise: Date? = nil,
        sunset: Date? = nil,
        fetchedAt: Date = Date()
    ) {
        self.temperature = temperature
        self.temperatureUnit = temperatureUnit
        self.humidity = humidity
        self.pressure = pressure
        self.windSpeed = windSpeed
        self.windDirection = windDirection
        self.description = description
        self.icon = icon
        self.moonPhase = moonPhase
        self.sunrise = sunrise
        self.sunset = sunset
        self.fetchedAt = fetchedAt
    }
    
    var temperatureDisplay: String {
        "\(Int(round(temperature)))°\(temperatureUnit)"
    }
    
    var pressureDisplay: String {
        "\(Int(round(pressure))) hPa"
    }
    
    var windDisplay: String {
        "\(String(format: "%.1f", windSpeed)) m/s"
    }
    
    var humidityDisplay: String {
        "\(Int(round(humidity)))%"
    }
    
    /// Fishing conditions rating based on weather
    var fishingRating: FishingRating {
        // Pressure between 1010-1020 is ideal
        let pressureScore: Double
        if pressure >= 1010 && pressure <= 1020 {
            pressureScore = 1.0
        } else if pressure >= 1000 && pressure <= 1030 {
            pressureScore = 0.7
        } else {
            pressureScore = 0.4
        }
        
        // Wind < 5 m/s is good
        let windScore = windSpeed < 5 ? 1.0 : (windSpeed < 10 ? 0.6 : 0.3)
        
        // Moon phase bonus
        let moonScore = moonPhase.isFavorable ? 1.0 : 0.7
        
        let totalScore = (pressureScore + windScore + moonScore) / 3.0
        
        if totalScore >= 0.8 {
            return .excellent
        } else if totalScore >= 0.6 {
            return .good
        } else if totalScore >= 0.4 {
            return .fair
        } else {
            return .poor
        }
    }
}

/// Overall fishing conditions rating
enum FishingRating: String, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    
    var displayName: String {
        rawValue.capitalized
    }
    
    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "orange"
        case .poor: return "red"
        }
    }
    
    var icon: String {
        switch self {
        case .excellent: return "star.fill"
        case .good: return "hand.thumbsup.fill"
        case .fair: return "hand.raised.fill"
        case .poor: return "hand.thumbsdown.fill"
        }
    }
}

