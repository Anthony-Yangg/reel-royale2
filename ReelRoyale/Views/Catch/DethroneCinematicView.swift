import SwiftUI

/// 3-second dethrone cinematic shown when a user claims a spot from another king.
struct DethroneCinematicView: View {
    let spotName: String
    let captainName: String
    let avatarURL: URL?
    let initial: String
    let tier: CaptainTier
    let reward: ProgressionReward
    let onComplete: () -> Void

    @Environment(\.reelTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var appState: AppState

    @State private var phase: Phase = .fadeIn
    @State private var crownScale: CGFloat = 0.1
    @State private var crownOpacity: Double = 0
    @State private var shakeOffset: CGFloat = 0
    @State private var bannerOffset: CGFloat = 80
    @State private var statsOpacity: Double = 0

    enum Phase {
        case fadeIn, crownEnter, shatter, crownTransfer, banner, stats, done
    }

    var body: some View {
        ZStack {
            theme.colors.surface.canvas.ignoresSafeArea()
            stars
            VStack(spacing: theme.spacing.lg) {
                Spacer()
                avatarWithCrown
                bannerView
                statsView
                Spacer()
            }
            .padding(.horizontal, theme.spacing.xl)
        }
        .offset(x: shakeOffset)
        .onAppear { startSequence() }
    }

    // MARK: - Sequence

    private func startSequence() {
        guard !reduceMotion else {
            renderStaticReveal()
            return
        }

        appState.sounds?.play(.cannonBoom)
        appState.haptics?.heavy()

        // 0.0 → 0.3 fade in handled by .opacity transition (free)
        // 0.3 — crown enters & settles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) {
            phase = .crownEnter
            withAnimation(.easeOut(duration: 0.5)) {
                crownScale = 1.0
                crownOpacity = 1.0
            }
        }
        // 0.8 — shake + shatter sound + heavy haptic
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.80) {
            phase = .shatter
            appState.sounds?.play(.crownShatter)
            appState.haptics?.heavy()
            withAnimation(.linear(duration: 0.18).repeatCount(3, autoreverses: true)) {
                shakeOffset = 8
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { shakeOffset = 0 }
        }
        // 1.2 — banner unfurl
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.20) {
            phase = .banner
            appState.sounds?.play(.seaShantyHorn)
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
                bannerOffset = 0
            }
        }
        // 1.8 — stats overlay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.80) {
            phase = .stats
            appState.sounds?.play(.coinShower)
            withAnimation(.easeOut(duration: 0.4)) { statsOpacity = 1 }
        }
        // 2.5 — done; trigger completion 0.7s later (let user read stats)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.20) {
            phase = .done
            appState.haptics?.success()
            withAnimation(.easeIn(duration: 0.4)) {
                statsOpacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onComplete()
            }
        }
    }

    private func renderStaticReveal() {
        crownScale = 1.0
        crownOpacity = 1.0
        bannerOffset = 0
        statsOpacity = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { onComplete() }
    }

    // MARK: - Subviews

    private var stars: some View {
        // Sparkle backdrop — gold particles drift in.
        TimelineView(.animation) { ctx in
            Canvas { context, size in
                let t = ctx.date.timeIntervalSince1970
                for i in 0..<24 {
                    let x = size.width * CGFloat((Double(i) * 0.137 + t * 0.06).truncatingRemainder(dividingBy: 1.0))
                    let yBase = size.height * CGFloat((Double(i) * 0.421 + t * 0.04).truncatingRemainder(dividingBy: 1.0))
                    let alpha = 0.25 + 0.5 * abs(sin(t + Double(i)))
                    let rect = CGRect(x: x, y: yBase, width: 3, height: 3)
                    context.fill(Path(ellipseIn: rect), with: .color(theme.colors.brand.crown.opacity(alpha)))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var avatarWithCrown: some View {
        ZStack {
            ShipAvatar(
                imageURL: avatarURL,
                initial: initial,
                tier: tier,
                size: .hero,
                showCrown: false
            )
            Image(systemName: "crown.fill")
                .font(.system(size: 60, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [theme.colors.brand.crown, theme.colors.brand.brassGold],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .shadow(color: theme.colors.brand.crown.opacity(0.7), radius: 12)
                .scaleEffect(crownScale)
                .opacity(crownOpacity)
                .offset(y: -90)
        }
    }

    private var bannerView: some View {
        VStack(spacing: 4) {
            Text("YOU ARE NOW")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.colors.brand.brassGold)
                .tracking(2.5)
            Text("KING OF \(spotName.uppercased())")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundStyle(theme.colors.brand.crown)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.horizontal, theme.spacing.xl)
        .padding(.vertical, theme.spacing.m)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: theme.radius.heroCard, style: .continuous)
                    .fill(theme.colors.surface.elevated)
                RoundedRectangle(cornerRadius: theme.radius.heroCard, style: .continuous)
                    .fill(
                        LinearGradient(colors: [theme.colors.brand.deepSea.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom)
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.heroCard, style: .continuous)
                .strokeBorder(theme.colors.brand.brassGold, lineWidth: 2)
        )
        .offset(y: bannerOffset)
        .reelShadow(theme.shadow.heroCard)
    }

    private var statsView: some View {
        VStack(spacing: theme.spacing.xs) {
            HStack(spacing: theme.spacing.xl) {
                statTile(label: "Doubloons", value: "+\(reward.doubloons)", icon: "dollarsign.circle.fill", color: theme.colors.brand.crown)
                statTile(label: "Glory",     value: "+\(reward.glory)",     icon: "rosette",                 color: theme.colors.brand.seafoam)
            }
        }
        .opacity(statsOpacity)
    }

    private func statTile(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(theme.colors.text.primary)
                .monospacedDigit()
            Text(label.uppercased())
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.colors.text.muted)
                .tracking(1.2)
        }
    }
}
