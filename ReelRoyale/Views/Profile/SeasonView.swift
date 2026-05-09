import SwiftUI

/// Current-season summary + leaderboard. Shows season progress bar, days remaining,
/// and the global top 50 ordered by `season_score`.
struct SeasonView: View {
    @StateObject private var viewModel = SeasonViewModel()
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let season = viewModel.season {
                    seasonHeader(season)
                } else {
                    EmptyStateView(
                        icon: "flag.checkered",
                        title: "No active season",
                        message: "Seasons reset every 30 days. A new one will start soon.",
                        actionTitle: nil,
                        action: nil
                    )
                    .padding(.top, 40)
                }

                if !viewModel.leaderboard.isEmpty {
                    leaderboard
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .navigationTitle("Season")
        .navigationBarTitleDisplayMode(.large)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private func seasonHeader(_ season: Season) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Season \(season.seasonNumber)")
                        .font(.title)
                        .fontWeight(.heavy)
                    Text("\(season.daysRemaining) days remaining")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.85))
                }
                Spacer()
                Image(systemName: "flag.checkered")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }

            ProgressView(value: season.progress)
                .tint(.crown)

            if let rank = viewModel.userRank {
                HStack {
                    Image(systemName: "person.fill")
                    Text("You are #\(rank) globally")
                    Spacer()
                    Text("\(appState.currentUser?.seasonScore ?? 0) pts")
                        .fontWeight(.bold)
                }
                .font(.subheadline)
                .foregroundColor(.white)
                .padding(.top, 4)
            }
        }
        .padding(20)
        .background(LinearGradient(colors: [.deepOcean, .oceanBlue], startPoint: .topLeading, endPoint: .bottomTrailing))
        .cornerRadius(16)
        .foregroundColor(.white)
    }

    private var leaderboard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Leaderboard")
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(viewModel.leaderboard) { entry in
                    HStack(spacing: 12) {
                        Text("#\(entry.rank)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(rankColor(entry.rank))
                            .frame(width: 36, alignment: .leading)

                        UserAvatarView(user: entry.user, size: 36, showCrown: false)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.user.username)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(entry.user.rankTier.rawValue)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(entry.seasonScore)")
                            .font(.headline)
                            .foregroundColor(.crown)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(
                        entry.user.id == appState.currentUser?.id
                            ? Color.seafoam.opacity(0.15)
                            : Color(.systemGray6)
                    )
                    .cornerRadius(12)
                }
            }
        }
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return .crown
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75)
        case 3: return Color(red: 0.80, green: 0.50, blue: 0.20)
        default: return .primary
        }
    }
}

@MainActor
final class SeasonViewModel: ObservableObject {
    @Published var season: Season?
    @Published var leaderboard: [SeasonLeaderboardEntry] = []
    @Published var userRank: Int?
    @Published var isLoading = false

    func load() async {
        isLoading = true
        async let seasonTask = AppState.shared.seasonService.getActiveSeason()
        async let boardTask = AppState.shared.seasonService.getSeasonLeaderboard(limit: 50)

        season = try? await seasonTask
        leaderboard = (try? await boardTask) ?? []

        if let userId = AppState.shared.currentUser?.id {
            userRank = try? await AppState.shared.seasonService.userStanding(userId: userId)
        }
        isLoading = false
    }
}
