import SwiftUI

/// Pirate-themed loading indicator: a rotating ship wheel.
struct ShipWheelSpinner: View {
    var size: CGFloat = 44

    @Environment(\.reelTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotation: Double = 0

    var body: some View {
        Image(systemName: "steeringwheel")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(theme.colors.brand.brassGold)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
            .accessibilityLabel("Loading")
    }
}

/// Standard inline loading view.
struct LoadingView: View {
    var message: String? = nil
    var size: Size = .medium

    enum Size {
        case small, medium, large
        var diameter: CGFloat {
            switch self { case .small: 28; case .medium: 44; case .large: 60 }
        }
    }

    @Environment(\.reelTheme) private var theme

    var body: some View {
        VStack(spacing: theme.spacing.m) {
            ShipWheelSpinner(size: size.diameter)
            if let message = message {
                Text(message)
                    .font(theme.typography.subhead)
                    .foregroundStyle(theme.colors.text.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Fullscreen loading overlay with dim scrim.
struct LoadingOverlay: View {
    let isLoading: Bool
    var message: String? = nil

    @Environment(\.reelTheme) private var theme

    var body: some View {
        if isLoading {
            ZStack {
                theme.colors.surface.scrim
                    .ignoresSafeArea()
                VStack(spacing: theme.spacing.m) {
                    ShipWheelSpinner(size: 56)
                    if let message = message {
                        Text(message)
                            .font(theme.typography.subhead)
                            .foregroundStyle(theme.colors.text.primary)
                    }
                }
                .padding(theme.spacing.xxl)
                .background(
                    RoundedRectangle(cornerRadius: theme.radius.card)
                        .fill(theme.colors.surface.elevated)
                )
                .reelShadow(theme.shadow.heroCard)
            }
            .transition(.opacity)
        }
    }
}

/// Pirate-themed empty state.
struct EmptyStateView: View {
    let icon: String
    let title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    @Environment(\.reelTheme) private var theme

    var body: some View {
        VStack(spacing: theme.spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(theme.colors.brand.tideTeal.opacity(0.6))
            Text(title)
                .font(theme.typography.title2)
                .foregroundStyle(theme.colors.text.primary)
                .multilineTextAlignment(.center)
            if let message = message {
                Text(message)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.text.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, theme.spacing.xxl)
            }
            if let actionTitle = actionTitle, let action = action {
                PirateButton(title: actionTitle, action: action)
                    .padding(.top, theme.spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(theme.spacing.m)
    }
}

/// Pirate-themed error state.
struct ErrorStateView: View {
    let message: String
    var retryAction: (() -> Void)? = nil

    @Environment(\.reelTheme) private var theme

    var body: some View {
        VStack(spacing: theme.spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(theme.colors.brand.coralRed)
            Text("The Tides Are Rough")
                .font(theme.typography.title2)
                .foregroundStyle(theme.colors.text.primary)
            Text(message)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.text.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, theme.spacing.xxl)
            if let retryAction = retryAction {
                PirateButton(title: "Try Again", icon: "arrow.clockwise", action: retryAction)
                    .padding(.top, theme.spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(theme.spacing.m)
    }
}

#Preview {
    VStack {
        LoadingView(message: "Charting nearby waters...")
        Divider().background(ReelTheme.default.colors.text.muted)
        EmptyStateView(
            icon: "fish",
            title: "No Catches Yet",
            message: "Cast your line and claim your first spot.",
            actionTitle: "Log a Catch"
        ) {}
    }
    .background(ReelTheme.default.colors.surface.canvas)
    .environment(\.reelTheme, .default)
    .environmentObject(AppState.shared)
    .preferredColorScheme(.dark)
}
