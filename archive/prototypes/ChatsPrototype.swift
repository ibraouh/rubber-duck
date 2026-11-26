import SwiftData
import SwiftUI

/// Prototype 2: Chats. Every conversation, newest first, in date sections, with a
/// preview of the last message and a blue dot when it's your turn, like Messages.
/// Tabs: Chats, Locked, Search.
struct ChatsPrototype: View {
    @Environment(\.modelContext) private var context
    @Environment(CoachSession.self) private var session
    @Environment(\.theme) private var theme
    @Query(sort: \Idea.updatedAt, order: .reverse) private var ideas: [Idea]

    @State private var chatsPath: [PrototypeRoute] = []
    @State private var lockedPath: [PrototypeRoute] = []
    @State private var searchPath: [PrototypeRoute] = []

    var body: some View {
        TabView {
            Tab("Chats", systemImage: "bubble.left.and.bubble.right") {
                NavigationStack(path: $chatsPath) {
                    chatList
                        .navigationDestination(for: PrototypeRoute.self) { PrototypeDestination(route: $0, path: $chatsPath) }
                }
            }
            Tab(theme.words.locked, systemImage: theme.symbols.lock) {
                NavigationStack(path: $lockedPath) {
                    LockedIdeasList()
                        .navigationDestination(for: PrototypeRoute.self) { PrototypeDestination(route: $0, path: $lockedPath) }
                }
            }
            Tab(role: .search) {
                NavigationStack(path: $searchPath) {
                    IdeaSearchList()
                        .navigationDestination(for: PrototypeRoute.self) { PrototypeDestination(route: $0, path: $searchPath) }
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
    }

    private var sections: [(title: String, ideas: [Idea])] {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: .now) ?? .distantPast
        let buckets: [(String, (Date) -> Bool)] = [
            ("Today", { calendar.isDateInToday($0) }),
            ("Yesterday", { calendar.isDateInYesterday($0) }),
            ("Previous 7 Days", { $0 >= weekAgo }),
            ("Earlier", { _ in true }),
        ]
        var remaining = ideas
        var result: [(String, [Idea])] = []
        for (title, matches) in buckets {
            let inBucket = remaining.filter { matches($0.updatedAt) }
            remaining.removeAll { matches($0.updatedAt) }
            if !inBucket.isEmpty { result.append((title, inBucket)) }
        }
        return result
    }

    private var chatList: some View {
        List {
            ForEach(sections, id: \.title) { section in
                Section(section.title) {
                    ForEach(section.ideas) { idea in
                        NavigationLink(value: PrototypeRoute.idea(idea.id)) {
                            ChatRow(idea: idea)
                        }
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                session.delete(idea, in: context)
                            }
                            .tint(.red)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if ideas.isEmpty {
                ContentUnavailableView(theme.words.emptyListTitle, systemImage: theme.symbols.idea,
                                       description: Text(theme.words.emptyListBody))
            }
        }
        .navigationTitle("Chats")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Settings", systemImage: "gearshape") { session.showSettings = true }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(theme.words.newIdea, systemImage: theme.symbols.newIdea) { chatsPath.append(.newIdea) }
            }
        }
    }
}

/// A conversation row in the style of Messages.
private struct ChatRow: View {
    @Environment(CoachSession.self) private var session
    @Environment(\.theme) private var theme
    let idea: Idea

    var body: some View {
        let state = session.state(of: idea)
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(state == .yourTurn ? theme.accent : .clear)
                .frame(width: 10, height: 10)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    if idea.isLocked {
                        Image(systemName: theme.symbols.locked)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(idea.displayTitle)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(listDate(idea.updatedAt))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Group {
                    switch state {
                    case .building, .thinking:
                        IdeaStateLabel(idea: idea)
                    default:
                        Text(idea.preview)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                if let parent = idea.parent {
                    InlineLabel("\(theme.words.branchedFrom) \(parent.displayTitle)", systemImage: theme.symbols.branch)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
