import SwiftData
import SwiftUI

/// Where a tab's navigation stack can go.
enum AppRoute: Hashable {
    case idea(Idea.ID)
    case journey(Idea.ID)
    case category(String)
    case newIdea
}

/// Resolves a route to its screen. Opening another idea from inside a
/// conversation (a branch, the idea it came from) pushes it onto the same stack.
struct IdeaDestination: View {
    @Query private var ideas: [Idea]
    let route: AppRoute
    @Binding var path: [AppRoute]

    var body: some View {
        switch route {
        case let .idea(id):
            if let idea = ideas.first(where: { $0.id == id }) {
                IdeaDetailView(idea: idea, selectionID: pushIdea)
                    .id(id)
                    // A conversation has its own bar for typing, so the tab bar steps
                    // aside, as it does in chat apps. It's back on every other screen.
                    .toolbar(.hidden, for: .tabBar)
            } else {
                gone
            }
        case let .journey(id):
            if let root = ideas.first(where: { $0.id == id }) {
                JourneyView(root: root, path: $path)
            } else {
                gone
            }
        case let .category(name):
            CategoryView(name: name)
        case .newIdea:
            NewIdeaView { idea in
                if !path.isEmpty { path.removeLast() }
                path.append(.idea(idea.id))
            }
            .toolbar(.hidden, for: .tabBar)
        }
    }

    private var gone: some View {
        ContentUnavailableView("This idea is gone", systemImage: "questionmark.circle")
    }

    private var pushIdea: Binding<Idea.ID?> {
        Binding(get: { nil }, set: { id in
            if let id { path.append(.idea(id)) }
        })
    }
}

/// Dates the way Messages and Notes list them: a time today, then Yesterday,
/// a weekday this week, then a date.
func listDate(_ date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) { return date.formatted(date: .omitted, time: .shortened) }
    if calendar.isDateInYesterday(date) { return "Yesterday" }
    if let days = calendar.dateComponents([.day], from: date, to: .now).day, days < 7 {
        return date.formatted(.dateTime.weekday(.wide))
    }
    return date.formatted(date: .numeric, time: .omitted)
}

/// Groups items into Notes-style date sections: Today, Yesterday,
/// Previous 7 Days, Previous 30 Days, Earlier.
func dateSections<Item>(_ items: [Item], by date: (Item) -> Date) -> [(title: String, items: [Item])] {
    let calendar = Calendar.current
    let weekAgo = calendar.date(byAdding: .day, value: -7, to: .now) ?? .distantPast
    let monthAgo = calendar.date(byAdding: .day, value: -30, to: .now) ?? .distantPast
    let buckets: [(String, (Date) -> Bool)] = [
        ("Today", { calendar.isDateInToday($0) }),
        ("Yesterday", { calendar.isDateInYesterday($0) }),
        ("Previous 7 Days", { $0 >= weekAgo }),
        ("Previous 30 Days", { $0 >= monthAgo }),
        ("Earlier", { _ in true }),
    ]
    var remaining = items
    var sections: [(String, [Item])] = []
    for (title, contains) in buckets {
        let inBucket = remaining.filter { contains(date($0)) }
        remaining.removeAll { contains(date($0)) }
        if !inBucket.isEmpty { sections.append((title, inBucket)) }
    }
    return sections
}

/// Groups items by month, newest first, the way Photos does: "November" for this
/// year, "November 2025" for earlier ones.
func monthSections<Item>(_ items: [Item], by date: (Item) -> Date) -> [(title: String, items: [Item])] {
    let calendar = Calendar.current
    let thisYear = calendar.component(.year, from: .now)
    var sections: [(title: String, items: [Item])] = []
    for item in items.sorted(by: { date($0) > date($1) }) {
        let day = date(item)
        let title = calendar.component(.year, from: day) == thisYear
            ? day.formatted(.dateTime.month(.wide))
            : day.formatted(.dateTime.month(.wide).year())
        if sections.last?.title == title {
            sections[sections.count - 1].items.append(item)
        } else {
            sections.append((title, [item]))
        }
    }
    return sections
}

/// An icon and text with tight spacing, for secondary lines inside rows
/// (`Label` spaces them like a list row icon, which is too wide there).
struct InlineLabel: View {
    let text: String
    let systemImage: String

    init(_ text: String, systemImage: String) {
        self.text = text
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .imageScale(.small)
            Text(text)
        }
    }
}

extension View {
    /// Lists keep iOS's own look in the System theme, and sit on the theme's
    /// background with card-colored rows in the others.
    func themedList(_ theme: Theme) -> some View {
        scrollContentBackground(theme.isSystem ? .automatic : .hidden)
            .background {
                if !theme.isSystem { ThemeBackground() }
            }
    }

    func themedRow(_ theme: Theme) -> some View {
        listRowBackground(theme.isSystem ? nil : theme.surface)
    }
}
