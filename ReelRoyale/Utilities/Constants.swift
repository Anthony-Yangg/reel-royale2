import Foundation
import SwiftUI

/// App-wide constants and configuration
enum AppConstants {
    /// Supabase configuration
    /// IMPORTANT: Replace these with your actual Supabase project credentials
    enum Supabase {
        static let projectURL = "https://dtteukpeqgnfaccwjxme.supabase.co"
        static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR0dGV1a3BlcWduZmFjY3dqeG1lIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5Mzg0MjcsImV4cCI6MjA4MDUxNDQyN30.1BCEAsWBfgNlCej9vk2-foATxSFkiQTqwixNbKfxt-E"
        
        /// Storage bucket names
        enum Buckets {
            static let avatars = "avatars"
            static let catchPhotos = "catch-photos"
            static let spotImages = "spot-images"
        }
        
        /// Table names
        enum Tables {
            static let profiles = "profiles"
            static let spots = "spots"
            static let catches = "catches"
            static let territories = "territories"
            static let likes = "likes"
            static let regulations = "regulations"
        }
    }
    
    /// OpenWeatherMap API configuration
    enum Weather {
        static let apiKey = "your-openweathermap-api-key"
        static let baseURL = "https://api.openweathermap.org/data/2.5"
    }
    
    enum Mapbox {
        static let accessToken = "pk.eyJ1IjoibWFwYm94dXNlcjQyIiwiYSI6ImNtaXY4ZG1pdjF1angzZXB3ajhlZzhwd2wifQ.A8FaAx4KAAwpbC83uClcZA"
    }
    
    /// AI Fish ID configuration (for future cloud ML endpoint)
    enum FishID {
        static let baseURL = "https://your-fish-id-api.com"
        static let apiKey = "your-fish-id-api-key"
    }
    
    /// App UI constants - Cartoonish game style
    enum UI {
        static let cornerRadius: CGFloat = 16
        static let cardCornerRadius: CGFloat = 20
        static let pillCornerRadius: CGFloat = 24
        static let buttonCornerRadius: CGFloat = 28
        static let smallCornerRadius: CGFloat = 12
        static let padding: CGFloat = 16
        static let smallPadding: CGFloat = 8
        static let avatarSize: CGFloat = 44
        static let largeAvatarSize: CGFloat = 80
        static let thumbnailSize: CGFloat = 60
        static let iconSize: CGFloat = 24
        
        /// Shadow values for playful depth
        static let cardShadowRadius: CGFloat = 8
        static let cardShadowY: CGFloat = 4
        static let cardShadowOpacity: Double = 0.12
        
        /// Animation durations - bouncy feel
        static let quickAnimation: Double = 0.2
        static let standardAnimation: Double = 0.35
        static let slowAnimation: Double = 0.5
        static let bouncyAnimation: Double = 0.6
    }
    
    /// Game mechanics constants
    enum Game {
        /// Minimum difference in size (cm) to dethrone current king
        static let minimumSizeDifferenceToWin: Double = 0.1
        
        /// Minimum spots to control for territory ruler
        static let minimumSpotsForTerritoryControl: Int = 1
    }
    
    /// Feed and pagination
    enum Feed {
        static let pageSize: Int = 20
        static let maxCacheAge: TimeInterval = 300 // 5 minutes
    }
}

/// App color palette - Dark Blue Cartoonish Game Theme
extension Color {
    // Primary - Dark Navy Blue (game-like feel)
    static let navyPrimary = Color(red: 0.10, green: 0.23, blue: 0.36)     // #1A3A5C
    static let navyLight = Color(red: 0.18, green: 0.35, blue: 0.52)       // Lighter navy
    static let navyDark = Color(red: 0.05, green: 0.12, blue: 0.20)        // Darker navy
    
    // Playful Accent Colors
    static let coralAccent = Color(red: 1.0, green: 0.45, blue: 0.35)      // Bright coral CTA
    static let aquaHighlight = Color(red: 0.30, green: 0.85, blue: 0.80)   // Aqua/seafoam
    static let sunnyYellow = Color(red: 1.0, green: 0.82, blue: 0.30)      // Golden/crown
    static let mintGreen = Color(red: 0.40, green: 0.85, blue: 0.55)       // Success green
    
    // Background & Cards
    static let creamBackground = Color(red: 0.98, green: 0.96, blue: 0.93)
    static let cardWhite = Color.white
    
    // Legacy aliases for backwards compatibility
    static let deepOcean = navyDark
    static let oceanBlue = navyPrimary
    static let seafoam = aquaHighlight
    static let coral = coralAccent
    static let sunset = sunnyYellow
    static let sand = creamBackground
    static let driftwood = Color(red: 0.55, green: 0.45, blue: 0.35)
    static let kelp = mintGreen
    static let crown = sunnyYellow
}

/// Common fish species for picker
enum CommonFishSpecies: String, CaseIterable {
    case largemouthBass = "Largemouth Bass"
    case smallmouthBass = "Smallmouth Bass"
    case stripedBass = "Striped Bass"
    case rainbowTrout = "Rainbow Trout"
    case brownTrout = "Brown Trout"
    case brookTrout = "Brook Trout"
    case walleye = "Walleye"
    case northernPike = "Northern Pike"
    case muskellunge = "Muskellunge"
    case channelCatfish = "Channel Catfish"
    case bluegill = "Bluegill"
    case crappie = "Crappie"
    case perch = "Yellow Perch"
    case carp = "Common Carp"
    case salmon = "Salmon"
    case steelhead = "Steelhead"
    case redfish = "Redfish"
    case snook = "Snook"
    case tarpon = "Tarpon"
    case bonefish = "Bonefish"
    case flounder = "Flounder"
    case halibut = "Halibut"
    case other = "Other"
}

