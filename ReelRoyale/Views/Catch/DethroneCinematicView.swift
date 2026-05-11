import SwiftUI

/// ~4.5-second dethrone cinematic — much bigger, slower, multi-layer feel.
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

    @State private var vignette: Double = 1.0
    @State private var crackOpacity: Double = 0
    @State private var shockwaveScale: CGFloat = 0.2
    @State private var shockwaveOpacity: Double = 0

    @State private var oldCrownY: CGFloat = -260
    @State private var oldCrownOpacity: Double = 0
    @State private var oldCrownRotate: Double = -20
    @State private var oldCrownShatter: Bool = false

    @State private var screenShakeX: CGFloat = 0

    @State private var avatarScale: CGFloat = 0.7
    @State private var avatarOpacity: Double = 0
    @State private var avatarBob: CGFloat = 0
    @State private var avatarTilt: Double = 0

    @State private var newCrownY: CGFloat = -300
    @State private var newCrownOpacity: Double = 0
    @State private var newCrownScale: CGFloat = 0.1
    @State private var newCrownGlow: Double = 0

    @State private var bannerOffset: CGFloat = 120
    @State private var bannerOpacity: Double = 0
    @State private var statsOpacity: Double = 0
    @State private var statsScale: CGFloat = 0.9

    @State private var sparklePhase: Double = 0
    @State private var rayPhase: Double = 0

    @State private var doneTriggered = false

    var body: some View {
        ZStack {
            // Deep canvas backdrop with radial glow
            RadialGradient(
                colors: [theme.colors.brand.deepSea, theme.colors.surface.canvas],
                center: .center, startRadius: 60, endRadius: 600
            )
            .ignoresSafeArea()

            godRays
            sparkles

            // Shockwave ring
            Circle()
                .strokeBorder(theme.colors.brand.crown.opacity(shockwaveOpacity), lineWidth: 6)
                .frame(width: 340, height: 340)
                .scaleEffect(shockwaveScale)
                .blur(radius: 2)

            // Old crown (gets shattered)
            if !oldCrownShatter {
                oldCrown
            } else {
                shatterParticles
            }

            // Crack overlay (lightning crackle)
            crackOverlay

            // Avatar with new crown crowning down on it
            VStack(spacing: 26) {
                Spacer()
                ZStack {
                    // Subtle halo behind avatar
                    Circle()
                        .fill(theme.colors.brand.crown.opacity(newCrownGlow * 0.35))
                        .frame(width: 240, height: 240)
                        .blur(radius: 30)

                    ShipAvatar(
                        imageURL: avatarURL,
                        initial: initial,
                        tier: tier,
                        size: .hero,
                        showCrown: false
                    )
                    .scaleEffect(avatarScale)
                    .opacity(avatarOpacity)
                    .offset(y: avatarBob)
                    .rotationEffect(.degrees(avatarTilt), anchor: .bottom)

                    // New crown descends
                    Image(systemName: "crown.fill")
                        .font(.system(size: 88, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [theme.colors.brand.crown, theme.colors.brand.brassGold, Color(hex: 0x8C6018)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .shadow(color: theme.colors.brand.crown.opacity(0.9), radius: 22)
                        .shadow(color: .black.opacity(0.6), radius: 4, x: 0, y: 3)
                        .scaleEffect(newCrownScale)
                        .opacity(newCrownOpacity)
                        .offset(y: newCrownY)
                }

                banner
                stats
                Spacer()
            }

            // Black-out vignette (fades out at start, in at end)
            Color.black.opacity(vignette).ignoresSafeArea()
        }
        .offset(x: screenShakeX)
        .onAppear { startSequence() }
    }

    // MARK: Layers

    private var godRays: some View {
        TimelineView(.animation) { _ in
            Canvas { context, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2 - 60)
                for i in 0..<14 {
                    let a = (Double(i) / 14) * .pi * 2 + rayPhase
                    var path = Path()
                    path.move(to: center)
                    let len: Double = 700
                    let x1 = center.x + CGFloat(cos(a)) * CGFloat(len)
                    let y1 = center.y + CGFloat(sin(a)) * CGFloat(len)
                    let spread: Double = 0.06
                    let x2 = center.x + CGFloat(cos(a + spread)) * CGFloat(len)
                    let y2 = center.y + CGFloat(sin(a + spread)) * CGFloat(len)
                    path.addLine(to: CGPoint(x: x1, y: y1))
                    path.addLine(to: CGPoint(x: x2, y: y2))
                    path.closeSubpath()
                    context.fill(path, with: .color(.white.opacity(0.04 * newCrownGlow)))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var sparkles: some View {
        TimelineView(.animation) { _ in
            Canvas { context, size in
                let t = sparklePhase
                for i in 0..<48 {
                    let dx = Double(i) * 0.197
                    let dy = Double(i) * 0.487
                    let x = size.width * CGFloat((dx + t * 0.05).truncatingRemainder(dividingBy: 1.0))
                    let y = size.height * CGFloat((dy + t * 0.03).truncatingRemainder(dividingBy: 1.0))
                    let alpha = 0.25 + 0.55 * abs(sin(t + Double(i)))
                    let r: CGFloat = i % 5 == 0 ? 3 : 2
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                                 with: .color(theme.colors.brand.crown.opacity(alpha * newCrownGlow)))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var crackOverlay: some View {
        Image(systemName: "bolt.fill")
            .font(.system(size: 320, weight: .black))
            .foregroundStyle(theme.colors.brand.crown.opacity(crackOpacity))
            .rotationEffect(.degrees(15))
            .blur(radius: 1)
            .blendMode(.plusLighter)
    }

    private var oldCrown: some View {
        Image(systemName: "crown.fill")
            .font(.system(size: 96, weight: .black))
            .foregroundStyle(
                LinearGradient(colors: [Color(hex: 0x8B7355), Color(hex: 0x4A3623)], startPoint: .top, endPoint: .bottom)
            )
            .opacity(oldCrownOpacity)
            .offset(y: oldCrownY)
            .rotationEffect(.degrees(oldCrownRotate))
            .shadow(color: .black.opacity(0.6), radius: 6)
    }

    /// 32 gold particle fragments expanding outward where old crown was.
    private var shatterParticles: some View {
        TimelineView(.animation) { ctx in
            Canvas { context, size in
                let t = ctx.date.timeIntervalSince1970.truncatingRemainder(dividingBy: 100)
                let center = CGPoint(x: size.width / 2, y: size.height / 2 - 100)
                for i in 0..<36 {
                    let angle = (Double(i) / 36) * .pi * 2
                    let dist = 60 + 220 * min(1, max(0, t.truncatingRemainder(dividingBy: 1.5)))
                    let x = center.x + CGFloat(cos(angle)) * CGFloat(dist)
                    let y = center.y + CGFloat(sin(angle)) * CGFloat(dist)
                    let size: CGFloat = 5
                    let rect = CGRect(x: x, y: y, width: size, height: size)
                    context.fill(Path(ellipseIn: rect),
                                 with: .color(theme.colors.brand.crown.opacity(0.85)))
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var banner: some View {
        VStack(spacing: 6) {
            Text("YOU ARE NOW")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.colors.brand.brassGold)
                .tracking(3)
            Text("KING OF")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.colors.text.primary)
                .tracking(2)
            Text(spotName.uppercased())
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [theme.colors.brand.crown, theme.colors.brand.brassGold], startPoint: .top, endPoint: .bottom)
                )
                .multilineTextAlignment(.center)
                .shadow(color: theme.colors.brand.crown.opacity(0.7), radius: 16)
                .lineLimit(2)
        }
        .padding(.horizontal, theme.spacing.xl)
        .padding(.vertical, theme.spacing.m)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.heroCard, style: .continuous)
                .fill(theme.colors.surface.elevated)
                .overlay(
                    LinearGradient(colors: [theme.colors.brand.deepSea.opacity(0.5), .clear], startPoint: .top, endPoint: .bottom)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radius.heroCard))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.heroCard, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [theme.colors.brand.crown, theme.colors.brand.brassGold.opacity(0.5)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 2.5
                )
        )
        .padding(.horizontal, theme.spacing.lg)
        .offset(y: bannerOffset)
        .opacity(bannerOpacity)
        .reelShadow(theme.shadow.heroCard)
    }

    private var stats: some View {
        HStack(spacing: theme.spacing.xl) {
            statTile(label: "Doubloons", value: "+\(reward.doubloons)", icon: "dollarsign.circle.fill", color: theme.colors.brand.crown)
            statTile(label: "Glory",     value: "+\(reward.glory)",     icon: "rosette",                 color: theme.colors.brand.seafoam)
        }
        .opacity(statsOpacity)
        .scaleEffect(statsScale)
    }

    private func statTile(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(theme.colors.text.primary)
                .monospacedDigit()
                .shadow(color: color.opacity(0.7), radius: 10)
            Text(label.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.colors.text.muted)
                .tracking(1.5)
        }
    }

    // MARK: Sequence

    private func startSequence() {
        guard !reduceMotion else { renderStatic(); return }

        appState.sounds?.play(.cannonBoom)
        appState.haptics?.heavy()

        // 0.0–0.4 — fade out vignette
        withAnimation(.easeOut(duration: 0.4)) { vignette = 0 }
        // Continuous god-ray sweep
        withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) { rayPhase = .pi * 2 }
        // Continuous sparkles
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) { sparklePhase = 1.0 }

        // 0.4 — old crown descends from above to center
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeOut(duration: 0.7)) {
                oldCrownY = -150
                oldCrownOpacity = 1.0
                oldCrownRotate = 0
            }
        }

        // 1.2 — crack/lightning flash + shake + shockwave
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            appState.sounds?.play(.crownShatter)
            appState.haptics?.heavy()
            withAnimation(.easeOut(duration: 0.18)) { crackOpacity = 0.9 }
            withAnimation(.easeIn(duration: 0.5).delay(0.18)) { crackOpacity = 0 }
            // shake
            withAnimation(.linear(duration: 0.06).repeatCount(6, autoreverses: true)) {
                screenShakeX = 12
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { screenShakeX = 0 }
            // shockwave
            shockwaveOpacity = 1
            withAnimation(.easeOut(duration: 0.8)) {
                shockwaveScale = 3.0
                shockwaveOpacity = 0
            }
            // shatter old crown
            oldCrownShatter = true
        }

        // 2.0 — avatar appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            appState.haptics?.confirm()
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                avatarScale = 1.0
                avatarOpacity = 1.0
            }
            // Continuous gentle bob on avatar
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                avatarBob = -6
                avatarTilt = 3
            }
        }

        // 2.4 — new crown descends onto avatar
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
                newCrownOpacity = 1
                newCrownScale = 1.0
                newCrownY = -90
                newCrownGlow = 1
            }
            appState.sounds?.play(.seaShantyHorn)
        }

        // 3.2 — banner unfurls
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) {
            appState.haptics?.success()
            withAnimation(.spring(response: 0.65, dampingFraction: 0.7)) {
                bannerOpacity = 1
                bannerOffset = 0
            }
        }

        // 3.8 — stats pop in
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
            appState.sounds?.play(.coinShower)
            withAnimation(.spring(response: 0.55, dampingFraction: 0.7)) {
                statsOpacity = 1
                statsScale = 1.0
            }
        }

        // 5.4 — fade out and complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.4) {
            withAnimation(.easeIn(duration: 0.45)) { vignette = 1 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.9) {
            triggerComplete()
        }
    }

    private func renderStatic() {
        vignette = 0
        oldCrownShatter = true
        avatarScale = 1
        avatarOpacity = 1
        newCrownOpacity = 1
        newCrownScale = 1
        newCrownY = -90
        newCrownGlow = 1
        bannerOpacity = 1
        bannerOffset = 0
        statsOpacity = 1
        statsScale = 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { triggerComplete() }
    }

    private func triggerComplete() {
        guard !doneTriggered else { return }
        doneTriggered = true
        onComplete()
    }
}
