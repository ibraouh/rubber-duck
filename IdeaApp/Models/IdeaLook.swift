import SwiftUI

/// The colors categories are drawn in: their labels and the glow behind the
/// titles on Home. System colors, so they look right in Light and Dark Mode.
enum IdeaColor: String, Codable, CaseIterable {
    case red, orange, yellow, green, mint, teal, cyan, blue, indigo, purple, pink, brown

    var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .teal: .teal
        case .cyan: .cyan
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .brown: .brown
        }
    }

    /// The color for text. System yellow is too light to read on white, so it's
    /// darkened in Light Mode.
    var textColor: Color {
        guard self == .yellow else { return color }
        return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? .systemYellow : UIColor(red: 0.72, green: 0.53, blue: 0, alpha: 1)
        })
    }
}

/// An idea's icon and category, picked by Claude once the idea has a name
/// (see `Schemas.look`).
struct IdeaLook: Codable {
    var emoji: String
    var category: String

    /// Shown on ideas that don't have a look yet.
    static let placeholderEmoji = "💡"
    static let uncategorized = "Uncategorized"

    /// Claude's emoji, if it's a single emoji; otherwise a lightbulb.
    static func cleanEmoji(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let emoji = trimmed.first { character in
            character.unicodeScalars.contains { $0.properties.isEmojiPresentation }
                || (character.unicodeScalars.count > 1 && character.unicodeScalars.first?.properties.isEmoji == true)
        }
        return emoji.map(String.init) ?? "💡"
    }
}

/// The categories Claude files ideas under. It picks from these plus any it has
/// made before, and makes a new one only when none of them fits.
enum IdeaCategories {
    /// The starting set, with what belongs in each (the descriptions are for Claude)
    /// and its color. Ideas in the same category always share a color.
    static let defaults: [(name: String, covers: String, color: IdeaColor)] = [
        ("App", "apps, websites, software and tools", .blue),
        ("Business", "startups, side businesses, services and things to sell", .indigo),
        ("Art", "drawing, painting, photography, crafts and visual design", .pink),
        ("Music", "songs, albums, instruments and playlists", .red),
        ("Writing", "stories, essays, books, newsletters and poems", .brown),
        ("Video", "films, YouTube, podcasts and other shows", .purple),
        ("Game", "video games, board games and puzzles", .teal),
        ("Food", "recipes, cooking, restaurants and drinks", .orange),
        ("Event", "parties, dinners, gatherings and trips with friends", .yellow),
        ("Travel", "trips, places to go and ways to explore", .cyan),
        ("Home", "home projects, decor, DIY and garden", .green),
        ("Learning", "skills to learn, courses and teaching", .mint),
        ("Gift", "presents and surprises for someone", .red),
        ("Life", "habits, routines, health, relationships and personal plans", .green),
    ]

    /// A category's color: fixed for the starting ones, and for ones Claude makes,
    /// picked from the name, so it's the same on every launch and device.
    /// Uncategorized ideas have none.
    static func color(for category: String?) -> IdeaColor? {
        guard let category, category != IdeaLook.uncategorized else { return nil }
        if let known = defaults.first(where: { $0.name.caseInsensitiveCompare(category) == .orderedSame }) {
            return known.color
        }
        let seed = category.lowercased().unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7fff_ffff }
        return IdeaColor.allCases[seed % IdeaColor.allCases.count]
    }

    /// The defaults first, then the ones Claude has made, alphabetically.
    static func available(from ideas: [Idea]) -> [String] {
        let defaultNames = defaults.map(\.name)
        let made = Set(ideas.compactMap(\.category))
            .filter { name in !defaultNames.contains { $0.caseInsensitiveCompare(name) == .orderedSame } }
            .sorted()
        return defaultNames + made
    }

    /// Reuses an existing category's spelling when Claude's answer matches one
    /// apart from case, spacing or a trailing "s".
    static func canonical(_ name: String, among available: [String]) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return IdeaLook.uncategorized }
        func key(_ text: String) -> String {
            var lowered = text.lowercased().trimmingCharacters(in: .whitespaces)
            if lowered.hasSuffix("s"), lowered.count > 3 { lowered.removeLast() }
            return lowered
        }
        return available.first { key($0) == key(trimmed) } ?? trimmed
    }
}
