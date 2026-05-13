import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.reelTheme) private var theme
    @StateObject private var vm: HomeViewModel
    @State private var didLoad = false

    init() {
        let state = AppState.shared
        state.configure()
        _vm = StateObject(wrappedValue: HomeViewModel(
            bountyService: state.bountyService,
            dethroneService: state.dethroneEventService,
            leaderboardService: state.leaderboardService,
            spotRepository: state.spotRepository
        ))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: theme.spacing.m) {
                    RoyaleTopDock(
                        bounty: vm.todaysBounty,
                        activeSeason: appState.activeSeason,
                        unreadCount: appState.unreadNotifications,
                        onOpenQuests: openChallenges,
                        onOpenChest: openSeason
                    )

                    RoyaleEventBanner(
                        bounty: vm.todaysBounty,
                        rank: appState.seasonRank,
                        onTap: openChallenges
                    )
                    .id("bounty")

                    RoyaleBattleHub(
                        top3: vm.top3,
                        yourEntry: vm.yourEntry,
                        crownsHeld: appState.crownsHeld,
                        onLeaderboard: openLeaderboard,
                        onCodex: { appState.homeNavigationPath.append(NavigationDestination.codex) },
                        onShop: { appState.homeNavigationPath.append(NavigationDestination.shop) },
                        onNotifications: { appState.homeNavigationPath.append(NavigationDestination.notifications) }
                    )
                    .id("arena")

                    RoyaleBattleActions(
                        onBattle: { appState.homeNavigationPath.append(NavigationDestination.logCatch(spotId: nil)) },
                        onDuo: { appState.selectedTab = .community }
                    )

                    RoyaleChestRow(
                        bounty: vm.todaysBounty,
                        ruledSpots: vm.ruledSpots,
                        activeSeason: appState.activeSeason,
                        currentUser: appState.currentUser,
                        crownsHeld: appState.crownsHeld,
                        onOpenBounty: openChallenges,
                        onOpenSpots: { appState.selectedTab = .spots },
                        onOpenSeason: openSeason,
                        onOpenShop: { appState.homeNavigationPath.append(NavigationDestination.shop) }
                    )
                    .id("chests")

                    RoyaleDethroneFeed(events: vm.dethrones) { _ in
                        appState.selectedTab = .community
                    }
                    .id("ticker")
                }
                .padding(.horizontal, theme.spacing.m)
                .padding(.top, theme.spacing.s)
                .padding(.bottom, 120)
            }
            .background(RoyaleAnimatedBackdrop().ignoresSafeArea())
            .task {
                guard !didLoad else { return }
                didLoad = true
                await vm.load(currentUserId: appState.currentUser?.id)
                await appState.refreshHUD()
                #if DEBUG
                if let target = UserDefaults.standard.string(forKey: "RR_PREVIEW_HOME_SCROLL"), !target.isEmpty {
                    UserDefaults.standard.removeObject(forKey: "RR_PREVIEW_HOME_SCROLL")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
                            proxy.scrollTo(target, anchor: .top)
                        }
                    }
                }
                #endif
            }
            .refreshable {
                await vm.load(currentUserId: appState.currentUser?.id)
                await appState.refreshHUD()
            }
        }
    }

    private func openLeaderboard() {
        appState.homeNavigationPath.append(NavigationDestination.leaderboard)
    }

    private func openChallenges() {
        appState.homeNavigationPath.append(NavigationDestination.challenges)
    }

    private func openSeason() {
        appState.homeNavigationPath.append(NavigationDestination.season)
    }
}

private struct RoyaleAnimatedBackdrop: View {
    @Environment(\.reelTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                LinearGradient(
                    colors: [
                        Color(hex: 0x143C74),
                        theme.colors.brand.deepSea,
                        Color(hex: 0x07111D)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                DiamondGrid()
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    .offset(y: CGFloat(sin(t * 0.2) * 6))

                RadialGradient(
                    colors: [
                        theme.colors.brand.seafoam.opacity(0.32),
                        .clear
                    ],
                    center: UnitPoint(x: 0.25 + 0.04 * sin(t * 0.18), y: 0.12),
                    startRadius: 8,
                    endRadius: 360
                )

                RadialGradient(
                    colors: [
                        theme.colors.brand.coralRed.opacity(0.20),
                        .clear
                    ],
                    center: UnitPoint(x: 0.78, y: 0.42 + 0.04 * cos(t * 0.16)),
                    startRadius: 20,
                    endRadius: 320
                )

                FloatingSparkles()
                    .opacity(0.45)
            }
        }
    }
}

