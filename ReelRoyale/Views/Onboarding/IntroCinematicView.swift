import SwiftUI

/// Brief 2.5-second cinematic shown on first launch.
/// Treasure-map zoom-in + ship sail-by + logo reveal.
struct IntroCinematicView: View {
    let onComplete: () -> Void

    @Environment(\.reelTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var appState: AppState

    @State private var mapScale: CGFloat = 1.6
    @State private var mapRotation: Double = -8
    @State private var shipOffset: CGFloat = -300
    @State private var logoOpacity: Double = 0
    @State private var taglineOpacity: Double = 0
    @State private var skipVisible: Bool = false

    var body: some View {
        ZStack {
            // Parchment background
            theme.colors.surface.canvas.ignoresSafeArea()
            mapBackdrop
                .scaleEffect(mapScale)
                .rotationEffect(.degrees(mapRotation))
                .clipped()

            // Ship sail-by
            Image(systemName: "ferry.fill")
                .font(.system(size: 80, weight: .bold))
                .foregroundStyle(
                    LinearGradient(colors: [theme.colors.brand.walnut, theme.colors.brand.brassGold], startPoint: .top, endPoint: .bottom)
                )
                .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 4)
                .offset(x: shipOffset, y: 40)

            VStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 64, weight: .black))
                    .foregroundStyle(
                        LinearGradient(colors: [theme.colors.brand.crown, theme.colors.brand.brassGold], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: theme.colors.brand.crown.opacity(0.6), radius: 10)
                Text("REEL ROYALE")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(theme.colors.text.primary)
                    .tracking(3.0)
                Text("King of the Seven Seas")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.colors.brand.brassGold)
                    .tracking(2.5)
                    .opacity(taglineOpacity)
            }
            .opacity(logoOpacity)

            if skipVisible {
                VStack {
                    HStack {
                        Spacer()
                        Button("Skip") { onComplete() }
                            .foregroundStyle(theme.colors.text.secondary)
                            .padding(theme.spacing.m)
                    }
                    Spacer()
                }
            }
        }
        .onAppear { runSequence() }
    }

    private var mapBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [theme.colors.brand.deepSea, theme.colors.surface.canvas],
                startPoint: .top, endPoint: .bottom
            )
            // Faint compass rose
            Image(systemName: "compass.drawing")
                .resizable()
                .scaledToFit()
                .frame(width: 280, height: 280)
                .foregroundStyle(theme.colors.brand.brassGold.opacity(0.15))
        }
    }

    private func runSequence() {
        guard !reduceMotion else {
            mapScale = 1
            mapRotation = 0
            shipOffset = 0
            logoOpacity = 1
            taglineOpacity = 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { onComplete() }
            return
        }

        appState.sounds?.play(.seaShantyHorn)

        // 0.0–1.2 — map zoom out + rotate to upright
        withAnimation(.easeOut(duration: 1.2)) {
            mapScale = 1.0
            mapRotation = 0
        }
        // 0.3–1.4 — ship sails across
        withAnimation(.easeInOut(duration: 1.1).delay(0.3)) {
            shipOffset = 350
        }
        // 1.2 — logo + tagline fade in
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            appState.haptics?.confirm()
            withAnimation(.easeOut(duration: 0.4)) { logoOpacity = 1 }
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) { taglineOpacity = 1 }
        }
        // 2.5 — done
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
            withAnimation(.easeIn(duration: 0.3)) { logoOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { onComplete() }
        }
        // 0.4 — show skip
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            skipVisible = true
        }
    }
}
