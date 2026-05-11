import SwiftUI

/// Dramatic 6-second first-launch cinematic.
/// Storm clouds part → giant pirate ship bobs across with wave parallax →
/// crown rises from sea → logo flares in with shanty horn.
struct IntroCinematicView: View {
    let onComplete: () -> Void

    @Environment(\.reelTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var appState: AppState

    // Animated states
    @State private var skyOpacity: Double = 0
    @State private var sunOpacity: Double = 0
    @State private var farMountainsX: CGFloat = -60
    @State private var midSeaPhase: Double = 0
    @State private var nearSeaPhase: Double = 0.4
    @State private var foamPhase: Double = 0.8

    @State private var shipX: CGFloat = -460          // off-screen left
    @State private var shipRotation: Double = 0       // sway
    @State private var shipBob: CGFloat = 0           // wave bob
    @State private var sailScale: CGFloat = 0.92

    @State private var crownY: CGFloat = 280          // hidden below sea
    @State private var crownScale: CGFloat = 0.4
    @State private var crownGlow: Double = 0
    @State private var crownRotate: Double = -8

    @State private var titleOpacity: Double = 0
    @State private var titleScale: CGFloat = 0.7
    @State private var titleLetterSpacing: CGFloat = 18
    @State private var taglineOpacity: Double = 0
    @State private var taglineY: CGFloat = 14

    @State private var vignetteOpacity: Double = 1.0
    @State private var skipVisible: Bool = false
    @State private var doneTriggered = false

    var body: some View {
        ZStack {
            sky
            farMountains
            midSea
            nearSea
            ship
            crownRise
            foamLayer
            logoBlock
            vignette
            skipButton
        }
        .ignoresSafeArea()
        .onAppear { runSequence() }
    }

    // MARK: Parallax layers

    private var sky: some View {
        ZStack {
            // Deep stormy gradient
            LinearGradient(
                colors: [
                    Color(hex: 0x0A1822),                  // canvas
                    Color(hex: 0x14222F),
                    Color(hex: 0x1F4B6B),
                    Color(hex: 0xC97D3A).opacity(0.65)     // sunset glow on horizon
                ],
                startPoint: .top, endPoint: .bottom
            )
            // Sun disk
            Circle()
                .fill(
                    RadialGradient(
                        colors: [theme.colors.brand.crown, theme.colors.brand.brassGold.opacity(0.4), .clear],
                        center: .center, startRadius: 4, endRadius: 110
                    )
                )
                .frame(width: 220, height: 220)
                .offset(y: -60)
                .opacity(sunOpacity)
                .blur(radius: 0.5)
        }
        .opacity(skyOpacity)
    }

    private var farMountains: some View {
        // Distant pirate-island silhouettes
        TimelineView(.animation) { _ in
            Canvas { context, size in
                let baseY = size.height * 0.55
                var path = Path()
                path.move(to: CGPoint(x: -40 + farMountainsX, y: baseY))
                let peakHeights: [CGFloat] = [80, 130, 100, 160, 90, 140, 70]
                let stepWidth = (size.width + 80) / CGFloat(peakHeights.count)
                for (i, h) in peakHeights.enumerated() {
                    let x = CGFloat(i) * stepWidth + farMountainsX
                    path.addQuadCurve(
                        to: CGPoint(x: x + stepWidth, y: baseY),
                        control: CGPoint(x: x + stepWidth/2, y: baseY - h)
                    )
                }
                path.addLine(to: CGPoint(x: size.width + 80, y: size.height))
                path.addLine(to: CGPoint(x: -40, y: size.height))
                path.closeSubpath()
                context.fill(path, with: .linearGradient(
                    Gradient(colors: [Color(hex: 0x0B1F2C), Color(hex: 0x051018)]),
                    startPoint: CGPoint(x: 0, y: baseY - 100),
                    endPoint: CGPoint(x: 0, y: size.height)
                ))
            }
        }
        .opacity(skyOpacity)
    }

    private var midSea: some View {
        WaveBand(
            phase: midSeaPhase,
            amplitude: 14,
            frequency: 0.011,
            colors: [Color(hex: 0x103247), Color(hex: 0x0A2536)],
            bandHeightFraction: 0.42
        )
        .opacity(skyOpacity)
    }

    private var nearSea: some View {
        WaveBand(
            phase: nearSeaPhase,
            amplitude: 22,
            frequency: 0.014,
            colors: [Color(hex: 0x1B5572), Color(hex: 0x0E2D44)],
            bandHeightFraction: 0.30
        )
        .opacity(skyOpacity)
    }

    private var foamLayer: some View {
        FoamLayer(phase: foamPhase)
            .opacity(skyOpacity * 0.85)
    }

    // MARK: Ship

    private var ship: some View {
        PirateShipShape()
            .frame(width: 360, height: 280)
            .offset(x: shipX, y: -10 + shipBob)
            .rotationEffect(.degrees(shipRotation), anchor: .bottom)
            .scaleEffect(sailScale)
    }

    // MARK: Crown rising from sea

    private var crownRise: some View {
        ZStack {
            // Halo
            Circle()
                .fill(theme.colors.brand.crown.opacity(crownGlow * 0.45))
                .frame(width: 280, height: 280)
                .blur(radius: 32)
            Image(systemName: "crown.fill")
                .font(.system(size: 120, weight: .black))
                .foregroundStyle(
                    LinearGradient(
                        colors: [theme.colors.brand.crown, theme.colors.brand.brassGold, Color(hex: 0xA67328)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .shadow(color: theme.colors.brand.crown.opacity(0.8), radius: 18)
                .shadow(color: .black.opacity(0.7), radius: 4, x: 0, y: 4)
                .scaleEffect(crownScale)
                .rotationEffect(.degrees(crownRotate))
        }
        .offset(y: crownY)
        .opacity(crownGlow > 0 ? 1 : 0)
    }

    // MARK: Logo

    private var logoBlock: some View {
        VStack(spacing: 10) {
            Text("REEL ROYALE")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [theme.colors.brand.crown, theme.colors.brand.brassGold],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .tracking(titleLetterSpacing)
                .shadow(color: theme.colors.brand.crown.opacity(0.7), radius: 18)
                .shadow(color: .black.opacity(0.6), radius: 2, x: 0, y: 3)
                .scaleEffect(titleScale)
                .opacity(titleOpacity)
            Text("KING OF THE SEVEN SEAS")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.colors.brand.parchment)
                .tracking(4)
                .shadow(color: .black.opacity(0.7), radius: 2)
                .opacity(taglineOpacity)
                .offset(y: taglineY)
        }
        .offset(y: 140)
    }

    private var vignette: some View {
        // Initial black-out that fades in
        Color.black.opacity(vignetteOpacity)
            .ignoresSafeArea()
    }

    @ViewBuilder
    private var skipButton: some View {
        if skipVisible {
            VStack {
                HStack {
                    Spacer()
                    Button {
                        triggerComplete()
                    } label: {
                        HStack(spacing: 4) {
                            Text("Skip")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                            Image(systemName: "forward.fill")
                                .font(.system(size: 11, weight: .black))
                        }
                        .foregroundStyle(theme.colors.brand.parchment)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(Color.black.opacity(0.45))
                        )
                        .overlay(
                            Capsule().strokeBorder(theme.colors.brand.brassGold.opacity(0.55), lineWidth: 1)
                        )
                    }
                    .padding(.trailing, 18)
                    .padding(.top, 60)
                }
                Spacer()
            }
            .transition(.opacity)
        }
    }

    // MARK: Sequence

    private func runSequence() {
        guard !reduceMotion else { renderStatic(); return }

        appState.sounds?.play(.seaShantyHorn)

        // 0.0–1.0: vignette lifts, sky brightens, sun appears
        withAnimation(.easeOut(duration: 1.0)) {
            vignetteOpacity = 0
            skyOpacity = 1
        }
        withAnimation(.easeOut(duration: 1.4).delay(0.2)) {
            sunOpacity = 1
        }
        withAnimation(.easeInOut(duration: 22).repeatForever(autoreverses: false)) {
            farMountainsX = 0
        }

        // Continuous wave motion
        withAnimation(.linear(duration: 4.5).repeatForever(autoreverses: false)) {
            midSeaPhase = .pi * 2
        }
        withAnimation(.linear(duration: 3.2).repeatForever(autoreverses: false)) {
            nearSeaPhase = .pi * 2 + 0.4
        }
        withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
            foamPhase = .pi * 2 + 0.8
        }

        // 0.6–4.6: ship sails across, bobbing on waves
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            appState.haptics?.confirm()
            withAnimation(.easeInOut(duration: 4.0)) {
                shipX = 460
            }
            // Sway
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) {
                shipRotation = 6
            }
            // Bob
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                shipBob = -22
            }
            // Sail flap
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                sailScale = 1.04
            }
        }

        // 3.6: crown rises from sea
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
            appState.haptics?.heavy()
            appState.sounds?.play(.cannonBoom)
            withAnimation(.spring(response: 0.85, dampingFraction: 0.62)) {
                crownY = -10
                crownScale = 1.0
                crownGlow = 1
                crownRotate = 0
            }
        }
        // Crown idle wobble
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.3) {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                crownRotate = 4
            }
        }

        // 4.8: title flares in
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.7) {
            appState.haptics?.success()
            appState.sounds?.play(.brassChime)
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
                titleOpacity = 1
                titleScale = 1.0
                titleLetterSpacing = 3
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.25)) {
                taglineOpacity = 1
                taglineY = 0
            }
        }

        // 0.8: show skip
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeIn(duration: 0.4)) { skipVisible = true }
        }

        // 6.8: complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.6) {
            withAnimation(.easeIn(duration: 0.4)) {
                vignetteOpacity = 1
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 7.0) {
            triggerComplete()
        }
    }

    private func renderStatic() {
        skyOpacity = 1
        sunOpacity = 1
        vignetteOpacity = 0
        shipX = 0
        crownY = -10
        crownScale = 1
        crownGlow = 1
        titleOpacity = 1
        titleScale = 1
        titleLetterSpacing = 3
        taglineOpacity = 1
        taglineY = 0
        skipVisible = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { triggerComplete() }
    }

    private func triggerComplete() {
        guard !doneTriggered else { return }
        doneTriggered = true
        onComplete()
    }
}

