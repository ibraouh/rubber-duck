import SwiftData
import SwiftUI

// Pieces shared by the layout prototypes. The prototypes are alternative app
// structures over the same data and the same conversation and card screens,
// switchable in Settings (debug builds), so they can be compared on real ideas.

/// The layouts being compared.
enum LayoutPrototype: String, CaseIterable, Identifiable {
    case current
    case journeys
    case chats
    case home

    var id: String { rawValue }

    var name: String {
        switch self {
        case .current: "Current (sidebar)"
        case .journeys: "1 · Journeys"
        case .chats: "2 · Chats"
        case .home: "3 · Home"
        }
    }

    static let storageKey = "layoutPrototype"
}

/// Where a prototype's navigation stacks can go.
enum PrototypeRoute: Hashable {
    case idea(Idea.ID)
    case journey(Idea.ID)
    case newIdea
}

/// Where an idea stands right now.
enum IdeaState {
    case building
    case thinking
    case yourTurn
    case noReply
    case locked
}

extension CoachSession {
    func state(of idea: Idea) -> IdeaState {
        if idea.isLocked { return .locked }
        if isBuildingIdeas(idea) { return .building }
        if isThinking(idea) { return .thinking }
        if idea.sortedMessages.last?.role == .assistant { return .yourTurn }
        return .noReply
    }
}

extension Idea {
    /// Messages a person would see: not the hidden go-ahead or the branch seed.
    var visibleMessages: [IdeaMessage] {
        sortedMessages.filter { !$0.isHidden && !$0.isSeed }
    }

    /// The idea a journey started from.
    var journeyRoot: Idea {
        var node = self
        while let parent = node.parent { node = parent }
        return node
    }

    /// Every idea that branched from this one, depth first, with its depth.
    var descendantsWithDepth: [(idea: Idea, depth: Int)] {
        sortedChildren.flatMap { child in
            [(child, 1)] + child.descendantsWithDepth.map { ($0.idea, $0.depth + 1) }
        }
    }

    /// Latest activity anywhere in the journey that starts here.
    var journeyActivity: Date {
        ([updatedAt] + descendantsWithDepth.map(\.idea.updatedAt)).max() ?? updatedAt
    }

    /// The most recently active idea in the journey that starts here.
    var latestInJourney: Idea {
        ([self] + descendantsWithDepth.map(\.idea)).max { $0.updatedAt < $1.updatedAt } ?? self
    }

    /// Suggestions from the latest set that haven't been explored yet.
    var unexploredSuggestions: [IdeaSuggestion] {
        guard let latest = sortedMessages.last(where: { !$0.suggestions.isEmpty }) else { return [] }
        return latest.suggestions.filter { child(exploring: $0) == nil }
    }

    /// A one-line preview of where the conversation is, like Messages shows.
    var preview: String {
        guard let last = visibleMessages.last else { return originPitch ?? "" }
        if last.role == .user { return "You: \(last.text)" }
        if !last.suggestions.isEmpty && last.text.isEmpty {
            return "\(last.suggestions.count) directions to explore"
        }
        return last.text
    }
}

/// Dates the way Messages lists them: a time today, then Yesterday, a weekday, a date.
func listDate(_ date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) { return date.formatted(date: .omitted, time: .shortened) }
    if calendar.isDateInYesterday(date) { return "Yesterday" }
    if let days = calendar.dateComponents([.day], from: date, to: .now).day, days < 7 {
        return date.formatted(.dateTime.weekday(.wide))
    }
    return date.formatted(date: .numeric, time: .omitted)
}

/// An icon and text with tight spacing, for secondary lines inside rows
/// (`Label` spaces them like a list row icon, which is too wide here).
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

/// A small status line: whose turn it is, or what the coach is doing.
struct IdeaStateLabel: View {
    @Environment(CoachSession.self) private var session
    @Environment(\.theme) private var theme
    let idea: Idea

