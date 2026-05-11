import SwiftUI

/// Auto-scrolling horizontal marquee of recent dethrones.
struct DethroneTickerSection: View {
    let events: [DethroneEvent]
    let onTapEvent: (DethroneEvent) -> Void

    @Environment(\.reelTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.s) {
            SectionHeader(title: "Recent Dethrones", subtitle: "Live from the seas")
            if events.isEmpty {
                Text("Quiet waters... for now.")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.text.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, theme.spacing.s)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: theme.spacing.xs) {
                        ForEach(events) { event in
                            DethroneTickerItem(event: event) {
                                onTapEvent(event)
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
    }
}