// MARK: - Wave band

private struct WaveBand: View {
    let phase: Double
    let amplitude: CGFloat
    let frequency: CGFloat
    let colors: [Color]
    let bandHeightFraction: CGFloat   // 0...1, how tall this band is relative to screen height (anchored to bottom)

    var body: some View {
        TimelineView(.animation) { _ in
            Canvas { context, size in
                let bandTop = size.height * (1 - bandHeightFraction)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: bandTop))
                var x: CGFloat = 0
                while x <= size.width {
                    let y = bandTop + amplitude * CGFloat(sin(Double(x) * Double(frequency) + phase))
                    path.addLine(to: CGPoint(x: x, y: y))
                    x += 4
                }
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.closeSubpath()
                context.fill(path, with: .linearGradient(
                    Gradient(colors: colors),
                    startPoint: CGPoint(x: 0, y: bandTop),
                    endPoint: CGPoint(x: 0, y: size.height)
                ))
                // Highlight ridge
                var ridge = Path()
                x = 0
                ridge.move(to: CGPoint(x: 0, y: bandTop))
                while x <= size.width {
                    let y = bandTop + amplitude * CGFloat(sin(Double(x) * Double(frequency) + phase))
                    ridge.addLine(to: CGPoint(x: x, y: y))
                    x += 4
                }
                context.stroke(ridge, with: .color(Color.white.opacity(0.06)), lineWidth: 1.2)
            }
        }
    }
}

