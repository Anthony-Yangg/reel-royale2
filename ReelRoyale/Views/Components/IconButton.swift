import SwiftUI

/// Round icon-only button. Used in nav bars, cards, etc.
struct IconButton: View {
    let systemName: String
    var size: CGFloat = 44
    var fillStyle: FillStyle = .elevated
    let action: () -> Void

    enum FillStyle {
        case elevated   // dark filled circle
        case ghost      // outlined transparent
        case brass      // gold filled
    }

    @Environment(\.reelTheme) private var theme
    @EnvironmentObject private var appState: AppState
    @State private var isPressed = false

    var body: some View {
        Button {
            appState.haptics?.tap()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(foregroundColor)
                .frame(width: size, height: size)
                .background(
                    Circle().fill(backgroundFill)
                )
                .overlay(
                    Circle().strokeBorder(borderColor, lineWidth: fillStyle == .ghost ? 1.25 : 0)
                )
                .scaleEffect(isPressed ? 0.92 : 1.0)
        }
        .buttonStyle(PressFeedbackStyle(isPressed: $isPressed))
        .animation(theme.motion.fast, value: isPressed)
    }

    private var foregroundColor: Color {
        switch fillStyle {
        case .elevated: return theme.colors.text.primary
        case .ghost:    return theme.colors.brand.brassGold
        case .brass:    return theme.colors.text.onLight
        }
    }

    private var backgroundFill: AnyShapeStyle {
        switch fillStyle {
        case .elevated:
            return AnyShapeStyle(theme.colors.surface.elevatedAlt)
        case .ghost:
            return AnyShapeStyle(Color.clear)
        case .brass:
            return AnyShapeStyle(
                LinearGradient(
                    colors: [theme.colors.brand.crown, theme.colors.brand.brassGold],
                    startPoint: .top, endPoint: .bottom
                )
            )
        }
    }

    private var borderColor: Color {
        switch fillStyle {
        case .ghost: return theme.colors.brand.brassGold.opacity(0.6)
        default: return .clear
        }
    }
}

#Preview {
    HStack(spacing: 16) {
        IconButton(systemName: "plus", fillStyle: .elevated) {}
        IconButton(systemName: "camera.fill", fillStyle: .ghost) {}
        IconButton(systemName: "anchor", fillStyle: .brass) {}
        IconButton(systemName: "magnifyingglass", size: 36, fillStyle: .elevated) {}
    }
    .padding()
    .background(ReelTheme.default.colors.surface.canvas)
    .environment(\.reelTheme, .default)
    .environmentObject(AppState.shared)
    .preferredColorScheme(.dark)
}
