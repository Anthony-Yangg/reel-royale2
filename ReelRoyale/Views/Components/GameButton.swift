import SwiftUI

/// Single button API used across the app. Every tap = haptic + sound + scale, via `AppFeedback`.
///
/// Variants map onto the app's premium fishing-club visual language (black primary,
/// soft secondary, ghost text, coral destructive, circular icon) so we can collapse `PirateButton`,
/// `GhostButton`, and `IconButton` into one consistent surface.
///
/// Usage:
///   GameButton(.primary,    "Cast Your Claim", icon: "anchor", fullWidth: true) { ... }
///   GameButton(.secondary,  "Open Map", icon: "map") { ... }
///   GameButton(.ghost,      "Skip") { ... }
///   GameButton(.destructive,"Dethrone", icon: "crown.fill") { ... }
///   GameButton.icon("plus") { ... }
///   GameButton.icon("camera.fill", style: .ghost) { ... }
struct GameButton: View {
    enum Variant {
        case primary       // brass-gold gradient (CTA)
        case secondary     // gold-outlined ghost
        case ghost         // text-only secondary
        case destructive   // coral red
    }

    enum IconStyle {
        case elevated, ghost, brass
    }

    enum Shape {
        case capsule(title: String, icon: String?)
        case iconOnly(symbol: String, size: CGFloat, style: IconStyle)
    }

    let variant: Variant
    let shape: Shape
    var fullWidth: Bool = false
    var isLoading: Bool = false
    /// Feedback fired before `action`. Defaults to a sensible match per variant.
    var feedback: AppFeedback
    let action: () -> Void

