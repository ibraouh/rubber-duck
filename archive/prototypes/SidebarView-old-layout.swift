import SwiftData
import SwiftUI

/// The history on the left: every idea, most recently active first. Ideas that
/// branched off another one say where they came from.
struct SidebarView: View {
    @Environment(\.modelContext) private var context
    @Environment(CoachSession.self) private var session
    @Environment(\.theme) private var theme
    @Query(sort: \Idea.updatedAt, order: .reverse) private var ideas: [Idea]
    @Binding var selectionID: Idea.ID?
    var onNewIdea: () -> Void

    var body: some View {
        Group {
            if ideas.isEmpty {
                emptyState
            } else {
                List(ideas, selection: $selectionID) { idea in
                    IdeaRow(idea: idea)
                        .listRowBackground(theme.isSystem ? nil : Color.clear)
                        // Delete is red everywhere in iOS, icon included. The role only
                        // reddens the text, and the theme's tint would color the icon.
                        .contextMenu {
                            Button("Delete", systemImage: "trash", role: .destructive) { delete(idea) }
                                .tint(.red)
                        }
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) { delete(idea) }
                                .tint(.red)
                        }
                }
                .scrollContentBackground(theme.isSystem ? .automatic : .hidden)
            }
        }
        .background(ThemeBackground())
        .navigationTitle(theme.words.sidebarTitle)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Settings", systemImage: "gearshape") { session.showSettings = true }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(theme.words.newIdea, systemImage: theme.symbols.newIdea, action: newIdea)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: theme.symbols.idea)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(theme.secondaryText)
            VStack(spacing: 8) {
                Text(theme.words.emptyListTitle)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.primaryText)
                Text(theme.words.emptyListBody)
                    .font(.body)
                    .foregroundStyle(theme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            Button(action: newIdea) {
                Label(theme.words.newIdea, systemImage: theme.symbols.newIdea)
                    .font(.headline)
                    .foregroundStyle(theme.onAccent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
            .tint(theme.accent)
            Spacer()
            Spacer()
        }
        .padding(32)
    }

    private func newIdea() {
        onNewIdea()
    }

    private func delete(_ idea: Idea) {
        if selectionID == idea.id { selectionID = nil }
        session.delete(idea, in: context)
    }
}

private struct IdeaRow: View {
    @Environment(CoachSession.self) private var session
    @Environment(\.theme) private var theme
    let idea: Idea

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: idea.isLocked ? theme.symbols.locked : theme.symbols.idea)
                .font(.subheadline)
                .foregroundStyle(idea.isLocked ? theme.accent : theme.secondaryText)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(idea.displayTitle)
                    .font(.body.weight(.medium))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
                subtitle
                    .font(.caption)
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(.vertical, 2)
    }

    private var subtitle: some View {
        HStack(spacing: 4) {
            if let parent = idea.parent {
                Image(systemName: theme.symbols.branch)
                    .imageScale(.small)
                Text("\(parent.isLocked ? theme.words.continuedFrom : theme.words.branchedFrom) \(parent.displayTitle)")
                    .lineLimit(1)
                Text("·")
            }
            status
                .layoutPriority(1)
        }
    }

    @ViewBuilder
    private var status: some View {
        if session.isBuildingIdeas(idea) {
            Text(theme.words.buildingIdeas + "…")
        } else if session.isThinking(idea) {
            Text(theme.words.thinking + "…")
        } else if idea.isLocked, let lockedAt = idea.lockedAt {
            Text("\(theme.words.locked) \(lockedAt.formatted(.relative(presentation: .named)))")
        } else {
            Text(idea.updatedAt, format: .relative(presentation: .named))
        }
    }
}
