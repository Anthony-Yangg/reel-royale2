import SwiftUI

/// Primary CTA button — brass-gold gradient, walnut border, press animation, haptic on tap.
struct PirateButton: View {
    let title: String
    var icon: String? = nil          // SF Symbol name
    var fullWidth: Bool = false
    var isLoading: Bool = false
    var isDestructive: Bool = false
    let action: () -> Void

    @Environment(\.reelTheme) private var theme
    @EnvironmentObject private var appState: AppState
    @Environment(\.isEnabled) private var isEnabled
    @State private var isPressed = false

    var body: some View {
        Button {
            appState.haptics?.confirm()
            action()
        } label: {
            HStack(spacing: theme.spacing.xs) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(theme.colors.text.onLight)
                } else {
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    Text(title)
                        .font(theme.typography.headline)
                }
            }
            .foregroundStyle(theme.colors.text.onLight)
            .padding(.horizontal, theme.spacing.xl)
            .padding(.vertical, theme.spacing.s + 2)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: theme.radius.button, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isDestructive
                                ? [theme.colors.brand.coralRed, theme.colors.brand.coralRed.opacity(0.85)]
                                : [theme.colors.brand.crown, theme.colors.brand.brassGold],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.button, style: .continuous)
                    .strokeBorder(theme.colors.brand.walnut, lineWidth: 1.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.button, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                    .blendMode(.overlay)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.5)
            .reelShadow(theme.shadow.card)
        }
        .buttonStyle(PressFeedbackStyle(isPressed: $isPressed))
        .animation(theme.motion.fast, value: isPressed)
        .disabled(isLoading)
    }
}

/// Tracks press state for any button.
struct PressFeedbackStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, new in
                isPressed = new
            }
    }
}

#Preview {
    VStack(spacing: 16) {
        PirateButton(title: "Cast Your Claim", icon: "anchor") {}
        PirateButton(title: "Full Width", fullWidth: true) {}
        PirateButton(title: "Loading", isLoading: true) {}
        PirateButton(title: "Dethrone", icon: "crown.fill", isDestructive: true) {}
        PirateButton(title: "Disabled") {}.disabled(true)
    }
    .padding()
    .background(ReelTheme.default.colors.surface.canvas)
    .environment(\.reelTheme, .default)
    .environmentObject(AppState.shared)
    .preferredColorScheme(.dark)
}
