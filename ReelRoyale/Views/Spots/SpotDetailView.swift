import SwiftUI
import MapKit

struct SpotDetailView: View {
    let spotId: String
    @StateObject private var viewModel: SpotDetailViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    init(spotId: String) {
        self.spotId = spotId
        _viewModel = StateObject(wrappedValue: SpotDetailViewModel(spotId: spotId))
    }
    
    var body: some View {
        ScrollView {
            if let spot = viewModel.spot {
                VStack(spacing: 24) {
                    // Header with map
                    spotHeader(spot)
                    
                    // King section
                    kingSection
                    
                    // Weather section
                    weatherSection
                    
                    // Territory section
                    territorySection
                    
                    // Leaderboard
                    leaderboardSection
                    
                    // Actions
                    actionButtons(spot)
                    
                    Spacer(minLength: 32)
                }
            } else if viewModel.isLoading {
                LoadingView(message: "Loading spot details...")
                    .frame(height: 400)
            } else if let error = viewModel.errorMessage {
                ErrorStateView(message: error) {
                    Task { await viewModel.loadSpotDetails() }
                }
            }
        }
        .navigationTitle(viewModel.spot?.name ?? "Spot Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadSpotDetails()
        }
        .refreshable {
            await viewModel.refreshData()
        }
    }
    
    @ViewBuilder
    private func spotHeader(_ spot: Spot) -> some View {
        VStack(spacing: 0) {
            MapboxSpotsView(
                spots: [
                    SpotWithDetails(
                        spot: spot,
                        kingUser: viewModel.kingUser,
                        bestCatch: viewModel.bestCatch,
                        territory: viewModel.territory?.territory,
                        distance: nil,
                        catchCount: viewModel.leaderboard.count
                    )
                ],
                selectedSpot: .constant(nil),
                region: .constant(MKCoordinateRegion(
                    center: spot.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
            )
            .frame(height: 200)
            .allowsHitTesting(false)
            
            // Spot info
            VStack(spacing: 12) {
                HStack {
                    if let type = spot.waterType {
                        Label(type.displayName, systemImage: type.icon)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.oceanBlue)
                            .cornerRadius(12)
                    }
                    
                    Spacer()
                    
                    Text(spot.formattedCoordinates)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let description = spot.description {
                    Text(description)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
    
    @ViewBuilder
    private var kingSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Current Ruler")
                    .font(.headline)
                Spacer()
            }
            
            if let king = viewModel.kingUser, let bestCatch = viewModel.bestCatch {
                HStack(spacing: 16) {
                    UserAvatarView(user: king, size: 60, showCrown: true)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(king.username)
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            CrownBadge(size: .small, isAnimated: viewModel.isCurrentUserKing)
                        }
                        
                        Text("\(bestCatch.species) - \(bestCatch.sizeDisplay)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Caught \(bestCatch.createdAt.relativeTime)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if let photoURL = bestCatch.photoURL {
                        CatchThumbnail(photoURL: photoURL, size: 60)
                    }
                }
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.crown.opacity(0.1), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(16)
            } else {
                HStack {
                    Image(systemName: "crown")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading) {
                        Text("No King Yet")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Be the first to claim this spot!")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var weatherSection: some View {
        if let weather = viewModel.weather {
            VStack(spacing: 12) {
                HStack {
                    Text("Conditions")
                        .font(.headline)
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: weather.fishingRating.icon)
                        Text(weather.fishingRating.displayName)
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(ratingColor(weather.fishingRating))
                    .cornerRadius(12)
                }
                
                HStack(spacing: 20) {
                    weatherItem(icon: weather.icon, title: weather.temperatureDisplay, subtitle: weather.description)
                    weatherItem(icon: "gauge", title: weather.pressureDisplay, subtitle: "Pressure")
                    weatherItem(icon: "wind", title: weather.windDisplay, subtitle: "Wind")
                    weatherItem(icon: weather.moonPhase.icon, title: weather.moonPhase.displayName, subtitle: "Moon")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding(.horizontal)
        } else if viewModel.isLoadingWeather {
            HStack {
                ProgressView()
                Text("Loading weather...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
    
    private func weatherItem(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.oceanBlue)
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func ratingColor(_ rating: FishingRating) -> Color {
        switch rating {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .orange
        case .poor: return .red
        }
    }
    
    @ViewBuilder
    private var territorySection: some View {
        if let territory = viewModel.territory {
            VStack(spacing: 12) {
                HStack {
                    Text("Territory")
                        .font(.headline)
                    Spacer()
                }
                
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "flag.fill")
                            .foregroundColor(.kelp)
                        Text(territory.territory.name)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    
                    HStack {
                        if let ruler = territory.rulerUser {
                            Text("Ruled by \(ruler.username)")
                                .foregroundColor(.secondary)
                        } else {
                            Text("No ruler yet")
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        TerritoryRulerBadge(
                            spotCount: territory.currentUserCrowns,
                            totalSpots: territory.totalSpots
                        )
                    }
                    .font(.subheadline)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private var leaderboardSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Leaderboard")
                    .font(.headline)
                Spacer()
                
                NavigationLink(value: NavigationDestination.leaderboard) {
                    Text("See All")
                        .font(.caption)
                        .foregroundColor(.oceanBlue)
                }
            }
            
            if viewModel.leaderboard.isEmpty {
                Text("No catches yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.leaderboard.prefix(5)) { entry in
                        LeaderboardRowView(entry: entry)
                        
                        if entry.id != viewModel.leaderboard.prefix(5).last?.id {
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                }
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func actionButtons(_ spot: Spot) -> some View {
        VStack(spacing: 12) {
            Button {
                appState.spotsNavigationPath.append(NavigationDestination.logCatch(spotId: spot.id))
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Log a Catch")
                }
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.coralAccent, Color.sunnyYellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: Color.coralAccent.opacity(0.4), radius: 8, x: 0, y: 4)
                )
            }
            
            Button {
                appState.spotsNavigationPath.append(NavigationDestination.regulations(spotId: spot.id))
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                    Text("View Regulations")
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.navyPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(Color.navyPrimary.opacity(0.1))
                )
            }
        }
        .padding(.horizontal)
    }
}

struct LeaderboardRowView: View {
    let entry: LeaderboardEntry
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank
            ZStack {
                if entry.rank <= 3 {
                    Circle()
                        .fill(rankColor)
                        .frame(width: 32, height: 32)
                }
                Text("\(entry.rank)")
                    .font(.headline)
                    .foregroundColor(entry.rank <= 3 ? .white : .secondary)
            }
            .frame(width: 40)
            
            // User
            UserAvatarView(user: entry.user, size: 36, showCrown: entry.isCurrentKing)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.user?.username ?? "Unknown")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(entry.fishCatch.species)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(entry.fishCatch.sizeDisplay)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.oceanBlue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private var rankColor: Color {
        switch entry.rank {
        case 1: return .crown
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return .clear
        }
    }
}

#Preview {
    NavigationStack {
        SpotDetailView(spotId: "test-spot")
            .environmentObject(AppState.shared)
    }
}