private struct DiamondGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 74
        let height = rect.height + spacing * 2
        let width = rect.width + spacing * 2

        var x = -width
        while x < width * 1.5 {
            path.move(to: CGPoint(x: x, y: -spacing))
            path.addLine(to: CGPoint(x: x + height, y: height - spacing))
            x += spacing
        }

        x = -width
        while x < width * 1.5 {
            path.move(to: CGPoint(x: x, y: height))
            path.addLine(to: CGPoint(x: x + height, y: -spacing))
            x += spacing
        }

        return path
    }
}

private struct RoyaleTopDock: View {
    let bounty: Bounty?
    let activeSeason: Season?
    let unreadCount: Int
    let onOpenQuests: () -> Void
    let onOpenChest: () -> Void

    @Environment(\.reelTheme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.s) {
            TopDockCard(
                title: "Quests",
                subtitle: bounty == nil ? "Loading" : "Active now",
                icon: "checkmark.seal.fill",
                badge: nil,
                colors: [theme.colors.brand.seafoam, Color(hex: 0x4E9BEF)],
                action: onOpenQuests
            )

            TopDockCard(
                title: "Crown Chest",
                subtitle: activeSeason.map { shortCountdown(until: $0.endDate) } ?? nextDailyResetText,
                icon: "shippingbox.fill",
                badge: unreadCount > 0 ? "\(unreadCount)" : nil,
                colors: [theme.colors.brand.crown, Color(hex: 0x7DD3FC)],
                action: onOpenChest
            )
        }
    }

    private var nextDailyResetText: String {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) ?? Date()
        return shortCountdown(until: tomorrow)
    }
}

private struct TopDockCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let badge: String?
    let colors: [Color]
    let action: () -> Void

    @Environment(\.reelTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.s) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x112C49), Color(hex: 0x27537A)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.26), lineWidth: 1.2)
                        )
                        .shadow(color: colors.first?.opacity(0.32) ?? .clear, radius: 12, x: 0, y: 6)

                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(
                            LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
                        )
                        .frame(width: 56, height: 56)

                    if let badge {
                        Text(badge)
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(theme.colors.brand.coralRed))
                            .offset(x: 7, y: -7)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.72)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(theme.colors.brand.parchment)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(theme.spacing.s)
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x1C6296), Color(hex: 0x143A5E)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.30), lineWidth: 1.5)
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.24), lineWidth: 3)
                    .blur(radius: 1)
                    .offset(y: 2)
                    .mask(alignment: .top) {
                        Rectangle().frame(height: 18)
                    }
            }
            .shadow(color: Color.black.opacity(0.34), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(RoyalePressStyle())
        .accessibilityLabel(title)
    }
}

private struct RoyaleEventBanner: View {
    let bounty: Bounty?
    let rank: Int?
    let onTap: () -> Void

    @Environment(\.reelTheme) private var theme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: theme.spacing.s) {
                ZStack {
                    Circle()
                        .fill(theme.colors.brand.crown.opacity(0.28))
                        .frame(width: 58, height: 58)
                    Circle()
                        .strokeBorder(theme.colors.brand.crown, lineWidth: 4)
                        .frame(width: 52, height: 52)
                    Image(systemName: bounty?.iconSystemName ?? "trophy.fill")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(theme.colors.brand.crown)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(bounty?.title ?? "Loading arena quests")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(bounty?.criteria ?? "Syncing your live challenges")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: 0xEAF9C5))
                        .lineLimit(1)
                }

                Spacer(minLength: theme.spacing.xs)

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12, weight: .black))
                        Text("\(bounty?.rewardGlory ?? 0)")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                    }
                    .foregroundStyle(.white)

                    Text(rank.map { "#\($0)" } ?? "LIVE")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(theme.colors.brand.crown)
                }
                .frame(minWidth: 58, alignment: .trailing)
            }
            .padding(.horizontal, theme.spacing.s)
            .padding(.vertical, theme.spacing.xs)
            .frame(minHeight: 82)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: 0x78D85C),
                                Color(hex: 0x2FAD89),
                                Color(hex: 0x2C8CD7)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.black.opacity(0.18))
                    .frame(height: 22)
                    .allowsHitTesting(false)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.50), lineWidth: 1.4)
            )
            .shadow(color: Color.black.opacity(0.32), radius: 12, x: 0, y: 7)
        }
        .buttonStyle(RoyalePressStyle())
        .accessibilityLabel(bounty?.title ?? "Arena quests")
    }
}

