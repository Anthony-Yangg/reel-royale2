import SwiftUI

/// Horizontal 4-step strip showing the path: Find Spot → Catch → Identify → Submit.
struct CatchPathStrip: View {
    let currentStep: Int            // 1...4 inclusive; 0 = none active yet
    let onTapStep: (Int) -> Void

    @Environment(\.reelTheme) private var theme

    private let steps: [(title: String, icon: String)] = [
        ("Find Spot",  "mappin.and.ellipse"),
        ("Catch",      "camera.fill"),
        ("Identify",   "sparkles"),
        ("Submit",     "anchor")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            SectionHeader(title: "Catch Path", subtitle: "From cast to crown")
            HStack(spacing: theme.spacing.xs) {
                ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                    stepTile(index: idx + 1, title: step.title, icon: step.icon)
                    if idx < steps.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(theme.colors.text.muted)
                    }
                }
            }
        }
    }

    private func stepTile(index: Int, title: String, icon: String) -> some View {
        let isCurrent = index == currentStep
        let isPast = index < currentStep
        return Button { onTapStep(index) } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(
                            isPast
                                ? AnyShapeStyle(LinearGradient(
                                    colors: [theme.colors.brand.crown, theme.colors.brand.brassGold],
                                    startPoint: .top, endPoint: .bottom))
                                : (isCurrent
                                   ? AnyShapeStyle(theme.colors.brand.tideTeal)
                                   : AnyShapeStyle(theme.colors.surface.elevatedAlt))
                        )
                        .frame(width: 44, height: 44)
                    Image(systemName: isPast ? "checkmark" : icon)
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(isPast ? theme.colors.brand.walnut : theme.colors.text.primary)
                }
                .overlay(
                    Circle()
                        .strokeBorder(
                            isCurrent ? theme.colors.brand.crown : Color.clear,
                            lineWidth: 2
                        )
                        .scaleEffect(1.08)
                )
                Text(title)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(isCurrent ? theme.colors.brand.crown : theme.colors.text.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Step \(index): \(title)")
    }
}
