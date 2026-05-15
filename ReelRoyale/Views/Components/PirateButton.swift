import SwiftUI

/// Primary CTA button. Now a thin wrapper around `GameButton(.primary | .destructive)` —
/// kept so existing callsites compile unchanged. New code should use `GameButton` directly.
struct PirateButton: View {
    let title: String
    var icon: String? = nil
    var fullWidth: Bool = false
    var isLoading: Bool = false
    var isDestructive: Bool = false
    let action: () -> Void

    var body: some View {
        GameButton(
            isDestructive ? .destructive : .primary,
            title,
            icon: icon,
            fullWidth: fullWidth,
            isLoading: isLoading,
            action: action
        )
    }
}

/// Tracks press state for any button. Used by `GameButton` and any legacy components
/// that still want to animate a custom label.
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
    .preferredColorScheme(.light)
}
