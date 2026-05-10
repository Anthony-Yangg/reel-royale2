import SwiftUI

/// The center ⚓ anchor button that hovers above the tab bar.
/// Tapping opens the Log Catch flow (Wave 1 = existing `LogCatchView`, Wave 4 = new 4-step flow).
struct CenterFAB: View {
    let action: () -> Void

    @Environment(\.reelTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var appState: AppState
    @State private var idleScale: CGFloat = 1.0
    @State private var isPressed = false

    var body: some View {
        Button {
            appState.haptics?.heavy()
            action()
        } label: {
            ZStack {
                // Outer halo (subtle gold glow)
                Circle()
                    .fill(theme.colors.brand.crown.opacity(0.3))
                    .frame(width: 86, height: 86)
                    .blur(radius: 14)

                // Brass gradient body
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [theme.colors.brand.crown, theme.colors.brand.brassGold],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 64, height: 64)
                    .overlay(
                        Circle().strokeBorder(theme.colors.brand.walnut, lineWidth: 2)
                    )
                    .overlay(
                        Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                            .blendMode(.overlay)
                    )

                // Anchor icon
                Image(systemName: "anchor")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(theme.colors.brand.walnut)
            }
            .scaleEffect(isPressed ? 0.92 : idleScale)
        }
        .buttonStyle(PressFeedbackStyle(isPressed: $isPressed))
        .animation(theme.motion.fast, value: isPressed)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: theme.motion.ambientDuration).repeatForever(autoreverses: true)) {
                idleScale = 1.04
            }
        }
        .accessibilityLabel("Log a catch")
    }
}

#Preview {
    CenterFAB(action: {})
        .padding()
        .background(ReelTheme.default.colors.surface.canvas)
        .environment(\.reelTheme, .default)
        .environmentObject(AppState.shared)
        .preferredColorScheme(.dark)
}
