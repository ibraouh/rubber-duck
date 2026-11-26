import SwiftData
import SwiftUI

/// One journey as a map: where it started, then every direction it took.
struct JourneyView: View {
    @Environment(\.modelContext) private var context
    @Environment(CoachSession.self) private var session
    @Environment(\.theme) private var theme
    let root: Idea
    @Binding var path: [AppRoute]
    @State private var pendingDelete: Idea?

    var body: some View {
        List {
            if let first = root.visibleMessages.first(where: { $0.role == .user }) {
                Section("Where it started") {
                    Text(first.text)
                        .italic()
                        .foregroundStyle(theme.secondaryText)
                        .themedRow(theme)
                }
            }

            Section("Directions") {
                NavigationLink(value: AppRoute.idea(root.id)) {
                    JourneyNodeRow(idea: root, depth: 0)
                }
                .themedRow(theme)
                ForEach(root.descendantsWithDepth, id: \.idea.id) { node in
                    NavigationLink(value: AppRoute.idea(node.idea.id)) {
                        JourneyNodeRow(idea: node.idea, depth: node.depth)
                    }
                    .themedRow(theme)
                    .swipeActions { deleteButton(node.idea) }
                    .contextMenu { deleteButton(node.idea) }
                }
            }
        }
        .themedList(theme)
        .tracksTabBarMinimizing()
        .navigationTitle(root.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("More", systemImage: "ellipsis") {
                    Button {
                        session.togglePin(root, in: context)
                    } label: {
                        Label(root.isPinned ? "Unpin" : "Pin", systemImage: root.isPinned ? "pin.slash" : "pin")
                    }
                    Button(role: .destructive) {
                        pendingDelete = root
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)
                }
            }
        }
        .deleteConfirmation(for: $pendingDelete) { idea in
            if idea === root, !path.isEmpty { path.removeLast() }
            session.delete(idea, in: context)
        }
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

private struct JourneyNodeRow: View {
    @Environment(\.theme) private var theme
    let idea: Idea
    let depth: Int

    var body: some View {
        HStack(spacing: 10) {
            if depth > 0 {
                Image(systemName: "arrow.turn.down.right")
                    .foregroundStyle(theme.secondaryText.opacity(0.6))
                    .padding(.leading, CGFloat(depth - 1) * 18)
            }
            IdeaEmoji(idea: idea, size: depth == 0 ? 36 : 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(idea.displayTitle)
                    .font(.body.weight(depth == 0 ? .semibold : .regular))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
                Group {
                    if idea.isLocked {
                        InlineLabel("\(theme.words.locked) \(listDate(idea.lockedAt ?? idea.updatedAt))", systemImage: theme.symbols.locked)
                    } else {
                        Text(listDate(idea.updatedAt))
                    }
                }
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(.vertical, 2)
    }
}
