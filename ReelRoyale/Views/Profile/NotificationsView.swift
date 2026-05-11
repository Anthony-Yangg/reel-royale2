import SwiftUI

/// In-app notification inbox. Tap routes to the relevant spot or feature.
struct NotificationsView: View {
    @StateObject private var viewModel = NotificationsViewModel()
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.items.isEmpty {
                LoadingView(message: "Loading notifications...")
            } else if viewModel.items.isEmpty {
                EmptyStateView(
                    icon: "bell.slash",
                    title: "All caught up",
                    message: "No new notifications. Catch fish to stir the leaderboard.",
                    actionTitle: "Browse spots",
                    action: { appState.selectedTab = .spots }
                )
            } else {
                List {
                    ForEach(viewModel.items) { item in
                        Button { handleTap(item) } label: {
                            NotificationRow(item: item)
                        }
                        .listRowBackground(item.read ? Color(.systemBackground) : Color.seafoam.opacity(0.05))
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !viewModel.items.allSatisfy(\.read) {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Mark all read") {
                        Task { await viewModel.markAllRead() }
                    }
                }
            }
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private func handleTap(_ item: AppNotification) {
        Task {
            try? await AppState.shared.notificationService.markRead(id: item.id)
            await viewModel.load()
            await AppState.shared.refreshUnreadCount()
        }
        if let spotId = item.spotId {
            appState.profileNavigationPath.append(NavigationDestination.spotDetail(spotId: spotId))
        }
    }
}

private struct NotificationRow: View {
    let item: AppNotification

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.18))
                    .frame(width: 40, height: 40)
                Image(systemName: item.type.icon)
                    .foregroundColor(iconColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(item.read ? .regular : .semibold)
                    Spacer()
                    Text(item.createdAt.relativeTime)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if let body = item.body {
                    Text(body)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var iconColor: Color {
        switch item.type {
        case .dethroned, .crownTaken: return .coral
        case .defended:               return .seafoam
        case .challengeComplete:      return .kelp
        case .seasonEnd:              return .crown
        case .rankUp:                 return .crown
        case .streakBonus:            return .coral
        case .newTerritory:           return .oceanBlue
        }
    }
}

@MainActor
final class NotificationsViewModel: ObservableObject {
    @Published var items: [AppNotification] = []
    @Published var isLoading = false

    func load() async {
        guard let userId = AppState.shared.currentUser?.id else { return }
        isLoading = true
        items = (try? await AppState.shared.notificationService.getRecent(forUser: userId, limit: 50)) ?? []
        isLoading = false
    }

    func markAllRead() async {
        guard let userId = AppState.shared.currentUser?.id else { return }
        try? await AppState.shared.notificationService.markAllRead(forUser: userId)
        await load()
        await AppState.shared.refreshUnreadCount()
    }
}
