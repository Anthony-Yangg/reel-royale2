import SwiftUI

/// Round icon-only button — thin wrapper around `GameButton.icon(...)`.
/// Kept for compatibility; new code should use `GameButton.icon` directly.
struct IconButton: View {
    let systemName: String
    var size: CGFloat = 44
    var fillStyle: FillStyle = .elevated
    let action: () -> Void

    enum FillStyle {
        case elevated
        case ghost
        case brass

        fileprivate var gameButtonStyle: GameButton.IconStyle {
            switch self {
            case .elevated: return .elevated
            case .ghost:    return .ghost
            case .brass:    return .brass
            }
        }
    }

    var body: some View {
        GameButton.icon(systemName, size: size, style: fillStyle.gameButtonStyle, action: action)
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
    .preferredColorScheme(.light)
}
