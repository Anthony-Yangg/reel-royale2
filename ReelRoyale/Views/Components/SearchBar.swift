import SwiftUI

/// Themed search bar.
struct PirateSearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search..."

    @Environment(\.reelTheme) private var theme
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.colors.text.muted)
                .font(.system(size: 14, weight: .semibold))
            TextField(placeholder, text: $text)
                .focused($isFocused)
                .textFieldStyle(.plain)
                .foregroundStyle(theme.colors.text.primary)
                .font(theme.typography.body)
                .submitLabel(.search)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(theme.colors.text.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, theme.spacing.s)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.button, style: .continuous)
                .fill(theme.colors.surface.elevatedAlt)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.button, style: .continuous)
                .strokeBorder(isFocused ? theme.colors.text.primary.opacity(0.35) : Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}

/// Themed filter chip used in segmented filter rows.
struct FilterChip: View {
    let label: String
    let icon: String?
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.reelTheme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(label)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(isSelected ? Color.white : theme.colors.text.primary)
            .padding(.horizontal, theme.spacing.s)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(isSelected ? theme.colors.text.primary : theme.colors.surface.elevated)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.black.opacity(isSelected ? 0 : 0.07), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