private struct RoyaleBattleHub: View {
    let top3: [CaptainRankEntry]
    let yourEntry: CaptainRankEntry?
    let crownsHeld: Int
    let onLeaderboard: () -> Void
    let onCodex: () -> Void
    let onShop: () -> Void
    let onNotifications: () -> Void

    @Environment(\.reelTheme) private var theme

    var body: some View {
        ZStack {
            HStack {
                SideRail(items: [
                    SideRailItem(icon: "trophy.fill", label: "Leaderboard", action: onLeaderboard),
                    SideRailItem(icon: "book.closed.fill", label: "Codex", action: onCodex)
                ])
                Spacer()
                SideRail(items: [
                    SideRailItem(icon: "cart.fill", label: "Shop", action: onShop),
                    SideRailItem(icon: "bell.fill", label: "Inbox", action: onNotifications)
                ])
            }
            .padding(.horizontal, 2)

            RoyaleArena3D(
                top3: top3,
                yourEntry: yourEntry,
                crownsHeld: crownsHeld
            )
            .padding(.horizontal, 50)
        }
        .frame(height: 318)
    }
}

private struct SideRailItem: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let action: () -> Void
}

private struct SideRail: View {
    let items: [SideRailItem]
    @Environment(\.reelTheme) private var theme

    var body: some View {
        VStack(spacing: theme.spacing.xl) {
            ForEach(items) { item in
                Button(action: item.action) {
                    Image(systemName: item.icon)
                        .font(.system(size: 25, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [theme.colors.brand.crown, theme.colors.brand.seafoam],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 58, height: 58)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: 0x31475E), Color(hex: 0x172433)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.28), lineWidth: 1.2)
                        )
                        .shadow(color: Color.black.opacity(0.38), radius: 10, x: 0, y: 6)
                }
                .buttonStyle(RoyalePressStyle())
                .accessibilityLabel(item.label)
            }
        }
    }
}

private struct RoyaleArena3D: View {
    let top3: [CaptainRankEntry]
    let yourEntry: CaptainRankEntry?
    let crownsHeld: Int

    @Environment(\.reelTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var leftName: String {
        top3.dropFirst().first?.captainName ?? yourEntry?.captainName ?? "You"
    }

    private var rightName: String {
        top3.first?.captainName ?? "Crown"
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let bob = CGFloat(sin(t * 1.35) * 5)
            let sway = CGFloat(cos(t * 0.9) * 2.5)

            ZStack {
                ForEach(0..<10, id: \.self) { idx in
                    FloatingStone(index: idx, time: t)
                }

                Ellipse()
                    .fill(Color.black.opacity(0.46))
                    .frame(width: 250, height: 52)
                    .blur(radius: 10)
                    .offset(y: 118)

                ZStack {
                    ArenaBase()
                        .offset(y: 62)

                    HStack(alignment: .bottom, spacing: 8) {
                        BattleTower(
                            title: leftName,
                            color: Color(hex: 0x2E8CFF),
                            crownCount: max(crownsHeld, 0),
                            time: t
                        )
                        .offset(x: -12, y: 18 + bob * 0.2)

                        CentralCrest(time: t)
                            .offset(y: -8 + bob)

                        BattleTower(
                            title: rightName,
                            color: theme.colors.brand.coralRed,
                            crownCount: top3.first?.crownsHeld ?? 0,
                            time: t + 0.7
                        )
                        .offset(x: 12, y: 18 - bob * 0.2)
                    }

                    WaterfallGlow(time: t)
                        .offset(y: 122)
                }
                .rotation3DEffect(.degrees(11 + sway * 0.25), axis: (x: 1, y: 0, z: 0), perspective: 0.7)
                .rotation3DEffect(.degrees(sway), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
                .shadow(color: Color.black.opacity(0.38), radius: 22, x: 0, y: 16)
            }
        }
    }
}

private struct FloatingStone: View {
    let index: Int
    let time: TimeInterval