    @Environment(\.reelTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @EnvironmentObject private var appState: AppState
    @State private var isPressed = false

    // MARK: - Convenience initialisers

    init(
        _ variant: Variant,
        _ title: String,
        icon: String? = nil,
        fullWidth: Bool = false,
        isLoading: Bool = false,
        feedback: AppFeedback? = nil,
        action: @escaping () -> Void
    ) {
        self.variant = variant
        self.shape = .capsule(title: title, icon: icon)
        self.fullWidth = fullWidth
        self.isLoading = isLoading
        self.feedback = feedback ?? Self.defaultFeedback(for: variant)
        self.action = action
    }

    static func icon(
        _ symbol: String,
        size: CGFloat = 44,
        style: IconStyle = .elevated,
        feedback: AppFeedback = .tap,
        action: @escaping () -> Void
    ) -> GameButton {
        GameButton(
            variant: .secondary,
            shape: .iconOnly(symbol: symbol, size: size, style: style),
            feedback: feedback,
            action: action
        )
    }

    private init(
        variant: Variant,
        shape: Shape,
        fullWidth: Bool = false,
        isLoading: Bool = false,
        feedback: AppFeedback,
        action: @escaping () -> Void
    ) {
        self.variant = variant
        self.shape = shape
        self.fullWidth = fullWidth
        self.isLoading = isLoading
        self.feedback = feedback
        self.action = action
    }

    // MARK: - Body

    var body: some View {
        Button {
            feedback.play(appState: appState)
            action()
        } label: {
            label
        }
        .buttonStyle(PressFeedbackStyle(isPressed: $isPressed))
        .animation(theme.motion.fast, value: isPressed)
        .disabled(isLoading)
    }

    @ViewBuilder
    private var label: some View {
        switch shape {
        case let .capsule(title, icon):
            capsuleLabel(title: title, icon: icon)
        case let .iconOnly(symbol, size, style):
            iconLabel(symbol: symbol, size: size, style: style)
        }
    }

    private func capsuleLabel(title: String, icon: String?) -> some View {
        HStack(spacing: theme.spacing.xs) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(capsuleForeground)
            } else {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: variant == .ghost ? 14 : 18, weight: .semibold))
                }
                Text(title)
                    .font(theme.typography.headline)
            }
        }
        .foregroundStyle(capsuleForeground)
        .padding(.horizontal, theme.spacing.xl)
        .padding(.vertical, theme.spacing.s + 2)
        .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: variant == .ghost ? 40 : 50)
        .background(capsuleBackground)
        .overlay(capsuleBorder)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .opacity(isEnabled ? 1.0 : 0.5)
        .modifier(ShadowIfNotGhost(variant: variant))
    }

    private func iconLabel(symbol: String, size: CGFloat, style: IconStyle) -> some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(iconForeground(style))
            .frame(width: size, height: size)
            .background(Circle().fill(iconBackground(style)))
            .overlay(
                Circle().strokeBorder(iconBorder(style), lineWidth: style == .ghost ? 1.25 : 0)
            )
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .opacity(isEnabled ? 1.0 : 0.5)
    }

    // MARK: - Capsule styling

    private var capsuleForeground: Color {
        switch variant {
        case .primary, .destructive: return theme.colors.text.onLight
        case .secondary, .ghost:     return theme.colors.text.primary
        }
    }

    @ViewBuilder
    private var capsuleBackground: some View {
        let r = theme.radius.button
        switch variant {
        case .primary:
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x202020), Color(hex: 0x050505)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
        case .destructive:
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [theme.colors.brand.coralRed, theme.colors.brand.coralRed.opacity(0.85)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
        case .secondary:
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(theme.colors.surface.elevated)
        case .ghost:
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .fill(Color.clear)
        }
    }

    @ViewBuilder
    private var capsuleBorder: some View {
        let r = theme.radius.button
        switch variant {
        case .primary:
            ZStack {
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.10), lineWidth: 1.5)
            }
        case .destructive:
            ZStack {
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .strokeBorder(theme.colors.brand.coralRed.opacity(0.35), lineWidth: 1.5)
                RoundedRectangle(cornerRadius: r, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                    .blendMode(.overlay)
            }
        case .secondary:
            RoundedRectangle(cornerRadius: r, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1.25)
        case .ghost:
            EmptyView()
        }
    }

    // MARK: - Icon styling

    private func iconForeground(_ style: IconStyle) -> Color {
        switch style {
        case .elevated: return theme.colors.text.primary
        case .ghost:    return theme.colors.text.primary
        case .brass:    return theme.colors.text.onLight
        }
    }

    private func iconBackground(_ style: IconStyle) -> AnyShapeStyle {
        switch style {
        case .elevated: return AnyShapeStyle(theme.colors.surface.elevatedAlt)
        case .ghost:    return AnyShapeStyle(Color.clear)
        case .brass:    return AnyShapeStyle(
            LinearGradient(
                colors: [Color(hex: 0x202020), Color(hex: 0x050505)],
                startPoint: .top, endPoint: .bottom
            )
        )
        }
    }

    private func iconBorder(_ style: IconStyle) -> Color {
        style == .ghost ? Color.black.opacity(0.12) : .clear
    }

    // MARK: - Defaults

    private static func defaultFeedback(for variant: Variant) -> AppFeedback {
        switch variant {
        case .primary:     return .confirm
        case .secondary:   return .tap
        case .ghost:       return .tap
        case .destructive: return .heavy
        }
    }
}

/// Drop card shadow on filled variants only (ghost/secondary stay flat).
private struct ShadowIfNotGhost: ViewModifier {
    let variant: GameButton.Variant
    @Environment(\.reelTheme) private var theme

    func body(content: Content) -> some View {
        switch variant {
        case .primary, .destructive:
            content.reelShadow(theme.shadow.card)
        case .secondary, .ghost:
            content
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        GameButton(.primary, "Cast Your Claim", icon: "anchor") {}
        GameButton(.secondary, "Open Map", icon: "map", fullWidth: true) {}
        GameButton(.ghost, "Skip") {}
        GameButton(.destructive, "Dethrone", icon: "crown.fill") {}
        HStack(spacing: 12) {
            GameButton.icon("plus") {}
            GameButton.icon("camera.fill", style: .ghost) {}
            GameButton.icon("anchor", style: .brass) {}
        }
        GameButton(.primary, "Loading", isLoading: true) {}
        GameButton(.primary, "Disabled") {}.disabled(true)
    }
    .padding()
    .background(ReelTheme.default.colors.surface.canvas)
    .environment(\.reelTheme, .default)
    .environmentObject(AppState.shared)
        .preferredColorScheme(.light)
}