// MARK: - Foam layer

private struct FoamLayer: View {
    let phase: Double

    var body: some View {
        TimelineView(.animation) { _ in
            Canvas { context, size in
                let baseY = size.height * 0.72
                for i in 0..<14 {
                    let xOffset = CGFloat(i) * (size.width / 14)
                    let bob = 6 * CGFloat(sin(Double(i) * 0.7 + phase))
                    let rect = CGRect(x: xOffset, y: baseY + bob, width: 30, height: 4)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.18)))
                }
            }
        }
    }
}

// MARK: - Pirate Ship shape

private struct PirateShipShape: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            // Hull
            HullShape()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x6B4429), Color(hex: 0x3B2415)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: 280, height: 80)
                .overlay(
                    HullShape().stroke(Color(hex: 0x2A1808), lineWidth: 2.5)
                        .frame(width: 280, height: 80)
                )
                .shadow(color: .black.opacity(0.65), radius: 14, x: 0, y: 10)

            // Deck stripes / gun ports
            HStack(spacing: 16) {
                ForEach(0..<6, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(hex: 0xD89A4A))
                        .frame(width: 14, height: 10)
                        .overlay(
                            Circle()
                                .fill(Color(hex: 0x1A0D04))
                                .frame(width: 6, height: 6)
                        )
                }
            }
            .padding(.bottom, 28)

            // Mast
            Rectangle()
                .fill(Color(hex: 0x4A2E1D))
                .frame(width: 6, height: 200)
                .offset(y: -80)

            // Main sail (curved)
            SailShape()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xE8D9B0), Color(hex: 0xB89A6E), Color(hex: 0xE8D9B0)],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(width: 140, height: 110)
                .overlay(SailShape().stroke(Color(hex: 0x4A2E1D), lineWidth: 1.5).frame(width: 140, height: 110))
                .offset(x: 4, y: -150)
                .shadow(color: .black.opacity(0.4), radius: 6, x: -4, y: 2)

            // Top sail
            SailShape()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xC9A24B), Color(hex: 0x8F6D2D)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(width: 90, height: 70)
                .overlay(SailShape().stroke(Color(hex: 0x4A2E1D), lineWidth: 1.5).frame(width: 90, height: 70))
                .offset(x: 2, y: -228)

            // Crow's nest
            Rectangle()
                .fill(Color(hex: 0x4A2E1D))
                .frame(width: 28, height: 10)
                .offset(y: -260)

            // Pirate flag — jolly roger
            ZStack {
                Rectangle()
                    .fill(Color(hex: 0x0A0808))
                    .frame(width: 36, height: 24)
                Image(systemName: "skull.fill")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color(hex: 0xE8D9B0))
            }
            .offset(x: 18, y: -278)
        }
    }
}

private struct HullShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + 10, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - 10, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                       control: CGPoint(x: rect.maxX + 18, y: rect.maxY - 6))
        p.addQuadCurve(to: CGPoint(x: rect.minX + 10, y: rect.minY),
                       control: CGPoint(x: rect.minX - 18, y: rect.maxY - 6))
        p.closeSubpath()
        return p
    }
}

private struct SailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                       control: CGPoint(x: rect.midX, y: rect.minY - 6))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - 4, y: rect.maxY),
                       control: CGPoint(x: rect.maxX + 8, y: rect.midY))
        p.addQuadCurve(to: CGPoint(x: rect.minX + 4, y: rect.maxY),
                       control: CGPoint(x: rect.midX, y: rect.maxY + 14))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY),
                       control: CGPoint(x: rect.minX - 8, y: rect.midY))
        p.closeSubpath()
        return p
    }
}