    var body: some View {
        let angle = Double(index) * .pi * 0.34 + time * (0.18 + Double(index % 3) * 0.03)
        let radius = CGFloat(94 + (index % 4) * 18)
        let x = CGFloat(cos(angle)) * radius
        let y = CGFloat(sin(angle * 1.16)) * 72
        let size = CGFloat(9 + (index % 4) * 5)

        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(hex: 0x718397), Color(hex: 0x334152)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size * 0.78)
            .rotationEffect(.degrees(angle * 40))
            .shadow(color: Color.black.opacity(0.32), radius: 5, x: 0, y: 3)
            .offset(x: x, y: y + 4)
            .opacity(0.72)
    }
}

private struct ArenaBase: View {
    @Environment(\.reelTheme) private var theme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.55))
                .frame(width: 250, height: 132)
                .offset(y: 22)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: 0x39495D),
                            Color(hex: 0x182633)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 248, height: 154)

            HStack(spacing: 0) {
                Color(hex: 0x2B8FF7)
                Color(hex: 0xD84C5E)
            }
            .frame(width: 196, height: 86)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(theme.colors.brand.crown.opacity(0.28), lineWidth: 1)
            )

            VStack(spacing: 11) {
                ForEach(0..<3, id: \.self) { idx in
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [theme.colors.brand.brassGold, Color(hex: 0x8E6226)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 78 - CGFloat(idx * 12), height: 12)
                        .shadow(color: Color.black.opacity(0.24), radius: 4, x: 0, y: 3)
                }
            }
            .offset(y: 18)

            HStack(spacing: 68) {
                BannerPole(color: Color(hex: 0x2B8FF7))
                BannerPole(color: Color(hex: 0xD84C5E))
            }
            .offset(y: -36)
        }
        .rotation3DEffect(.degrees(56), axis: (x: 1, y: 0, z: 0), perspective: 0.85)
    }
}

private struct BannerPole: View {
    let color: Color

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(hex: 0xD5B86A))
                .frame(width: 4, height: 44)
            Rectangle()
                .fill(color)
                .frame(width: 28, height: 38)
                .clipShape(BannerShape())
                .shadow(color: color.opacity(0.45), radius: 8, x: 0, y: 4)
        }
    }
}

private struct BannerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.22))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct BattleTower: View {
    let title: String
    let color: Color
    let crownCount: Int
    let time: TimeInterval

    @Environment(\.reelTheme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x6A7582), Color(hex: 0x2E3946)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 66, height: 78)
                    .overlay(alignment: .top) {
                        HStack(spacing: 5) {
                            ForEach(0..<3, id: \.self) { _ in
                                Rectangle()
                                    .fill(Color(hex: 0xAEB9C4))
                                    .frame(width: 11, height: 10)
                            }
                        }
                        .offset(y: -6)
                    }

                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(color)
                    .frame(width: 44, height: 54)
                    .offset(y: 10)
                    .shadow(color: color.opacity(0.40), radius: 10, x: 0, y: 0)

                Image(systemName: "crown.fill")
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.colors.brand.crown, theme.colors.brand.brassGold],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .offset(y: -48 + CGFloat(sin(time * 1.5) * 2))
            }

            Text(title)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .frame(width: 78)
                .padding(.top, 8)

            HStack(spacing: 3) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 8, weight: .black))
                Text("\(crownCount)")
                    .font(.system(size: 10, weight: .black, design: .rounded))
            }
            .foregroundStyle(theme.colors.brand.crown)
        }
    }
}

private struct CentralCrest: View {
    let time: TimeInterval

