import SwiftData
import SwiftUI

/// Prototype 3: Home. A dashboard of what needs you next: pick up where you left
/// off, ideas waiting on your answer, directions you haven't explored, and recently
/// locked ideas. Tabs: Home, Ideas (grouped by status), Search.
struct HomePrototype: View {
    @Environment(CoachSession.self) private var session
    @Environment(\.theme) private var theme

    @State private var homePath: [PrototypeRoute] = []
    @State private var ideasPath: [PrototypeRoute] = []
    @State private var searchPath: [PrototypeRoute] = []

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                NavigationStack(path: $homePath) {
                    HomeDashboard(path: $homePath)
                        .navigationDestination(for: PrototypeRoute.self) { PrototypeDestination(route: $0, path: $homePath) }
                }
            }
            Tab("Ideas", systemImage: "lightbulb") {
                NavigationStack(path: $ideasPath) {
                    IdeasByStatus(path: $ideasPath)
                        .navigationDestination(for: PrototypeRoute.self) { PrototypeDestination(route: $0, path: $ideasPath) }
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
}

private struct HomeDashboard: View {
    @Environment(\.modelContext) private var context
    @Environment(CoachSession.self) private var session
    @Environment(\.theme) private var theme
    @Query(sort: \Idea.updatedAt, order: .reverse) private var ideas: [Idea]
    @Binding var path: [PrototypeRoute]

    private var active: [Idea] { ideas.filter { !$0.isLocked } }
    private var current: Idea? { active.first }
    private var waiting: [Idea] {
        active.dropFirst().filter { session.state(of: $0) == .yourTurn }
    }
    private var toExplore: [(idea: Idea, suggestion: IdeaSuggestion)] {
        Array(active.flatMap { idea in idea.unexploredSuggestions.map { (idea, $0) } }.prefix(6))
    }
    private var recentlyLocked: [Idea] {
        ideas.filter(\.isLocked).sorted { ($0.lockedAt ?? .distantPast) > ($1.lockedAt ?? .distantPast) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if let current {
                    section("Pick up where you left off") {
                        PickUpCard(idea: current) { path.append(.idea(current.id)) }
                    }
                } else {
                    ContentUnavailableView {
                        Label(theme.words.emptyListTitle, systemImage: theme.symbols.idea)
                    } description: {
                        Text(theme.words.emptyListBody)
                    } actions: {
                        Button(theme.words.newIdea) { path.append(.newIdea) }
                            .buttonStyle(.borderedProminent)
                            .tint(theme.accent)
                    }
                    .padding(.top, 60)
                }

                if !waiting.isEmpty {
                    section("Waiting on you") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(waiting) { idea in
                                    WaitingCard(idea: idea) { path.append(.idea(idea.id)) }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.horizontal, -16)
                    }
                }

                if !toExplore.isEmpty {
                    section("Directions to explore") {
                        VStack(spacing: 12) {
                            ForEach(toExplore, id: \.suggestion.id) { item in
                                ExploreCard(idea: item.idea, suggestion: item.suggestion) {
                                    let child = session.explore(item.suggestion, from: item.idea, in: context)
                                    path.append(.idea(child.id))
                                }
                            }
                        }
                    }
                }

                if !recentlyLocked.isEmpty {
                    section("Recently \(theme.words.locked.lowercased())") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(recentlyLocked) { idea in
                                    LockedCard(idea: idea) { path.append(.idea(idea.id)) }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.horizontal, -16)
                    }
                }
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Settings", systemImage: "gearshape") { session.showSettings = true }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(theme.words.newIdea, systemImage: theme.symbols.newIdea) { path.append(.newIdea) }
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.title3.weight(.bold))
            content()
        }
    }
}

private struct PickUpCard: View {
    @Environment(\.theme) private var theme
    let idea: Idea
    var open: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(idea.displayTitle)
                    .font(.headline)
                Spacer()
                IdeaStateLabel(idea: idea)
                    .font(.caption.weight(.semibold))
            }
            Text(idea.preview)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(4)
            Button(action: open) {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(theme.accent)
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 24))
    }
}

private struct WaitingCard: View {
    let idea: Idea
    var open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 8) {
                Text(idea.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(idea.preview)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(width: 230, height: 140, alignment: .topLeading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}

private struct ExploreCard: View {
    @Environment(\.theme) private var theme
    let idea: Idea
    let suggestion: IdeaSuggestion
    var explore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(suggestion.title)
                .font(.headline)
            Text(suggestion.pitch)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            HStack {
                InlineLabel("\(theme.words.branchedFrom) \(idea.displayTitle)", systemImage: theme.symbols.branch)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                Spacer()
                Button(theme.words.explore, action: explore)
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .tint(theme.accent)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
    }
}

private struct LockedCard: View {
    @Environment(\.theme) private var theme
    let idea: Idea
    var open: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: theme.symbols.locked)
                    .foregroundStyle(theme.accent)
                Text(idea.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(idea.cardOneLiner ?? "")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(width: 200, height: 150, alignment: .topLeading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}

/// The Ideas tab: your turn first, then ones Claude is working on, then locked.
private struct IdeasByStatus: View {
    @Environment(CoachSession.self) private var session
    @Environment(\.theme) private var theme
    @Query(sort: \Idea.updatedAt, order: .reverse) private var ideas: [Idea]
    @Binding var path: [PrototypeRoute]

    var body: some View {
        let yourTurn = ideas.filter { session.state(of: $0) == .yourTurn }
        let working = ideas.filter { [.building, .thinking, .noReply].contains(session.state(of: $0)) }
        let locked = ideas.filter(\.isLocked)
        List {
            group("Your turn", yourTurn)
            group("In progress", working)
            group(theme.words.locked, locked)
        }
        .navigationTitle("Ideas")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(theme.words.newIdea, systemImage: theme.symbols.newIdea) { path.append(.newIdea) }
            }
        }
    }

    @ViewBuilder
    private func group(_ title: String, _ items: [Idea]) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(items) { idea in
                    NavigationLink(value: PrototypeRoute.idea(idea.id)) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(idea.displayTitle)
                                .font(.body.weight(.medium))
                            Text(idea.preview)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }
}
