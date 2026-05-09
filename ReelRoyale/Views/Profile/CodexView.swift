import SwiftUI

/// Player's species codex (Pokemon-style discovery grid).
/// Discovered species show full color + stats. Locked entries show silhouette + "???".
struct CodexView: View {
    @StateObject private var viewModel = CodexViewModel()
    @EnvironmentObject var appState: AppState

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                discoveryHeader
                    .padding(.horizontal)

                if viewModel.isLoading && viewModel.entries.isEmpty {
                    LoadingView(message: "Loading codex...")
                        .frame(height: 300)
                } else if viewModel.entries.isEmpty {
                    EmptyStateView(
                        icon: "books.vertical.fill",
                        title: "No species yet",
                        message: "Catch your first fish to start filling out your codex.",
                        actionTitle: "Start fishing",
                        action: { appState.selectedTab = .spots }
                    )
                    .padding(.top, 60)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(viewModel.entries) { entry in
                            CodexCard(entry: entry)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 32)
        }
        .navigationTitle("Codex")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private var discoveryHeader: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(viewModel.discoveredCount) of \(viewModel.totalCount)")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Species discovered")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.seafoam)
            }
            ProgressView(value: viewModel.progress)
                .tint(.seafoam)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

private struct CodexCard: View {
    let entry: CodexEntry

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(rarityGradient)
                    .frame(height: 90)

                Image(systemName: "fish.fill")
                    .font(.system(size: 40))
                    .foregroundColor(entry.isDiscovered ? .white : .white.opacity(0.25))

                if !entry.isDiscovered {
                    Image(systemName: "lock.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(6)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }

            VStack(spacing: 2) {
                Text(entry.isDiscovered ? entry.species.displayName : "???")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .foregroundColor(.primary)

                Text(entry.species.rarityTier.displayName)
                    .font(.caption2)
                    .foregroundColor(rarityColor)
                    .textCase(.uppercase)

                if let pb = entry.personalBestDisplay {
                    Text("PB \(pb)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        .opacity(entry.isDiscovered ? 1.0 : 0.65)
    }

    private var rarityColor: Color {
        switch entry.species.rarityTier {
        case .common:   return .gray
        case .uncommon: return .seafoam
        case .rare:     return .oceanBlue
        case .trophy:   return .crown
        }
    }

    private var rarityGradient: LinearGradient {
        let base = rarityColor
        return LinearGradient(
            colors: [base, base.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

@MainActor
final class CodexViewModel: ObservableObject {
    @Published var entries: [CodexEntry] = []
    @Published var isLoading = false

    var discoveredCount: Int { entries.filter(\.isDiscovered).count }
    var totalCount: Int { entries.count }
    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(discoveredCount) / Double(totalCount)
    }

    func load() async {
        guard let userId = AppState.shared.currentUser?.id else { return }
        isLoading = true
        entries = (try? await AppState.shared.codexService.getCodex(for: userId)) ?? []
        isLoading = false
    }
}
