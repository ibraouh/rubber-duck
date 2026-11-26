import SwiftData
import SwiftUI

/// Home: every journey (an idea and the directions that branched from it),
/// pinned ones first, then by when you last worked on them, like Notes.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(CoachSession.self) private var session
    @Environment(\.theme) private var theme
    @Query(sort: \Idea.updatedAt, order: .reverse) private var ideas: [Idea]
    @Binding var path: [AppRoute]
    @State private var pendingDelete: Idea?

    private var journeys: [Idea] { ideas.filter { $0.parent == nil } }

    private var sections: [(title: String, items: [Idea])] {
        let pinned = journeys.filter(\.isPinned)
            .sorted { ($0.pinnedAt ?? .distantPast) > ($1.pinnedAt ?? .distantPast) }
        let rest = journeys.filter { !$0.isPinned }
            .sorted { $0.journeyActivity > $1.journeyActivity }
        return (pinned.isEmpty ? [] : [("Pinned", pinned)]) + dateSections(rest, by: \.journeyActivity)
    }

    var body: some View {
        List {
            ForEach(sections, id: \.title) { section in
                Section(theme.heading(section.title)) {
                    ForEach(section.items) { root in
                        NavigationLink(value: root.descendants.isEmpty ? AppRoute.idea(root.id) : .journey(root.id)) {
                            JourneyRow(root: root)
                        }
                        .themedRow(theme)
                        .swipeActions(edge: .leading) {
                            pinButton(root)
                        }
                        .swipeActions(edge: .trailing) {
                            deleteButton(root)
                        }
                        .contextMenu {
                            pinButton(root)
                            deleteButton(root)
                        }
                    }
                }
            }
        }
        .tabGlow(glowColors)
        .tracksTabBarMinimizing()
        .overlay {
            if journeys.isEmpty {
                ContentUnavailableView {
                    Label(theme.words.emptyListTitle, systemImage: theme.symbols.idea)
                } description: {
                    Text(theme.words.emptyListBody)
                } actions: {
                    Button(theme.words.newIdea) { path.append(.newIdea) }
                        .buttonStyle(.borderedProminent)
                        .tint(theme.accent)
                }
            }
        }
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(theme.words.newIdea, systemImage: theme.symbols.newIdea) { path.append(.newIdea) }
            }
        }
        .deleteConfirmation(for: $pendingDelete) { session.delete($0, in: context) }
    }

    /// The glow behind the title takes the category colors of your latest
    /// journeys, and cool colors when they don't have any yet.
    private var glowColors: [Color] {
        var colors: [IdeaColor] = []
        for root in journeys.sorted(by: { $0.journeyActivity > $1.journeyActivity }) {
            if let color = root.categoryColor, !colors.contains(color) { colors.append(color) }
            if colors.count == 3 { break }
        }
        for fallback in [IdeaColor.teal, .indigo, .pink] where colors.count < 3 && !colors.contains(fallback) {
            colors.append(fallback)
        }
        return colors.map(\.color)
    }

    private func pinButton(_ root: Idea) -> some View {
        Button {
            withAnimation { session.togglePin(root, in: context) }
        } label: {
            Label(root.isPinned ? "Unpin" : "Pin", systemImage: root.isPinned ? "pin.slash" : "pin")
        }
        .tint(.orange)
    }

    private func deleteButton(_ root: Idea) -> some View {
        Button(role: .destructive) {
            requestDelete(root)
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .tint(.red)
    }

    /// Deleting a journey with branches asks first, since it takes them all.
    private func requestDelete(_ idea: Idea) {
        if idea.descendants.isEmpty {
            withAnimation { session.delete(idea, in: context) }
        } else {
            pendingDelete = idea
        }
    }
}

/// A journey on Home, in two lines: its emoji and title, then when you last
/// worked on it, its category, and how many directions and locked ideas it has.
private struct JourneyRow: View {
    @Environment(\.theme) private var theme
    let root: Idea

    var body: some View {
        HStack(spacing: 12) {
            IdeaEmoji(idea: root, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(root.displayTitle)
                    .font(.headline)
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    Text(listDate(root.journeyActivity))
                        .foregroundStyle(theme.primaryText.opacity(0.7))
                        .fixedSize()
                    Text("·")
                    // The category gives way first if the line runs out of room.
                    Text(root.categoryLabel)
                        .fontWeight(.semibold)
                        .foregroundStyle(root.tint(in: theme))
                        .lineLimit(1)
                    JourneyCounts(root: root)
                }
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(.vertical, 2)
    }
}

/// How many directions a journey has and how many of its ideas are locked, as
/// small icons with numbers. Shows nothing for a lone idea still being explored.
private struct JourneyCounts: View {
    @Environment(\.theme) private var theme
    let root: Idea

    var body: some View {
        let directions = root.descendants
        let locked = ([root] + directions).filter(\.isLocked).count
        if !directions.isEmpty || locked > 0 {
            HStack(spacing: 8) {
                Text("·")
                if !directions.isEmpty {
                    InlineLabel("\(directions.count)", systemImage: theme.symbols.branch)
                }
                if locked > 0 {
                    InlineLabel("\(locked)", systemImage: theme.symbols.locked)
                }
            }
            .fixedSize()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(root.progressSummary(theme))
        }
    }
}

extension View {
    /// Asks before deleting an idea that has branches, naming how many go with it.
    func deleteConfirmation(for idea: Binding<Idea?>, delete: @escaping (Idea) -> Void) -> some View {
        confirmationDialog(
            "Delete this idea?",
            isPresented: Binding(get: { idea.wrappedValue != nil }, set: { if !$0 { idea.wrappedValue = nil } }),
            titleVisibility: .visible,
            presenting: idea.wrappedValue
        ) { target in
            let count = target.descendants.count
            Button("Delete Idea and \(count) Direction\(count == 1 ? "" : "s")", role: .destructive) {
                withAnimation { delete(target) }
            }
        } message: { target in
            Text("“\(target.displayTitle)” and every direction that branched from it will be deleted on all your devices. This can't be undone.")
        }
    }
}
