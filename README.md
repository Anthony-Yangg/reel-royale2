# Reel Royale 🎣👑

A real-world, king-of-the-hill fishing game and companion app for iOS. Users go fishing in real life and log their catches at specific locations. Each spot has a king/queen based on the largest recorded catch, and users compete to claim spots and control territories.

## Features

### Core Gameplay
- **King of the Hill**: Claim spots by logging the largest catch
- **Territory Control**: Dominate regions by ruling multiple spots
- **Leaderboards**: Compete globally and locally
- **Crown System**: Visual badges for rulers

### Fishing Companion
- **Spot Discovery**: Find fishing spots via map or list
- **Catch Logging**: Track all your catches with photos
- **AR Fish Measurement**: Measure fish length using your camera
- **AI Fish ID**: Identify species using AI (structured for Core ML/Cloud integration)
- **Weather Conditions**: Real-time fishing conditions for spots
- **Regulations**: Access to fishing rules (stub implementation)

### Social
- **Community Feed**: See recent public catches
- **Likes**: Appreciate other anglers' catches
- **User Profiles**: View stats, catches, and crowns

### Privacy
- **Visibility Controls**: Public, Friends Only, or Private catches
- **Location Privacy**: Hide exact catch locations

## Architecture

### Tech Stack
- **Platform**: iOS 17+
- **Language**: Swift 5.9+
- **UI**: SwiftUI
- **Backend**: Supabase
- **AR**: ARKit/RealityKit (for fish measurement)
- **ML**: Core ML/Vision (for fish ID)

### Project Structure

```
ReelRoyale/
├── Models/              # Data models
├── Services/            # Business logic & API services
├── Repositories/        # Data access layer
├── ViewModels/          # MVVM view models
├── Views/               # SwiftUI views
│   ├── Auth/            # Authentication screens
│   ├── Spots/           # Spot discovery & details
│   ├── Community/       # Social feed
│   ├── Profile/         # User profile
│   ├── Catch/           # Catch logging & details
│   ├── More/            # Settings & tools
│   └── Components/      # Reusable UI components
├── Utilities/           # Extensions & constants
└── Resources/           # Assets & config
```

### Design Patterns
- **MVVM**: Clear separation of Views, ViewModels, and Models
- **Protocol-Oriented**: All services use protocols for testability
- **Dependency Injection**: Services injected via AppState
- **Repository Pattern**: Data access abstracted from business logic

## Setup

### Prerequisites
- Xcode 15+
- iOS 17+ device or simulator
- Supabase account

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/reel-royale.git
   cd reel-royale
   ```

2. **Open in Xcode**
   ```bash
   open ReelRoyale.xcodeproj
   ```

3. **Set up Supabase**
   - Create a new Supabase project at [supabase.com](https://supabase.com)
   - Run the SQL schema from `supabase-schema.sql` in your Supabase SQL Editor
   - Create storage buckets: `avatars`, `catch-photos`, `spot-images`

4. **Configure the app**
   - Open `ReelRoyale/Utilities/Constants.swift`
   - Replace Supabase credentials:
     ```swift
     enum Supabase {
         static let projectURL = "https://your-project.supabase.co"
         static let anonKey = "your-anon-key"
     }
     ```

5. **Optional: Weather API**
   - Get an API key from [OpenWeatherMap](https://openweathermap.org/api)
   - Update `AppConstants.Weather.apiKey` in `Constants.swift`

6. **Build and run**
   - Select your target device/simulator
   - Press ⌘+R to build and run

### Storage Bucket Setup

In Supabase Dashboard → Storage, create these buckets:

1. **avatars** - User profile pictures
   - Public: Yes
   - File size limit: 5MB
   - Allowed MIME types: image/*

2. **catch-photos** - Catch images
   - Public: Yes
   - File size limit: 10MB
   - Allowed MIME types: image/*

3. **spot-images** - Spot/location images
   - Public: Yes
   - File size limit: 10MB
   - Allowed MIME types: image/*

## Usage

### For Users

1. **Sign Up / Log In**
   - Create an account with email and password
   - Complete your profile setup

2. **Discover Spots**
   - Browse fishing spots on the map or list
   - Filter by water type and distance

3. **Log a Catch**
   - Select or create a spot
   - Add a photo of your catch
   - Measure with AR or enter size manually
   - Use AI Fish ID to identify the species
   - Set privacy preferences
   - Submit to potentially claim the crown!

4. **Compete**
   - Check leaderboards to see top anglers
   - Control territories by ruling multiple spots
   - Track your stats on your profile

### For Developers

#### Adding New Features

1. **New Model**: Add to `Models/`
2. **New Service**: Create protocol in `Services/`, implement with Supabase
3. **New Repository**: Add to `Repositories/`
4. **New Screen**: Create ViewModel in `ViewModels/`, View in `Views/`

#### Testing

The protocol-based architecture makes testing easy:
```swift
// Create mock implementation
class MockSpotRepository: SpotRepositoryProtocol {
    // ... mock implementations
}

// Inject in tests
let viewModel = SpotsViewModel(spotRepository: MockSpotRepository())
```

## API Reference

### Supabase Tables

| Table | Description |
|-------|-------------|
| `profiles` | User profiles (extends auth.users) |
| `spots` | Fishing locations |
| `catches` | Logged catches |
| `territories` | Groups of spots |
| `likes` | Catch appreciation |
| `regulations` | Fishing rules |

### Key Services

| Service | Purpose |
|---------|---------|
| `AuthService` | Authentication |
| `GameService` | King/territory logic |
| `WeatherService` | Weather conditions |
| `FishIDService` | AI species identification |
| `MeasurementService` | AR fish measurement |

## Roadmap

- [ ] Real-time notifications for dethroning
- [ ] Friends system and friend-only visibility
- [ ] Achievements and badges
- [ ] Fishing challenges/tournaments
- [ ] On-device Core ML fish identification
- [ ] Social sharing
- [ ] Apple Watch companion app

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Supabase for the backend infrastructure
- Apple for ARKit and Core ML frameworks
- The fishing community for inspiration

---

Built with 🎣 by fishing enthusiasts, for fishing enthusiasts.