    @Environment(\.reelTheme) private var theme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xF7F9FF), Color(hex: 0x9FAABC), Color(hex: 0x1E2835)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 116, height: 116)
                .rotationEffect(.degrees(45))
                .shadow(color: Color.black.opacity(0.40), radius: 18, x: 0, y: 12)

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.62), lineWidth: 3)
                .frame(width: 96, height: 96)
                .rotationEffect(.degrees(45))

            CrossedRods()
                .stroke(
                    LinearGradient(
                        colors: [Color.white, theme.colors.brand.crown],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: 88, height: 88)
                .shadow(color: Color.white.opacity(0.45), radius: 8, x: 0, y: 0)

            Image(systemName: "fish.fill")
                .font(.system(size: 28, weight: .black))
                .foregroundStyle(theme.colors.brand.seafoam)
                .rotationEffect(.degrees(sin(time * 0.9) * 8))
                .offset(y: -2)
        }
    }
}

private struct CrossedRods: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 10, y: rect.maxY - 10))
        path.addLine(to: CGPoint(x: rect.maxX - 10, y: rect.minY + 10))
        path.move(to: CGPoint(x: rect.maxX - 10, y: rect.maxY - 10))
        path.addLine(to: CGPoint(x: rect.minX + 10, y: rect.minY + 10))
        return path
    }
}

private struct WaterfallGlow: View {
    let time: TimeInterval

    var body: some View {
        VStack(spacing: -4) {
            ForEach(0..<4, id: \.self) { idx in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: 0x75F7FF).opacity(0.95),
                                Color(hex: 0x2B8FF7).opacity(0.20)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 14 + CGFloat(idx * 5), height: 16)
                    .opacity(0.72 - Double(idx) * 0.12)
                    .offset(y: CGFloat(sin(time * 4 + Double(idx)) * 2))
            }
        }
        .blur(radius: 0.3)
    }
}

private struct RoyaleBattleActions: View {
    let onBattle: () -> Void
    let onDuo: () -> Void

    @Environment(\.reelTheme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.s) {
            RoyaleActionButton(
                title: "Battle",
                subtitle: "Log catch",
                icon: "scope",
                colors: [Color(hex: 0xFFD857), Color(hex: 0xFF981F)],
                foreground: Color(hex: 0x3B2100),
                action: onBattle
            )
            RoyaleActionButton(
                title: "2v2",
                subtitle: "Community",
                icon: "person.2.fill",
                colors: [Color(hex: 0x70D5FF), Color(hex: 0x2D91FF)],
                foreground: .white,
                action: onDuo
            )
        }
    }
}

private struct RoyaleActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let colors: [Color]
    let foreground: Color
    let action: () -> Void

    @Environment(\.reelTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: theme.spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .black))
                VStack(alignment: .leading, spacing: 0) {
                    Text(title)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .minimumScaleFactor(0.64)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .textCase(.uppercase)
                        .opacity(0.82)
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(foreground)
            .padding(.horizontal, theme.spacing.m)
            .frame(maxWidth: .infinity, minHeight: 88)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.24))
                    .frame(height: 22)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.45), lineWidth: 1.5)
            )
            .shadow(color: colors.last?.opacity(0.42) ?? .clear, radius: 16, x: 0, y: 8)
        }
        .buttonStyle(RoyalePressStyle())
    }
}

private struct RoyaleChestRow: View {
    let bounty: Bounty?
    let ruledSpots: [Spot]
    let activeSeason: Season?
    let currentUser: User?
    let crownsHeld: Int
    let onOpenBounty: () -> Void
    let onOpenSpots: () -> Void
    let onOpenSeason: () -> Void
    let onOpenShop: () -> Void

