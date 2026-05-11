import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.reelTheme) private var theme

    @State private var scope: LeaderboardScope = .global
    @State private var timeframe: LeaderboardTimeframe = .season
    @State private var entries: [CaptainRankEntry] = []
    @State private var yourEntry: CaptainRankEntry?
    @State private var isLoading = false

    var body: some View {
        ZStack {
            theme.colors.surface.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                if isLoading && entries.isEmpty {
                    LoadingView(message: "Reading the roster...")
                } else if entries.isEmpty {
                    EmptyStateView(
                        icon: "trophy",
                        title: "No rankings yet",
                        message: "Be the first to claim a spot and appear on the board."
                    )
                } else {
                    ScrollView {
                        VStack(spacing: theme.spacing.m) {
                            podiumIfPresent
                            ranked
                            if let you = yourEntry, !top3Contains(you) {
                                VStack(alignment: .leading, spacing: theme.spacing.xs) {
                                    Text("YOUR POSITION")
                                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                                        .foregroundStyle(theme.colors.brand.brassGold)
                                        .tracking(1.5)
                                    LeaderboardRow(entry: you, isYou: true) {}
                                }
                                .padding(.top, theme.spacing.s)
                            }
                        }
                        .padding(.horizontal, theme.spacing.m)
                        .padding(.vertical, theme.spacing.m)
                        .padding(.bottom, 120)
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
        .refreshable { await load() }
    }

    private var top3: [CaptainRankEntry] { entries.filter { $0.rank <= 3 } }

    private func top3Contains(_ entry: CaptainRankEntry) -> Bool {
        top3.contains(where: { $0.id == entry.id })
    }

    private var header: some View {
        VStack(spacing: theme.spacing.s) {
            HStack {
                Text("Leaderboard")
                    .font(theme.typography.title1)
                    .foregroundStyle(theme.colors.text.primary)
                Spacer()
                Image(systemName: "trophy.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(
                        LinearGradient(colors: [theme.colors.brand.crown, theme.colors.brand.brassGold], startPoint: .top, endPoint: .bottom)
                    )
            }
            HStack(spacing: 6) {
                ForEach(LeaderboardScope.allCases) { s in
                    FilterChip(label: s.rawValue, icon: nil, isSelected: scope == s) {
                        appState.haptics?.tap()
                        scope = s
                        Task { await load() }
                    }
                }
                Spacer()
                Menu {
                    ForEach(LeaderboardTimeframe.allCases) { t in
                        Button(t.rawValue) { timeframe = t; Task { await load() } }
                    }
                } label: {
                    FilterChip(label: timeframe.rawValue, icon: "clock", isSelected: true) {}
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(.horizontal, theme.spacing.m)
        .padding(.vertical, theme.spacing.m)
        .background(theme.colors.surface.canvas)
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.colors.brand.brassGold.opacity(0.18)).frame(height: 0.75)
        }
    }

    @ViewBuilder
    private var podiumIfPresent: some View {
        if top3.count >= 1 {
            PodiumCard(entries: top3, onSelect: { _ in })
                .padding(.top, theme.spacing.s)
                .padding(.bottom, theme.spacing.m)
                .background(
                    RoundedRectangle(cornerRadius: theme.radius.heroCard)
                        .fill(
                            LinearGradient(colors: [theme.colors.brand.deepSea, theme.colors.surface.elevatedAlt], startPoint: .top, endPoint: .bottom)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radius.heroCard)
                        .strokeBorder(theme.colors.brand.brassGold.opacity(0.3), lineWidth: 1)
                )
                .reelShadow(theme.shadow.heroCard)
        }
    }

    private var ranked: some View {
        VStack(spacing: theme.spacing.xs) {
            ForEach(entries.filter { $0.rank > 3 }) { entry in
                LeaderboardRow(entry: entry, isYou: entry.id == appState.currentUser?.id) {}
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            entries = try await appState.leaderboardService.fetchTop(scope: scope, timeframe: timeframe, limit: 50)
            if let uid = appState.currentUser?.id {
                yourEntry = try await appState.leaderboardService.fetchUserRank(userId: uid, scope: scope, timeframe: timeframe)
            }
        } catch {
            // Silently keep mock data on error.
        }
    }
}
