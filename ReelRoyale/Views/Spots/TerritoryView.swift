import SwiftUI

struct TerritoryView: View {
    let territoryId: String
    @State private var territory: TerritoryWithControl?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ScrollView {
            if let territory = territory {
                VStack(spacing: 24) {
                    // Header
                    territoryHeader(territory)
                    
                    // Ruler section
                    rulerSection(territory)
                    
                    // Spots in territory
                    spotsSection(territory)
                    
                    // Crown distribution
                    crownDistribution(territory)
                }
                .padding(.bottom, 32)
            } else if isLoading {
                LoadingView(message: "Loading territory...")
                    .frame(height: 400)
            } else if let error = errorMessage {
                ErrorStateView(message: error) {
                    Task { await loadTerritory() }
                }
            }
        }
        .navigationTitle(territory?.territory.name ?? "Territory")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadTerritory()
        }
    }
    
    @ViewBuilder
    private func territoryHeader(_ territory: TerritoryWithControl) -> some View {
        VStack(spacing: 16) {
            // Territory image or icon
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color.kelp, Color.seafoam],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 150)
                
                VStack {
                    Image(systemName: "flag.2.crossed.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                    
                    Text(territory.territory.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal)
            
            // Stats
            HStack(spacing: 32) {
                statItem(value: "\(territory.totalSpots)", label: "Spots")
                statItem(value: "\(territory.crownCounts.count)", label: "Anglers")
                statItem(value: "\(territory.currentUserCrowns)", label: "Your Crowns")
            }
        }
    }
    
    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.oceanBlue)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private func rulerSection(_ territory: TerritoryWithControl) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Territory Ruler")
                    .font(.headline)
                Spacer()
            }
            
            if let ruler = territory.rulerUser {
                HStack(spacing: 16) {
                    UserAvatarView(user: ruler, size: 60, showCrown: true)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(ruler.username)
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Image(systemName: "flag.fill")
                                .foregroundColor(.kelp)
                        }
                        
                        Text("Controls \(territory.rulerCrownCount) of \(territory.totalSpots) spots")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color.kelp.opacity(0.1))
                .cornerRadius(16)
            } else {
                HStack {
                    Image(systemName: "flag")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading) {
                        Text("No Ruler Yet")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Claim more spots to rule this territory!")
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
    private func spotsSection(_ territory: TerritoryWithControl) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Spots")
                    .font(.headline)
                Spacer()
            }
            
            ForEach(territory.spots) { spot in
                Button {
                    appState.spotsNavigationPath.append(NavigationDestination.spotDetail(spotId: spot.id))
                } label: {
                    HStack {
                        Image(systemName: spot.waterType?.icon ?? "mappin")
                            .foregroundColor(.oceanBlue)
                            .frame(width: 30)
                        
                        Text(spot.name)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if spot.hasKing {
                            CrownBadge(size: .small)
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func crownDistribution(_ territory: TerritoryWithControl) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Crown Distribution")
                    .font(.headline)
                Spacer()
            }
            
            let sortedCounts = territory.crownCounts.sorted { $0.value > $1.value }
            
            if sortedCounts.isEmpty {
                Text("No crowns claimed yet")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(sortedCounts.prefix(5)), id: \.key) { userId, count in
                        CrownDistributionRow(
                            userId: userId,
                            crownCount: count,
                            totalSpots: territory.totalSpots,
                            isRuler: userId == territory.rulerUserId
                        )
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal)
    }
    
    private func loadTerritory() async {
        isLoading = true
        errorMessage = nil
        
        do {
            territory = try await AppState.shared.gameService.getTerritoryControl(territoryId: territoryId)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

struct CrownDistributionRow: View {
    let userId: String
    let crownCount: Int
    let totalSpots: Int
    let isRuler: Bool
    
    @State private var user: User?
    
    var body: some View {
        HStack {
            UserAvatarView(user: user, size: 32)
            
            Text(user?.username ?? "Loading...")
                .font(.subheadline)
            
            if isRuler {
                Image(systemName: "flag.fill")
                    .font(.caption)
                    .foregroundColor(.kelp)
            }
            
            Spacer()
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.crown)
                        .frame(width: geometry.size.width * CGFloat(crownCount) / CGFloat(totalSpots))
                }
            }
            .frame(width: 80, height: 8)
            
            Text("\(crownCount)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.crown)
                .frame(width: 24)
        }
        .task {
            user = try? await AppState.shared.userRepository.getUser(byId: userId)
        }
    }
}

#Preview {
    NavigationStack {
        TerritoryView(territoryId: "test-territory")
            .environmentObject(AppState.shared)
    }
}

