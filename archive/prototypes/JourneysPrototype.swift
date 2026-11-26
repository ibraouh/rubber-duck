import SwiftData
import SwiftUI

/// Prototype 1: Journeys. An idea and every direction that branched from it are
/// one journey. Tabs: Ideas, Locked, Search. A Continue bar sits above the tab bar,
/// like Music's mini-player.
struct JourneysPrototype: View {
    @Environment(CoachSession.self) private var session
    @Environment(\.theme) private var theme
    @Query(sort: \Idea.updatedAt, order: .reverse) private var ideas: [Idea]

    private enum TabID: Hashable { case ideas, locked, search }
    @State private var tab: TabID = .ideas
    @State private var ideasPath: [PrototypeRoute] = []
    @State private var lockedPath: [PrototypeRoute] = []
    @State private var searchPath: [PrototypeRoute] = []

    private var journeys: [Idea] {
        ideas.filter { $0.parent == nil }.sorted { $0.journeyActivity > $1.journeyActivity }
    }

    var body: some View {
        TabView(selection: $tab) {
            Tab("Ideas", systemImage: "lightbulb", value: TabID.ideas) {
                NavigationStack(path: $ideasPath) {
                    journeyList
                        .navigationDestination(for: PrototypeRoute.self) { PrototypeDestination(route: $0, path: $ideasPath) }
                }
            }
            Tab(theme.words.locked, systemImage: theme.symbols.lock, value: TabID.locked) {
                NavigationStack(path: $lockedPath) {
                    LockedIdeasList()
                        .navigationDestination(for: PrototypeRoute.self) { PrototypeDestination(route: $0, path: $lockedPath) }
                }
            }
            Tab(value: TabID.search, role: .search) {
                NavigationStack(path: $searchPath) {
                    IdeaSearchList()
                        .navigationDestination(for: PrototypeRoute.self) { PrototypeDestination(route: $0, path: $searchPath) }
                }
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            ContinueBar(idea: ideas.first { !$0.isLocked }) { idea in
                tab = .ideas
                ideasPath = idea.map { [.idea($0.id)] } ?? [.newIdea]
            }
        }
    }

    private var journeyList: some View {
        List(journeys) { root in
            let directions = root.descendantsWithDepth.map(\.idea)
            NavigationLink(value: directions.isEmpty ? PrototypeRoute.idea(root.id) : .journey(root.id)) {
                JourneyRow(root: root, directions: directions)
            }
        }
        .overlay {
            if journeys.isEmpty {
                ContentUnavailableView(theme.words.emptyListTitle, systemImage: theme.symbols.idea,
                                       description: Text(theme.words.emptyListBody))
            }
        }
        .navigationTitle("Ideas")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Settings", systemImage: "gearshape") { session.showSettings = true }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(theme.words.newIdea, systemImage: theme.symbols.newIdea) { ideasPath.append(.newIdea) }
            }
        }
    }
}

private struct JourneyRow: View {
    @Environment(\.theme) private var theme
    let root: Idea
    let directions: [Idea]

    var body: some View {
        let latest = root.latestInJourney
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(root.displayTitle)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text(listDate(root.journeyActivity))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !directions.isEmpty {
                HStack(spacing: 10) {
                    InlineLabel("\(directions.count) direction\(directions.count == 1 ? "" : "s")", systemImage: theme.symbols.branch)
                    let locked = ([root] + directions).filter(\.isLocked).count
                    if locked > 0 {
                        InlineLabel("\(locked) \(theme.words.locked.lowercased())", systemImage: theme.symbols.locked)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                if latest !== root {
                    Text(latest.displayTitle)
                        .lineLimit(1)
                    Text("·")
                }
                IdeaStateLabel(idea: latest)
                    .labelStyle(.titleOnly)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

/// One journey as a map: where it started, then every direction it took.
struct JourneyView: View {
    @Environment(\.theme) private var theme
    let root: Idea

    var body: some View {
        List {
            Section {
                if let first = root.visibleMessages.first(where: { $0.role == .user }) {
                    Text(first.text)
                        .font(.body)
                        .italic()
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Where it started")
            }

            Section("Directions") {
                NavigationLink(value: PrototypeRoute.idea(root.id)) {
                    JourneyNodeRow(idea: root, depth: 0)
                }
                ForEach(root.descendantsWithDepth, id: \.idea.id) { node in
                    NavigationLink(value: PrototypeRoute.idea(node.idea.id)) {
                        JourneyNodeRow(idea: node.idea, depth: node.depth)
                    }
                }
            }
        }
        .navigationTitle(root.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct JourneyNodeRow: View {
    @Environment(\.theme) private var theme
    let idea: Idea
    let depth: Int

    var body: some View {
        HStack(spacing: 10) {
            if depth > 0 {
                Image(systemName: "arrow.turn.down.right")
                    .foregroundStyle(.tertiary)
                    .padding(.leading, CGFloat(depth - 1) * 18)
            }
            Image(systemName: idea.isLocked ? theme.symbols.locked : theme.symbols.idea)
                .foregroundStyle(idea.isLocked ? theme.accent : .secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(idea.displayTitle)
                    .font(.body.weight(depth == 0 ? .semibold : .regular))
                    .lineLimit(1)
                IdeaStateLabel(idea: idea)
                    .labelStyle(.titleOnly)
                    .font(.caption)
            }
        }
        .padding(.vertical, 2)
    }
}

/// The bar above the tab bar: jump back into the latest conversation.
struct ContinueBar: View {
    @Environment(\.theme) private var theme
    let idea: Idea?
    var open: (Idea?) -> Void

    var body: some View {
        Button {
            open(idea)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: idea == nil ? theme.symbols.newIdea : theme.symbols.idea)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(idea?.displayTitle ?? theme.words.newIdea)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if let idea {
                        IdeaStateLabel(idea: idea)
                            .labelStyle(.titleOnly)
                            .font(.caption)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
