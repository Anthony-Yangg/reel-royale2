import SwiftUI

/// Cannonball-on-rope progress rail for the catch flow.
struct StepperRail: View {
    let totalSteps: Int           // typically 4
    let currentStep: Int          // 1...totalSteps
    let labels: [String]

    @Environment(\.reelTheme) private var theme

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.colors.surface.elevatedAlt)
                        .frame(height: 6)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [theme.colors.brand.crown, theme.colors.brand.brassGold],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: progressWidth(in: geo.size.width), height: 6)
                        .animation(theme.motion.standard, value: currentStep)
                    HStack(spacing: 0) {
                        ForEach(0..<totalSteps, id: \.self) { idx in
                            stepDot(index: idx)
                            if idx < totalSteps - 1 { Spacer() }
                        }
                    }
                    cannonball(in: geo.size.width)
                }
            }
            .frame(height: 32)
            HStack(spacing: 0) {
                ForEach(Array(labels.enumerated()), id: \.offset) { idx, label in
                    Text(label)
                        .font(.system(size: 11, weight: idx + 1 == currentStep ? .heavy : .semibold, design: .rounded))
                        .foregroundStyle(idx + 1 == currentStep ? theme.colors.brand.crown : theme.colors.text.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func progressWidth(in total: CGFloat) -> CGFloat {
        guard totalSteps > 1 else { return total }
        let stepWidth = total / CGFloat(totalSteps - 1)
        return min(total, stepWidth * CGFloat(currentStep - 1))
    }

    private func stepDot(index: Int) -> some View {
        let step = index + 1
        let isPast = step < currentStep
        let isCurrent = step == currentStep
        return Circle()
            .fill(isPast || isCurrent ? theme.colors.brand.crown : theme.colors.surface.elevated)
            .frame(width: 12, height: 12)
            .overlay(
                Circle().strokeBorder(theme.colors.brand.walnut, lineWidth: 1.5)
            )
    }

    private func cannonball(in totalWidth: CGFloat) -> some View {
        ZStack {
            Circle().fill(theme.colors.brand.walnut)
            Circle().fill(
                RadialGradient(colors: [theme.colors.text.primary.opacity(0.35), .clear], center: .topLeading, startRadius: 1, endRadius: 12)
            )
        }
        .frame(width: 22, height: 22)
        .overlay(
            Circle().strokeBorder(theme.colors.brand.brassGold, lineWidth: 1.5)
        )
        .offset(x: progressWidth(in: totalWidth) - 11, y: 0)
        .animation(theme.motion.standard, value: currentStep)
    }
}
