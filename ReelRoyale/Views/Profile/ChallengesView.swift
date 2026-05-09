import SwiftUI

/// Daily + weekly challenge cards. Progress bars where applicable.
/// Completed cards show a checkmark + reward summary.
struct ChallengesView: View {
    @StateObject private var viewModel = ChallengesViewModel()
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.isLoading && viewModel.daily.isEmpty {
                    LoadingView(message: "Loading challenges...")
                        .frame(height: 300)
                } else {
                    section(title: "Daily", subtitle: "Resets at midnight UTC", items: viewModel.daily)
                    section(title: "Weekly", subtitle: "Resets every Monday", items: viewModel.weekly)

                    if viewModel.daily.isEmpty && viewModel.weekly.isEmpty {
                        EmptyStateView(
                            icon: "checkmark.seal",
                            title: "No active challenges",
                            message: "Pull down to refresh or come back tomorrow.",
                            actionTitle: nil,
                            action: nil
                        )
                        .padding(.top, 40)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .navigationTitle("Challenges")
        .navigationBarTitleDisplayMode(.large)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    @ViewBuilder
    private func section(title: String, subtitle: String, items: [UserChallengeWithDetails]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.bold)
                    Spacer()
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 4)

                ForEach(items) { item in
                    ChallengeCard(item: item)
                }
            }
        }
    }
}

private struct ChallengeCard: View {
    let item: UserChallengeWithDetails

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(item.userRecord.completed ? Color.kelp.opacity(0.18) : Color.seafoam.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: item.userRecord.completed ? "checkmark.seal.fill" : "target")
                    .font(.title3)
                    .foregroundColor(item.userRecord.completed ? .kelp : .seafoam)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(item.challenge.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                if let desc = item.challenge.description {
                    Text(desc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 10) {
                    Label("+\(item.challenge.xpReward) XP", systemImage: "bolt.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                    Label("+\(item.challenge.coinReward)", systemImage: "circle.hexagongrid.fill")
                        .font(.caption2)
                        .foregroundColor(.crown)
                }

                progressView
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(item.userRecord.completed ? Color.kelp.opacity(0.4) : Color.clear, lineWidth: 1)
        )
    }

    /// Shows a progress bar when the underlying challenge has a numeric goal.
    /// Returns `EmptyView` for completed/binary challenges.
    @ViewBuilder
    private var progressView: some View {
        if !item.userRecord.completed {
            switch item.challenge.conditionType {
            case .visitNSpots:
                progressBar(current: item.userRecord.progress["spots_visited"]?.intValue ?? 0,
                            target: item.challenge.requiredCount ?? 1)
            case .catchCountInWindow:
                progressBar(current: item.userRecord.progress["catches"]?.intValue ?? 0,
                            target: item.challenge.requiredCount ?? 1)
            case .catchInNTerritories:
                progressBar(current: item.userRecord.progress["territories"]?.intValue ?? 0,
                            target: item.challenge.requiredCount ?? 1)
            case .holdKingNDays:
                progressBar(current: item.userRecord.progress["streak_days"]?.intValue ?? 0,
                            target: item.challenge.requiredHoldDays ?? 1)
            default:
                EmptyView()
            }
        }
    }

    private func progressBar(current: Int, target: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ProgressView(value: Double(current), total: Double(target))
                .tint(.seafoam)
            Text("\(current) / \(target)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

@MainActor
final class ChallengesViewModel: ObservableObject {
    @Published var daily: [UserChallengeWithDetails] = []
    @Published var weekly: [UserChallengeWithDetails] = []
    @Published var isLoading = false

    func load() async {
        guard let userId = AppState.shared.currentUser?.id else { return }
        isLoading = true
        let active = (try? await AppState.shared.challengeService.activeChallenges(for: userId)) ?? []
        daily = active.filter { $0.challenge.type == .daily }
        weekly = active.filter { $0.challenge.type == .weekly }
        isLoading = false
    }
}
