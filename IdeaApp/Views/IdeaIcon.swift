import SwiftUI

/// An idea's emoji, picked by Claude once the idea has a name, shown on its own
/// at the start of a row, like Notion's page icons. (A colored circle, the emoji
/// in the title, a color dot and nothing at all were tried and dropped.) Ideas
/// without one yet show a lightbulb. Mono shows them in grayscale, to stay black
/// and white.
struct IdeaEmoji: View {
    @Environment(\.theme) private var theme
    let idea: Idea
    var size: CGFloat = 40

    var body: some View {
        Text(idea.emoji)
            .font(.system(size: size * 0.72))
            .frame(width: size, height: size)
            .grayscale(theme.isMonochrome ? 1 : 0)
            .animation(.snappy, value: idea.iconEmoji)
            .accessibilityHidden(true)
    }
}

/// A few ideas' emoji side by side, for a category row in Search.
struct IdeaEmojiStack: View {
    @Environment(\.theme) private var theme
    let ideas: [Idea]

    var body: some View {
        Text(ideas.prefix(3).map(\.emoji).joined(separator: " "))
            .font(.title3)
            .grayscale(theme.isMonochrome ? 1 : 0)
            .accessibilityHidden(true)
    }
}

/// An idea in a list: its emoji, title and one line under it.
struct IdeaRow: View {
    @Environment(\.theme) private var theme
    let idea: Idea
    var subtitle: String?

    var body: some View {
        HStack(spacing: 12) {
            IdeaEmoji(idea: idea, size: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(idea.displayTitle)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
                Text(subtitle ?? "\(idea.categoryLabel) · \(idea.progressSummary(theme))")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}

extension Idea {
    /// Where an idea and the directions under it stand: "3 directions · 1 locked",
    /// "Locked", or "No directions yet".
    func progressSummary(_ theme: Theme) -> String {
        let directions = descendants
        if directions.isEmpty {
            return isLocked ? theme.words.locked : "No directions yet"
        }
        let locked = ([self] + directions).filter(\.isLocked).count
        let count = "\(directions.count) direction\(directions.count == 1 ? "" : "s")"
        return locked == 0 ? count : "\(count) · \(locked) \(theme.words.locked.lowercased())"
    }

    /// The emoji Claude picked, or the placeholder.
    var emoji: String { iconEmoji ?? IdeaLook.placeholderEmoji }

    /// The idea's category color, for text like its category label. Gray when
    /// it's uncategorized, and in Mono.
    func tint(in theme: Theme) -> Color {
        guard !theme.isMonochrome, let color = categoryColor else { return theme.secondaryText }
        return color.textColor
    }
}

extension Theme {
    var isMonochrome: Bool { id == Theme.mono.id }
}