    @Environment(\.reelTheme) private var theme

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacing.xs) {
                ChestSlotCard(
                    title: bounty == nil ? "Quests" : "Open Now",
                    subtitle: bounty.map { "+\($0.rewardDoubloons) coins" } ?? "Syncing",
                    footer: bounty.map { shortCountdown(until: $0.endsAt) } ?? "Today",
                    icon: "gift.fill",
                    colors: [Color(hex: 0x55EE9C), Color(hex: 0x1D9B72)],
                    action: onOpenBounty
                )

                ChestSlotCard(
                    title: crownsHeld > 0 ? "\(crownsHeld) Crowns" : "Crown Hunt",
                    subtitle: ruledSpots.first?.name ?? "Claim a spot",
                    footer: ruledSpots.first?.bestCatchDisplay ?? "Find waters",
                    icon: "crown.fill",
                    colors: [Color(hex: 0xAEE7FF), Color(hex: 0x3D8DFF)],
                    action: onOpenSpots
                )

                ChestSlotCard(
                    title: "Season",
                    subtitle: activeSeason.map { "Season \($0.seasonNumber)" } ?? "Live ladder",
                    footer: activeSeason.map { shortCountdown(until: $0.endDate) } ?? "Ranking",
                    icon: "shield.fill",
                    colors: [Color(hex: 0xB47EFF), Color(hex: 0x435BFF)],
                    action: onOpenSeason
                )

                ChestSlotCard(
                    title: "Shop",
                    subtitle: "\(currentUser?.lureCoins ?? 0) coins",
                    footer: currentUser?.rankTier.rawValue ?? "Captain",
                    icon: "shippingbox.fill",
                    colors: [Color(hex: 0xFFD45E), Color(hex: 0xD17822)],
                    action: onOpenShop
                )
            }
            .padding(.horizontal, 1)
        }
    }
}

private struct ChestSlotCard: View {
    let title: String
    let subtitle: String
    let footer: String
    let icon: String
    let colors: [Color]
    let action: () -> Void

    @Environment(\.reelTheme) private var theme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(footer)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(Color(hex: 0x17324A))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color(hex: 0xDFFFEF).opacity(0.92))
                    )

                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 82, height: 70)
                        .shadow(color: colors.last?.opacity(0.42) ?? .clear, radius: 10, x: 0, y: 6)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.black.opacity(0.20))
                        .frame(width: 58, height: 12)
                        .offset(y: 14)
                    Image(systemName: icon)
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(.white)
                        .shadow(color: Color.black.opacity(0.24), radius: 5, x: 0, y: 3)
                }

                VStack(spacing: 0) {
                    Text(title)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundStyle(theme.colors.brand.parchment)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                }
            }
            .padding(theme.spacing.xs)
            .frame(width: 118, height: 166)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x23557F), Color(hex: 0x152B45)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.26), lineWidth: 1.2)
            )
            .shadow(color: Color.black.opacity(0.32), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(RoyalePressStyle())
    }
}

private struct RoyaleDethroneFeed: View {
    let events: [DethroneEvent]
    let onTapEvent: (DethroneEvent) -> Void

    @Environment(\.reelTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            HStack {
                Text("Live Dethrones")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "bolt.fill")
                    .foregroundStyle(theme.colors.brand.crown)
            }

            if events.isEmpty {
                HStack(spacing: theme.spacing.s) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(theme.colors.brand.seafoam)
                    Text("No crowns have changed hands yet. First catch can light this up.")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(theme.colors.text.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(theme.spacing.s)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: 0x10283E).opacity(0.82))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: theme.spacing.xs) {
                        ForEach(events) { event in
                            Button {
                                onTapEvent(event)
                            } label: {
                                HStack(spacing: theme.spacing.xs) {
                                    TierEmblem(tier: event.newKingTier, division: 1, size: .small)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(event.newKingName)
                                            .font(.system(size: 13, weight: .black, design: .rounded))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                        Text("\(event.spotName) - \(event.elapsedShort)")
                                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                                            .foregroundStyle(theme.colors.text.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .padding(.horizontal, theme.spacing.s)
                                .padding(.vertical, theme.spacing.xs)
                                .background(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .fill(Color(hex: 0x10283E).opacity(0.92))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                                        .strokeBorder(theme.colors.brand.coralRed.opacity(0.35), lineWidth: 1)
                                )
                            }
                            .buttonStyle(RoyalePressStyle())
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
    }
}

private struct RoyalePressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .animation(.spring(response: 0.18, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

private func shortCountdown(until date: Date) -> String {
    let interval = max(0, date.timeIntervalSinceNow)
    let hours = Int(interval) / 3600
    let minutes = (Int(interval) % 3600) / 60
    let days = hours / 24

    if days > 0 {
        return "\(days)d \(hours % 24)h"
    }
    if hours > 0 {
        return "\(hours)h \(minutes)m"
    }
    return "\(max(minutes, 1))m"
}
