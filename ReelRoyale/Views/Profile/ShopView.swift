import SwiftUI

/// Tackle Shop — purely cosmetic. No real-money pricing yet; everything costs Lure Coins
/// earned in-game. Categories: rod skins, badges, flags, frames.
struct ShopView: View {
    @StateObject private var viewModel = ShopViewModel()
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                coinHeader

                if viewModel.isLoading && viewModel.byCategory.isEmpty {
                    LoadingView(message: "Loading tackle shop...")
                        .frame(height: 300)
                } else if viewModel.byCategory.isEmpty {
                    EmptyStateView(
                        icon: "tag",
                        title: "Shop is empty",
                        message: "Items will appear here as the shop opens up.",
                        actionTitle: nil,
                        action: nil
                    )
                    .padding(.top, 40)
                } else {
                    ForEach(ShopCategory.allCases) { category in
                        if let items = viewModel.byCategory[category], !items.isEmpty {
                            categorySection(category: category, items: items)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .navigationTitle("Tackle Shop")
        .navigationBarTitleDisplayMode(.large)
        .alert(item: $viewModel.alert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    private var coinHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "circle.hexagongrid.fill")
                .font(.title2)
                .foregroundColor(.crown)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(appState.currentUser?.lureCoins ?? 0)")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                Text("Lure Coins")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: appState.currentUser?.rankTier.icon ?? "crown")
                .font(.title2)
                .foregroundColor(.crown)
            Text(appState.currentUser?.rankTier.rawValue ?? "Minnow")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private func categorySection(category: ShopCategory, items: [ShopItemWithOwnership]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(category.displayName, systemImage: category.icon)
                .font(.title3)
                .fontWeight(.bold)
                .padding(.horizontal, 4)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                ForEach(items) { entry in
                    ShopItemCard(entry: entry) {
                        Task { await viewModel.purchase(entry.item.id) }
                    } equip: {
                        Task { await viewModel.equip(entry.item.id) }
                    }
                }
            }
        }
    }
}

private struct ShopItemCard: View {
    let entry: ShopItemWithOwnership
    let purchase: () -> Void
    let equip: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: [Color.oceanBlue, Color.seafoam],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(height: 90)
                Image(systemName: entry.item.iconName ?? entry.item.category.icon)
                    .font(.system(size: 36))
                    .foregroundColor(.white)
                if entry.isEquipped {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.kelp)
                                .background(Circle().fill(.white).frame(width: 18, height: 18))
                                .padding(6)
                        }
                        Spacer()
                    }
                }
            }

            VStack(spacing: 2) {
                Text(entry.item.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                if let desc = entry.item.description {
                    Text(desc)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)

            actionButton
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    @ViewBuilder
    private var actionButton: some View {
        if entry.owned {
            if entry.isEquipped {
                Text("Equipped")
                    .font(.caption)
                    .foregroundColor(.kelp)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.kelp.opacity(0.15))
                    .cornerRadius(8)
            } else {
                Button(action: equip) {
                    Text("Equip")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.seafoam)
                        .foregroundColor(.deepOcean)
                        .cornerRadius(8)
                }
            }
        } else if let block = entry.block {
            VStack(spacing: 2) {
                Text("Locked")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Text(block.message)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color(.systemGray5))
            .cornerRadius(8)
        } else {
            Button(action: purchase) {
                HStack(spacing: 4) {
                    Image(systemName: "circle.hexagongrid.fill")
                        .font(.caption)
                    Text("\(entry.item.costCoins)")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.crown)
                .foregroundColor(.deepOcean)
                .cornerRadius(8)
            }
        }
    }
}

@MainActor
final class ShopViewModel: ObservableObject {
    @Published var byCategory: [ShopCategory: [ShopItemWithOwnership]] = [:]
    @Published var isLoading = false
    @Published var alert: AlertContent?

    struct AlertContent: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    func load() async {
        guard let user = AppState.shared.currentUser else { return }
        isLoading = true
        let stats = await unlockStats(for: user.id)
        let items = (try? await AppState.shared.shopService.getCatalog(for: user, stats: stats)) ?? []
        byCategory = Dictionary(grouping: items) { $0.item.category }
        isLoading = false
    }

    private func unlockStats(for userId: String) async -> UserStats {
        let catches = (try? await AppState.shared.catchRepository.getCatches(forUser: userId)) ?? []
        let releaseCount = catches.filter { $0.released }.count
        let trophyCount = await trophyCatchCount(in: catches)

        return UserStats(
            totalCatches: catches.count,
            publicCatches: catches.filter { $0.isPublic }.count,
            crownedSpots: 0,
            ruledTerritories: 0,
            largestCatch: nil,
            largestCatchUnit: nil,
            favoriteSpecies: nil,
            speciesDiscovered: 0,
            releaseCount: releaseCount,
            trophyCount: trophyCount
        )
    }

    private func trophyCatchCount(in catches: [FishCatch]) async -> Int {
        var count = 0
        var cache: [String: FishRarity] = [:]

        for fishCatch in catches {
            let key = fishCatch.species.lowercased()
            let rarity: FishRarity

            if let cached = cache[key] {
                rarity = cached
            } else if let species = try? await AppState.shared.codexService.resolveSpecies(named: fishCatch.species) {
                rarity = species.rarityTier
                cache[key] = rarity
            } else {
                rarity = .common
                cache[key] = rarity
            }

            if rarity == .trophy {
                count += 1
            }
        }

        return count
    }

    func purchase(_ itemId: String) async {
        guard let user = AppState.shared.currentUser else { return }
        do {
            try await AppState.shared.shopService.purchase(itemId: itemId, for: user)
            await AppState.shared.refreshCurrentUser()
            await load()
        } catch {
            alert = AlertContent(title: "Purchase failed", message: error.localizedDescription)
        }
    }

    func equip(_ itemId: String) async {
        guard let user = AppState.shared.currentUser else { return }
        do {
            try await AppState.shared.shopService.equip(itemId: itemId, for: user)
            await AppState.shared.refreshCurrentUser()
            await load()
        } catch {
            alert = AlertContent(title: "Equip failed", message: error.localizedDescription)
        }
    }
}
