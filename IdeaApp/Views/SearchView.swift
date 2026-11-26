import SwiftData
import SwiftUI

/// The Search tab. Before you type, it lists your categories to browse, the way
/// Health's Browse and Music's Search do; typing searches titles, categories and
/// conversations.
struct SearchView: View {
    @Environment(\.theme) private var theme
    @Query(sort: \Idea.updatedAt, order: .reverse) private var ideas: [Idea]
    @State private var query = ""

    private var needle: String { query.trimmingCharacters(in: .whitespaces) }

    private var results: [(idea: Idea, snippet: String?)] {
        ideas.compactMap { idea in
            if idea.displayTitle.localizedCaseInsensitiveContains(needle)
                || idea.categoryLabel.localizedCaseInsensitiveContains(needle) {
                return (idea, nil)
            }
            if let hit = idea.visibleMessages.first(where: { $0.text.localizedCaseInsensitiveContains(needle) }) {
                return (idea, hit.text)
            }
            return nil
        }
    }

    /// Every category with ideas in it, alphabetically, with Uncategorized last.
    private var categories: [(name: String, ideas: [Idea])] {
        let grouped = Dictionary(grouping: ideas, by: \.categoryLabel)
        return grouped
            .sorted { lhs, rhs in
                if lhs.key == IdeaLook.uncategorized { return false }
                if rhs.key == IdeaLook.uncategorized { return true }
                return lhs.key.localizedCompare(rhs.key) == .orderedAscending
            }
            .map { ($0.key, $0.value) }
    }

    var body: some View {
        List {
            if needle.isEmpty {
                if !categories.isEmpty {
                    Section(theme.heading("Categories")) {
                        ForEach(categories, id: \.name) { category in
                            NavigationLink(value: AppRoute.category(category.name)) {
                                CategoryRow(name: category.name, ideas: category.ideas)
                            }
                            .themedRow(theme)
                        }
                    }
                }
            } else {
                ForEach(results, id: \.idea.id) { result in
                    NavigationLink(value: AppRoute.idea(result.idea.id)) {
                        IdeaRow(idea: result.idea, subtitle: result.snippet)
                    }
                    .themedRow(theme)
                }
            }
        }
        .themedList(theme)
        .tracksTabBarMinimizing()
        .overlay {
            if !needle.isEmpty, results.isEmpty {
                ContentUnavailableView.search(text: needle)
            }
        }
        .navigationTitle("Search")
        .searchable(text: $query, prompt: "Ideas and categories")
    }
}

private struct CategoryRow: View {
    @Environment(\.theme) private var theme
    let name: String
    let ideas: [Idea]

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                Text("\(ideas.count) idea\(ideas.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
            }
            Spacer()
            IdeaEmojiStack(ideas: ideas)
        }
        .padding(.vertical, 2)
    }
}

/// Every idea filed under one category, most recent first.
struct CategoryView: View {
    @Environment(\.theme) private var theme
    @Query(sort: \Idea.updatedAt, order: .reverse) private var ideas: [Idea]
    let name: String

    private var filed: [Idea] { ideas.filter { $0.categoryLabel == name } }

    var body: some View {
        List(filed) { idea in
            NavigationLink(value: AppRoute.idea(idea.id)) {
                IdeaRow(idea: idea, subtitle: subtitle(for: idea))
            }
            .themedRow(theme)
        }
        .themedList(theme)
        .tracksTabBarMinimizing()
        .overlay {
            if filed.isEmpty {
                ContentUnavailableView("Nothing here anymore", systemImage: "tray")
            }
        }
        .navigationTitle(name)
    }

    private func subtitle(for idea: Idea) -> String {
        "\(listDate(idea.updatedAt)) · \(idea.progressSummary(theme))"
    }
}
