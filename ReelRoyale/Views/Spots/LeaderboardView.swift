import SwiftUI

struct LeaderboardView: View {
    @State private var selectedTab = 0
    @State private var globalLeaderboard: [GlobalLeaderboardEntry] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("Leaderboard Type", selection: $selectedTab) {
                Text("Global").tag(0)
                Text("Crowns").tag(1)
                Text("Territories").tag(2)
            }
            .pickerStyle(.segmented)
            .padding()
            
            if isLoading {
                LoadingView(message: "Loading leaderboard...")
            } else if globalLeaderboard.isEmpty {
                EmptyStateView(
                    icon: "trophy",
                    title: "No Rankings Yet",
                    message: "Be the first to claim a spot and appear on the leaderboard!"
                )
            } else {
                List {
                    ForEach(globalLeaderboard) { entry in
                        GlobalLeaderboardRowView(entry: entry)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Leaderboard")
        .task {
            await loadLeaderboard()
        }
    }
    
    private func loadLeaderboard() async {
        isLoading = true
        do {
            globalLeaderboard = try await AppState.shared.gameService.getGlobalLeaderboard(limit: 50)
        } catch {
            print("Failed to load leaderboard: \(error)")
        }
        isLoading = false
    }
}

struct GlobalLeaderboardRowView: View {
    let entry: GlobalLeaderboardEntry
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank
            ZStack {
                if entry.rank <= 3 {
                    Circle()
                        .fill(rankColor)
                        .frame(width: 40, height: 40)
                    
                    if entry.rank == 1 {
                        CrownBadge(size: .small)
                            .offset(y: -20)
                    }
                }
                
                Text("\(entry.rank)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(entry.rank <= 3 ? .white : .secondary)
            }
            .frame(width: 50)
            
            // User
            UserAvatarView(user: entry.user, size: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.user?.username ?? "Unknown")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.crown)
                        Text("\(entry.crownCount)")
                    }
                    .font(.caption)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "flag.fill")
                            .foregroundColor(.kelp)
                        Text("\(entry.territoriesRuled)")
                    }
                    .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(entry.crownCount)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.crown)
                Text("crowns")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
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
        LeaderboardView()
    }
}

