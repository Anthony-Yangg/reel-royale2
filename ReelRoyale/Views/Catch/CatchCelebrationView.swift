import SwiftUI

/// The post-catch celebration. Shown immediately after a successful catch.
/// Animates XP and coin counters, surfaces dethrone/rank-up/challenge events,
/// then dismisses on the user's tap.
struct CatchCelebrationView: View {
    let result: CatchResult
    let onContinue: () -> Void

    @State private var displayXP: Int = 0
    @State private var displayCoins: Int = 0
    @State private var showBonuses: Bool = false
    @State private var showChallenges: Bool = false
    @State private var showRankUp: Bool = false
    @State private var crownPulse: Bool = false

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(spacing: 24) {
                    headerBanner
                        .padding(.top, 32)

                    rewardsCard
                    rankProgressCard

                    if !result.xpBreakdown.bonusItems.isEmpty {
                        bonusList
                            .opacity(showBonuses ? 1 : 0)
                            .offset(y: showBonuses ? 0 : 20)
                    }

                    if !result.completedChallenges.isEmpty {
                        challengesCard
                            .opacity(showChallenges ? 1 : 0)
                            .offset(y: showChallenges ? 0 : 20)
                    }

                    Spacer(minLength: 16)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
            }

            VStack {
                Spacer()
                continueButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
        }
        .onAppear { startAnimations() }
    }

    // MARK: - Sections

    private var background: some View {
        LinearGradient(
            colors: result.isNewKing
                ? [Color.crown.opacity(0.85), Color.deepOcean]
                : [Color.oceanBlue, Color.deepOcean],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var headerBanner: some View {
        VStack(spacing: 12) {
            Image(systemName: result.isNewKing ? "crown.fill" : "fish.fill")
                .font(.system(size: 64))
                .foregroundColor(result.isNewKing ? .crown : .seafoam)
                .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                .scaleEffect(crownPulse ? 1.15 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: crownPulse)

            Text(headerTitle)
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let subtitle = headerSubtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }

    private var rewardsCard: some View {
        HStack(spacing: 16) {
            rewardTile(icon: "bolt.fill", label: "XP", value: displayXP, color: .yellow)
            rewardTile(icon: "circle.hexagongrid.fill", label: "Coins", value: displayCoins, color: .crown)
        }
    }

    private var rankProgressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: result.newRank.icon)
                    .font(.title2)
                    .foregroundColor(.crown)
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.newRank.rawValue)
                        .font(.headline)
                        .foregroundColor(.white)
                    if showRankUp {
                        Text("Rank up from \(result.oldRank.rawValue)!")
                            .font(.caption)
                            .foregroundColor(.crown)
                    } else if let toNext = result.xpToNextRank {
                        Text("\(toNext) XP to next rank")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    } else {
                        Text("Top tier reached")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                Spacer()
            }

            ProgressView(value: progressValue)
                .progressViewStyle(.linear)
                .tint(showRankUp ? .crown : .seafoam)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .colorScheme(.dark)
        .cornerRadius(16)
    }

    private var bonusList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bonuses")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.7))
                .textCase(.uppercase)

            ForEach(result.xpBreakdown.bonusItems) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.bonus?.icon ?? "star.fill")
                        .foregroundColor(.crown)
                    Text(item.label)
                        .font(.subheadline)
                        .foregroundColor(.white)
                    Spacer()
                    if item.xp > 0 {
                        Label("\(item.xp)", systemImage: "bolt.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                    if item.coins > 0 {
                        Label("\(item.coins)", systemImage: "circle.hexagongrid.fill")
                            .font(.caption)
                            .foregroundColor(.crown)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .colorScheme(.dark)
        .cornerRadius(16)
    }

    private var challengesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Challenges complete", systemImage: "checkmark.seal.fill")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.crown)
                .textCase(.uppercase)

            ForEach(result.completedChallenges) { challenge in
                VStack(alignment: .leading, spacing: 2) {
                    Text(challenge.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    HStack(spacing: 8) {
                        Label("+\(challenge.xpReward)", systemImage: "bolt.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        Label("+\(challenge.coinReward)", systemImage: "circle.hexagongrid.fill")
                            .font(.caption)
                            .foregroundColor(.crown)
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .colorScheme(.dark)
        .cornerRadius(16)
    }

    private var continueButton: some View {
        Button {
            onContinue()
        } label: {
            Text(result.isNewKing ? "Claim my crown" : "Nice catch — continue")
                .font(.headline)
                .foregroundColor(.deepOcean)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.seafoam)
                .cornerRadius(28)
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
        }
    }

    private func rewardTile(icon: String, label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text("+\(value)")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .colorScheme(.dark)
        .cornerRadius(16)
    }

    // MARK: - Helpers

    private var headerTitle: String {
        if result.leveledUp { return "Rank up!" }
        if result.isNewKing { return "King of the spot!" }
        if result.firstSpeciesEver { return "New species discovered!" }
        return "Nice catch!"
    }

    private var headerSubtitle: String? {
        if result.isNewKing {
            return "You took the crown at this spot."
        }
        if result.firstSpeciesEver {
            return "Added to your codex."
        }
        let size = result.fishCatch.sizeDisplay
        return "\(size) \(result.fishCatch.species)"
    }

    private var progressValue: Double {
        let current = result.updatedUser?.xp ?? 0
        return result.newRank.progress(xp: current)
    }

    private func startAnimations() {
        crownPulse = result.isNewKing
        let xpTarget = result.xpAwarded
        let coinTarget = result.coinsAwarded
        let totalDuration: Double = 1.4

        withAnimation(.easeOut(duration: totalDuration)) {
            displayXP = xpTarget
            displayCoins = coinTarget
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.6)) {
            showBonuses = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(1.0)) {
            showChallenges = true
        }
        if result.leveledUp {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.8)) {
                showRankUp = true
            }
        }

        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if result.isNewKing {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }
}

#Preview {
    CatchCelebrationView(
        result: CatchResult(
            fishCatch: FishCatch(
                userId: "u1", spotId: "s1", species: "Largemouth Bass",
                sizeValue: 4.2, sizeUnit: "kg", xpAwarded: 520, coinsAwarded: 60
            ),
            updatedUser: User(id: "u1", username: "Demo", xp: 1520, rankTier: .angler),
            isNewKing: true,
            previousKingId: "x",
            territoryControlChanged: true,
            newTerritoryRulerId: "u1",
            xpAwarded: 520,
            coinsAwarded: 60,
            xpBreakdown: XPBreakdown(
                baseXP: 420,
                speciesMultiplier: 1.5,
                bonusItems: [
                    XPLineItem(label: "First Blood", xp: 100, coins: 0, bonus: .firstSpecies),
                    XPLineItem(label: "Crown Taken", xp: 200, coins: 100, bonus: .dethrone)
                ],
                totalXP: 520,
                totalCoins: 60,
                firstSpecies: true,
                dethroned: true
            ),
            oldRank: .minnow,
            newRank: .angler,
            leveledUp: true,
            xpToNextRank: 3480,
            firstSpeciesEver: true,
            completedChallenges: []
        ),
        onContinue: {}
    )
}
