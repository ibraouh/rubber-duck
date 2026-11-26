import SwiftData
import SwiftUI

/// The saved result of locking an idea in.
struct IdeaCardView: View {
    @Environment(\.modelContext) private var context
    @Environment(CoachSession.self) private var session
    @Environment(\.theme) private var theme
    let idea: Idea
    @Binding var selectionID: Idea.ID?
    @Binding var showConversation: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if let oneLiner = idea.cardOneLiner {
                    Text(oneLiner)
                        .font(.title3)
                        .foregroundStyle(theme.primaryText)
                }

                CardSection(title: "Why it works", text: idea.cardWhyItWorks)
                CardSection(title: "What it fixed", text: idea.cardWhatItFixed)
                if !idea.cardOpenQuestions.isEmpty {
                    CardSection(title: "Open questions", bullets: idea.cardOpenQuestions)
                }
                CardSection(title: "Next step", text: idea.cardNextStep)

                if !idea.sortedChildren.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionTitle(text: "Developed further")
                        ForEach(idea.sortedChildren) { child in
                            Button {
                                selectionID = child.id
                            } label: {
                                Label(child.displayTitle, systemImage: theme.symbols.branch)
                                    .font(.subheadline.weight(.semibold))
                            }
                            .buttonStyle(.bordered).buttonBorderShape(.capsule)
                        }
                    }
                }

                Button {
                    selectionID = session.keepDeveloping(idea, in: context).id
                } label: {
                    Label(theme.words.keepDeveloping, systemImage: theme.symbols.branch)
                        .font(.headline)
                        .foregroundStyle(theme.onAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).tint(theme.accent)
                .padding(.top, 4)
            }
            .padding(22)
            .background(theme.surface, in: .rect(cornerRadius: 30))
            .overlay(RoundedRectangle(cornerRadius: 30).strokeBorder(theme.surfaceStroke, lineWidth: 0.5))
            .padding(16)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background(ThemeBackground())
        .navigationTitle(idea.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Conversation", systemImage: "bubble.left.and.bubble.right") {
                    showConversation = true
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            if idea.isSample {
                Label("Sample idea, not written by Claude", systemImage: "info.circle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)
            }
            if let parent = idea.parent {
                Button {
                    selectionID = parent.id
                } label: {
                    Label("\(theme.words.branchedFrom) \(parent.displayTitle)", systemImage: theme.symbols.branch)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                }
                .buttonStyle(.bordered).buttonBorderShape(.capsule)
            }
            IdeaEmoji(idea: idea, size: 56)
                .padding(.top, 4)
            HStack(spacing: 6) {
                Text(idea.categoryLabel)
                Text("·")
                Image(systemName: theme.symbols.locked)
                Text(theme.words.locked)
                if let lockedAt = idea.lockedAt {
                    Text("·")
                    Text(lockedAt, format: .dateTime.month().day().year())
                }
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(idea.tint(in: theme))
            Text(idea.displayTitle)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(theme.primaryText)
        }
    }
}

private struct SectionTitle: View {
    @Environment(\.theme) private var theme
    let text: String

    var body: some View {
        Text(theme.heading(text))
            .font(.footnote.weight(.semibold))
            .textCase(theme.headingTextCase)
            .foregroundStyle(theme.secondaryText)
    }
}

private struct CardSection: View {
    @Environment(\.theme) private var theme
    let title: String
    var text: String?
    var bullets: [String] = []

    var body: some View {
        if text != nil || !bullets.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                SectionTitle(text: title)
                if let text {
                    Text(text)
                        .foregroundStyle(theme.primaryText)
                }
                ForEach(bullets, id: \.self) { bullet in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•")
                        Text(bullet)
                    }
                    .foregroundStyle(theme.primaryText)
                }
            }
        }
    }
}