    var body: some View {
        switch session.state(of: idea) {
        case .building:
            Label(theme.words.buildingIdeas, systemImage: theme.symbols.showIdeas)
                .foregroundStyle(theme.accent)
        case .thinking:
            Label(theme.words.thinking, systemImage: "ellipsis")
                .foregroundStyle(theme.secondaryText)
        case .yourTurn:
            Label("Your turn", systemImage: "circle.fill")
                .foregroundStyle(theme.accent)
        case .noReply:
            Label("No reply yet", systemImage: "exclamationmark.circle")
                .foregroundStyle(theme.secondaryText)
        case .locked:
            Label(theme.words.locked, systemImage: theme.symbols.locked)
                .foregroundStyle(theme.secondaryText)
        }
    }
}

/// Resolves a route to its screen. Opening another idea from inside a
/// conversation (a branch, a parent) pushes it onto the same stack.
struct PrototypeDestination: View {
    @Query private var ideas: [Idea]
    let route: PrototypeRoute
    @Binding var path: [PrototypeRoute]

    var body: some View {
        switch route {
        case let .idea(id):
            if let idea = ideas.first(where: { $0.id == id }) {
                IdeaDetailView(idea: idea, selectionID: pushIdea)
                    .id(id)
            } else {
                ContentUnavailableView("This idea is gone", systemImage: "questionmark.circle")
            }
        case let .journey(id):
            if let root = ideas.first(where: { $0.id == id }) {
                JourneyView(root: root)
            } else {
                ContentUnavailableView("This idea is gone", systemImage: "questionmark.circle")
            }
        case .newIdea:
            NewIdeaView { idea in
                if !path.isEmpty { path.removeLast() }
                path.append(.idea(idea.id))
            }
        }
    }

    private var pushIdea: Binding<Idea.ID?> {
        Binding(get: { nil }, set: { id in
            if let id { path.append(.idea(id)) }
        })
    }
}

/// The Locked tab: every idea that's been locked in, newest first.
struct LockedIdeasList: View {
    @Environment(\.theme) private var theme
    @Query(sort: \Idea.updatedAt, order: .reverse) private var ideas: [Idea]

    private var locked: [Idea] {
        ideas.filter(\.isLocked).sorted { ($0.lockedAt ?? .distantPast) > ($1.lockedAt ?? .distantPast) }
    }

    var body: some View {
        Group {
            if locked.isEmpty {
                ContentUnavailableView(
                    "Nothing locked yet",
                    systemImage: theme.symbols.lock,
                    description: Text("When an idea feels right, lock it in from the conversation and its card lands here.")
                )
            } else {
                List(locked) { idea in
                    NavigationLink(value: PrototypeRoute.idea(idea.id)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(idea.displayTitle)
                                .font(.headline)
                            if let oneLiner = idea.cardOneLiner {
                                Text(oneLiner)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            if let lockedAt = idea.lockedAt {
                                Text("\(theme.words.locked) \(listDate(lockedAt))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle(theme.words.locked)
    }
}

/// The Search tab: ideas whose title or conversation mentions the query.
struct IdeaSearchList: View {
    @Environment(\.theme) private var theme
    @Query(sort: \Idea.updatedAt, order: .reverse) private var ideas: [Idea]
    @State private var query = ""

    private var results: [(idea: Idea, snippet: String?)] {
        let needle = query.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return ideas.map { ($0, nil) } }
        return ideas.compactMap { idea in
            if idea.displayTitle.localizedCaseInsensitiveContains(needle) { return (idea, nil) }
            if let hit = idea.visibleMessages.first(where: { $0.text.localizedCaseInsensitiveContains(needle) }) {
                return (idea, hit.text)
            }
            return nil
        }
    }

    var body: some View {
        List(results, id: \.idea.id) { result in
            NavigationLink(value: PrototypeRoute.idea(result.idea.id)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.idea.displayTitle)
                        .font(.body.weight(.semibold))
                    Text(result.snippet ?? result.idea.preview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(.vertical, 2)
            }
        }
        .overlay {
            if results.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .navigationTitle("Search")
        .searchable(text: $query, prompt: "Ideas and conversations")
    }
}
