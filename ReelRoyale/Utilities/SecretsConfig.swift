import Foundation

/// Centralized accessor for API keys and external service URLs.
///
/// Lookup order (first hit wins):
///   1. ProcessInfo environment variable (great for dev / xcconfig substitution).
///   2. Info.plist key under `ReelRoyaleSecrets` dictionary (great for release).
///   3. Hard-coded fallback in `AppConstants` (placeholder - not for production).
///
/// To configure for production:
///   - Add an `xcconfig` (or use `*.entitlements` / `Info.plist` directly) with:
///       OPENWEATHER_API_KEY = your-key
///       FISH_ID_API_KEY     = your-key
///       FISH_ID_BASE_URL    = https://your-endpoint
///   - Reference these in Info.plist under `ReelRoyaleSecrets`:
///       <key>ReelRoyaleSecrets</key>
///       <dict>
///         <key>OPENWEATHER_API_KEY</key><string>$(OPENWEATHER_API_KEY)</string>
///         <key>FISH_ID_API_KEY</key>    <string>$(FISH_ID_API_KEY)</string>
///         <key>FISH_ID_BASE_URL</key>   <string>$(FISH_ID_BASE_URL)</string>
///       </dict>
///   - Never commit a populated `Secrets.xcconfig`. Use a gitignored override.
enum SecretsConfig {

    /// True iff a production-grade key is configured. UI can show a banner otherwise.
    static var hasOpenWeatherKey: Bool {
        guard let key = openWeatherAPIKey else { return false }
        return !key.isEmpty && !key.lowercased().hasPrefix("your-")
    }

    static var hasFishIDKey: Bool {
        guard let key = fishIDAPIKey else { return false }
        return !key.isEmpty && !key.lowercased().hasPrefix("your-")
    }

    static var openWeatherAPIKey: String? {
        resolve(
            envKey: "OPENWEATHER_API_KEY",
            plistKey: "OPENWEATHER_API_KEY",
            fallback: AppConstants.Weather.apiKey
        )
    }

    static var fishIDAPIKey: String? {
        resolve(
            envKey: "FISH_ID_API_KEY",
            plistKey: "FISH_ID_API_KEY",
            fallback: AppConstants.FishID.apiKey
        )
    }

    static var fishIDBaseURL: String {
        resolve(
            envKey: "FISH_ID_BASE_URL",
            plistKey: "FISH_ID_BASE_URL",
            fallback: AppConstants.FishID.baseURL
        ) ?? AppConstants.FishID.baseURL
    }

    static var openWeatherBaseURL: String {
        resolve(
            envKey: "OPENWEATHER_BASE_URL",
            plistKey: "OPENWEATHER_BASE_URL",
            fallback: AppConstants.Weather.baseURL
        ) ?? AppConstants.Weather.baseURL
    }

    // MARK: - Helpers

    private static func resolve(envKey: String, plistKey: String, fallback: String) -> String? {
        if let env = ProcessInfo.processInfo.environment[envKey], !env.isEmpty {
            return env
        }
        if let secrets = Bundle.main.object(forInfoDictionaryKey: "ReelRoyaleSecrets") as? [String: Any],
           let value = secrets[plistKey] as? String,
           !value.isEmpty,
           !value.contains("$(")
        {
            return value
        }
        return fallback.isEmpty ? nil : fallback
    }
}
