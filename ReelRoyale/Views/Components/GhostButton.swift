import SwiftUI

/// Secondary outlined button. Brass-gold border on transparent background.
struct GhostButton: View {
    let title: String
    var icon: String? = nil
    var fullWidth: Bool = false
    let action: () -> Void

    @Environment(\.reelTheme) private var theme
    @EnvironmentObject private var appState: AppState
    @Environment(\.isEnabled) private var isEnabled
    @State private var isPressed = false

    var body: some View {
        Button {
            appState.haptics?.tap()
            action()
        } label: {
            HStack(spacing: theme.spacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(theme.typography.headline)
            }
            .foregroundStyle(theme.colors.brand.brassGold)
            .padding(.horizontal, theme.spacing.xl)
            .padding(.vertical, theme.spacing.s + 2)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 48)
            .background(
                RoundedRectangle(cornerRadius: theme.radius.button, style: .continuous)
                    .fill(theme.colors.surface.elevated.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radius.button, style: .continuous)
                    .strokeBorder(theme.colors.brand.brassGold.opacity(0.7), lineWidth: 1.25)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.4)
        }
        .buttonStyle(PressFeedbackStyle(isPressed: $isPressed))
        .animation(theme.motion.fast, value: isPressed)
    }
}

#Preview {
    VStack(spacing: 16) {
        GhostButton(title: "Open Map", icon: "map") {}
        GhostButton(title: "Full Width", fullWidth: true) {}
        GhostButton(title: "Disabled") {}.disabled(true)
    }
    .padding()
    .background(ReelTheme.default.colors.surface.canvas)
    .environment(\.reelTheme, .default)
    .environmentObject(AppState.shared)
    .preferredColorScheme(.dark)
}
