import SwiftUI

/// Secondary outlined button — thin wrapper around `GameButton(.secondary)`.
/// Kept for compatibility; new code should use `GameButton` directly.
struct GhostButton: View {
    let title: String
    var icon: String? = nil
    var fullWidth: Bool = false
    let action: () -> Void

    var body: some View {
        GameButton(.secondary, title, icon: icon, fullWidth: fullWidth, action: action)
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
