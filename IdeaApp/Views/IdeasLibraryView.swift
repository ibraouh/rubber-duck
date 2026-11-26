import SwiftData
import SwiftUI

/// The Ideas tab: the ideas you've locked in, by the month you locked them.
struct IdeasLibraryView: View {
    @Environment(\.modelContext) private var context
    @Environment(CoachSession.self) private var session
    @Environment(\.theme) private var theme
    @Query(sort: \Idea.updatedAt, order: .reverse) private var ideas: [Idea]
    @State private var pendingDelete: Idea?

    private var sections: [(title: String, items: [Idea])] {
        monthSections(ideas.filter(\.isLocked)) { $0.lockedAt ?? $0.updatedAt }
    }

    var body: some View {
        List {
            ForEach(sections, id: \.title) { section in
                Section(theme.heading(section.title)) {
                    ForEach(section.items) { idea in
                        NavigationLink(value: AppRoute.idea(idea.id)) {
                            LockedIdeaRow(idea: idea)
                        }
                        .themedRow(theme)
                        .swipeActions { deleteButton(idea) }
                        .contextMenu { deleteButton(idea) }
                    }
                }
            }
        }
        // A warm glow, like a lit bulb, so it matches Home without copying it.
        .tabGlow([.yellow, .orange, .pink])
        .tracksTabBarMinimizing()
        .overlay {
            if sections.isEmpty {
                ContentUnavailableView(
                    "No ideas yet",
                    systemImage: "lightbulb",
                    description: Text("When an idea feels right, \(theme.words.lock.lowercased()) it from its conversation and it shows up here.")
                )
            }
        }
        .navigationTitle("Ideas")
        .deleteConfirmation(for: $pendingDelete) { session.delete($0, in: context) }
    }

    private func deleteButton(_ idea: Idea) -> some View {
        Button(role: .destructive) {
            if idea.descendants.isEmpty {
                withAnimation { session.delete(idea, in: context) }
            } else {
                pendingDelete = idea
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
        .tint(.red)
    }
}

private struct LockedIdeaRow: View {
    @Environment(\.theme) private var theme
    let idea: Idea

    var body: some View {
        HStack(spacing: 12) {
            IdeaEmoji(idea: idea, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(idea.displayTitle)
                    .font(.headline)
                    .foregroundStyle(theme.primaryText)
                if let oneLiner = idea.cardOneLiner {
                    Text(oneLiner)
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(2)
                }
                HStack(spacing: 6) {
                    Text(idea.categoryLabel)
                        .fontWeight(.semibold)
                        .foregroundStyle(idea.tint(in: theme))
                    if let parent = idea.parent {
                        Text("·")
                        Text("\(theme.words.branchedFrom) \(parent.displayTitle)")
                    }
                }
                .font(.caption)
                .foregroundStyle(theme.secondaryText.opacity(0.8))
                .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}
