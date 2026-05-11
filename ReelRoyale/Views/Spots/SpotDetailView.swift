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
        ZStack(alignment: .bottom) {
            ScrollView {
                if let spot = viewModel.spot {
                    VStack(spacing: 24) {
                        spotHeader(spot)
                        kingSection
                        activityStrip(spot)
                        weatherSection
                        territorySection
                        leaderboardSection
                        Spacer(minLength: 120) // room for sticky CTA
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

            if let spot = viewModel.spot {
                stickyCTA(spot)
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

    /// Always-visible bottom call-to-action. Tone shifts based on king state:
    /// - No king: "Be the first king" (urgency).
    /// - I'm king: "Defend your spot" (different verb).
    /// - Other king: "Take the crown" (challenge).
    @ViewBuilder
    private func stickyCTA(_ spot: Spot) -> some View {
        let title: String = {
            if !spot.hasKing { return "Be the first king" }
            if spot.currentKingUserId == appState.currentUser?.id { return "Defend" }
            return "Take the crown"
        }()
        let gradient = LinearGradient(
            colors: spot.hasKing ? [.coral, .sunset] : [.kelp, .seafoam],
            startPoint: .leading, endPoint: .trailing
        )

        Button {
            appState.spotsNavigationPath.append(NavigationDestination.logCatch(spotId: spot.id))
        } label: {
            HStack {
                Image(systemName: spot.currentKingUserId == appState.currentUser?.id ? "shield.fill" : "crown.fill")
                Text(title)
            }
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(gradient)
            .cornerRadius(28)
            .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    /// Activity strip: total catches, unique anglers, last fished. Drives FOMO.
    private func activityStrip(_ spot: Spot) -> some View {
        HStack(spacing: 12) {
            activityTile(icon: "fish.fill", value: "\(spot.totalCatches)", label: "Catches")
            activityTile(icon: "person.2.fill", value: "\(spot.uniqueAnglers)", label: "Anglers")
            activityTile(
                icon: "clock.fill",
                value: spot.lastCatchAt?.relativeTime ?? "Never",
                label: "Last fish"
            )
        }
        .padding(.horizontal)
    }

    private func activityTile(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundColor(.oceanBlue)
            Text(value).font(.subheadline).fontWeight(.semibold)
            Text(label).font(.caption2).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
    
    @ViewBuilder
    private func spotHeader(_ spot: Spot) -> some View {
        VStack(spacing: 0) {
            // Mini map
            Map(coordinateRegion: .constant(MKCoordinateRegion(
                center: spot.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )), annotationItems: [spot]) { spot in
                MapMarker(coordinate: spot.coordinate, tint: .oceanBlue)
            }
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

                        // Reign duration is the taunt: "held this for 3 days, can you take it?"
                        if let kingSince = viewModel.spot?.kingSince {
                            Label(reignText(since: kingSince), systemImage: "clock.fill")
                                .font(.caption)
                                .foregroundColor(.crown)
                                .fontWeight(.semibold)
                        } else {
                            Text("Caught \(bestCatch.createdAt.relativeTime)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
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
                if let spot = viewModel.spot {
                    NavigationLink(value: NavigationDestination.regulations(spotId: spot.id)) {
                        Label("Rules", systemImage: "doc.text")
                            .font(.caption)
                            .foregroundColor(.oceanBlue)
                    }
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
    
    // Sticky CTA replaces the old primary action. Regulations link kept
    // as a small secondary item under the leaderboard.

    private func reignText(since: Date) -> String {
        let interval = Date().timeIntervalSince(since)
        let days = Int(interval / 86400)
        if days >= 7 { return "Crowned for \(days) days — long live the king" }
        if days >= 1 { return "Crowned for \(days) day\(days == 1 ? "" : "s")" }
        let hours = Int(interval / 3600)
        if hours >= 1 { return "Crowned for \(hours) hour\(hours == 1 ? "" : "s")" }
        return "Just crowned"
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
