import SwiftData
import SwiftUI

struct ConversationView: View {
    @Environment(\.modelContext) private var context
    @Environment(CoachSession.self) private var session
    @Environment(\.theme) private var theme
    let idea: Idea
    @Binding var selectionID: Idea.ID?
    @Binding var showConversation: Bool

    @State private var draft = ""
    @State private var diagnosisExpanded = false
    @FocusState private var composerFocused: Bool

    private var messages: [IdeaMessage] { idea.sortedMessages }
    private var lastAssistant: IdeaMessage? { messages.last { $0.role == .assistant } }
    private var waitingOnReply: Bool { messages.last?.role == .user }

    /// The request's error, or, if the app quit while a reply was on its way, a
    /// note that it never arrived, so there's always a way to try again.
    private var failure: CoachSession.Failure? {
        if let failure = session.failure(for: idea) { return failure }
        guard waitingOnReply, !session.isBusy(idea) else { return nil }
        return CoachSession.Failure(message: "The reply didn't arrive.", needsAPIKey: false)
    }

    /// Quick answers to the coach's last message, shown under it until you reply.
    private var showsSuggestedReplies: Bool {
        guard !idea.isLocked, !session.isBusy(idea), !waitingOnReply, let lastAssistant else { return false }
        return !lastAssistant.quickReplies.isEmpty || offersIdeasButton
    }

    private var offersIdeasButton: Bool {
        lastAssistant?.suggestions.isEmpty ?? false
    }

    var body: some View {
        ScrollViewReader { scroller in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if session.isUsingDemoReplies {
                        Label("Scripted demo replies, not Claude", systemImage: "exclamationmark.bubble")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.secondaryText)
                            .frame(maxWidth: .infinity)
                    }
                    if idea.isSample {
                        Label("Sample idea. Claude didn't write these replies.", systemImage: "info.circle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.secondaryText)
                            .frame(maxWidth: .infinity)
                    }
                    if messages.isEmpty {
                        FirstPromptView()
                    }
                    ForEach(messages.filter { !$0.isHidden }) { message in
                        MessageRow(message: message, idea: idea, onExplore: explore, onOpen: open)
                            .id(message.id)
                    }
                    if session.isBuildingIdeas(idea) {
                        BuildingIdeasIndicator()
                    } else if session.isThinking(idea) {
                        TypingIndicator()
                    } else if showsSuggestedReplies, let lastAssistant {
                        SuggestedReplies(
                            replies: lastAssistant.quickReplies,
                            showIdeas: offersIdeasButton,
                            onSend: send
                        )
                    }
                    if let failure {
                        FailureRow(failure: failure, canRetry: waitingOnReply) {
                            session.retry(idea, in: context)
                        }
                    }
                    Color.clear.frame(height: 1).id(BottomAnchor.id)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .defaultScrollAnchor(.bottom)
            // Belt and braces: land on the latest message when the chat opens.
            .task { scroller.scrollTo(BottomAnchor.id, anchor: .bottom) }
            // When the message field grows or the keyboard opens, the scroll view's
            // bottom inset grows; keep the latest message just above it.
            .onScrollGeometryChange(for: CGFloat.self) { $0.contentInsets.bottom } action: { old, new in
                if new > old {
                    scroller.scrollTo(BottomAnchor.id, anchor: .bottom)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .background(ThemeBackground())
            // Real bars, so the conversation fades under them like it does in Messages.
            .safeAreaBar(edge: .top) {
                if idea.hasDiagnosis {
                    DiagnosisBar(idea: idea, expanded: $diagnosisExpanded)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)
                        .frame(maxWidth: 760)
                }
            }
            .safeAreaBar(edge: .bottom) {
                if !idea.isLocked {
                    ComposerBar(draft: $draft, focus: $composerFocused, isBusy: session.isBusy(idea), onSend: send)
                        .frame(maxWidth: 760)
                }
            }
            .onChange(of: messages.count) { scrollToBottom(scroller) }
            .onChange(of: session.isThinking(idea)) { scrollToBottom(scroller) }
            .onChange(of: composerFocused) {
                if composerFocused { scrollToBottom(scroller) }
            }
        }
        .overlay {
            if session.isLocking(idea) {
                LockingOverlay(label: theme.words.locking)
            }
        }
        .navigationTitle(idea.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // The icon sits by the title, like a contact's photo in Messages. It
            // appears once Claude has named the idea.
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    IdeaEmoji(idea: idea, size: 28)
                    Text(idea.displayTitle)
                        .font(.headline)
                        .foregroundStyle(theme.primaryText)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
            }
            .sharedBackgroundVisibility(.hidden)
            ToolbarItem(placement: .primaryAction) {
                if idea.isLocked {
                    Button {
                        showConversation = false
                    } label: {
                        Label(theme.words.locked, systemImage: theme.symbols.locked)
                    }
                } else {
                    Button {
                        composerFocused = false
                        session.lock(idea, in: context)
                    } label: {
                        Label(theme.words.lock, systemImage: theme.symbols.lock)
                    }
                    .disabled(!idea.hasReply || session.isBusy(idea))
                }
            }
        }
    }

    private func send(_ text: String) {
        session.send(text, in: idea, context: context)
        draft = ""
    }

    private func explore(_ suggestion: IdeaSuggestion) {
        selectionID = session.explore(suggestion, from: idea, in: context).id
    }

    private func open(_ other: Idea) {
        selectionID = other.id
    }

    private func scrollToBottom(_ scroller: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.25)) {
            scroller.scrollTo(BottomAnchor.id, anchor: .bottom)
        }
    }
}

private enum BottomAnchor {
    static let id = "bottom"
}

// MARK: - Rows

struct FirstPromptView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: theme.symbols.idea)
                .font(.title)
                .foregroundStyle(theme.accent)
            Text(theme.words.firstPromptTitle)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(theme.primaryText)
            Text(theme.words.firstPromptBody)
                .font(.body)
                .foregroundStyle(theme.secondaryText)
        }
        .padding(.top, 40)
        .padding(.horizontal, 4)
    }
}

struct MessageRow: View {
    @Environment(\.theme) private var theme
    let message: IdeaMessage
    let idea: Idea
    var onExplore: (IdeaSuggestion) -> Void
    var onOpen: (Idea) -> Void

    var body: some View {
        if message.isSeed {
            OriginBanner(idea: idea, onOpen: onOpen)
        } else if message.role == .user {
            MessageBubble(text: message.text, fromUser: true)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                // Ideas that follow the coach's own "ready" message come without a note.
                if !message.text.isEmpty {
                    MessageBubble(text: message.text, fromUser: false)
                }

                let suggestions = message.suggestions
                if !suggestions.isEmpty {
                    Text(theme.heading(theme.words.ideasHeading))
                        .font(.footnote.weight(.semibold))
                        .textCase(theme.headingTextCase)
                        .foregroundStyle(theme.secondaryText)
                        .padding(.top, 6)
                        .padding(.leading, 4)
                    ForEach(suggestions) { suggestion in
                        SuggestionCard(
                            suggestion: suggestion,
                            explored: idea.child(exploring: suggestion),
                            onExplore: { onExplore(suggestion) },
                            onOpen: onOpen
                        )
                    }
                }
            }
        }
    }
}

private struct SuggestionCard: View {
    @Environment(\.theme) private var theme
    let suggestion: IdeaSuggestion
    let explored: Idea?
    var onExplore: () -> Void
    var onOpen: (Idea) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(suggestion.title)
                .font(.headline)
                .foregroundStyle(theme.primaryText)
            Text(suggestion.pitch)
                .font(.subheadline)
                .foregroundStyle(theme.primaryText.opacity(0.85))
            VStack(alignment: .leading, spacing: 6) {
                TraitLine(symbol: theme.symbols.liked, color: theme.likedColor, label: theme.words.keeps, text: suggestion.keeps)
                TraitLine(symbol: theme.symbols.broke, color: theme.brokeColor, label: theme.words.fixes, text: suggestion.fixes)
            }
            HStack {
                Spacer()
                if let explored {
                    Button {
                        onOpen(explored)
                    } label: {
                        Label(theme.words.explored, systemImage: "arrow.right")
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button(action: onExplore) {
                        Label(theme.words.explore, systemImage: theme.symbols.branch)
                            .foregroundStyle(theme.onAccent)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .font(.subheadline.weight(.semibold))
            .buttonBorderShape(.capsule)
            .tint(theme.accent)
        }
        .padding(16)
        .background(theme.surface, in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(theme.surfaceStroke, lineWidth: 0.5))
    }
}

struct TraitLine: View {
    let symbol: String
    let color: Color
    let label: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 16)
            Text("\(Text(label).fontWeight(.semibold)) \(text)")
                .font(.footnote)
                .foregroundStyle(Color.primary.opacity(0.85))
        }
    }
}

/// Where a branched or continued idea came from, shown in place of the hidden seed message.
private struct OriginBanner: View {
    @Environment(\.theme) private var theme
    let idea: Idea
    var onOpen: (Idea) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let parent = idea.parent {
                Button {
                    onOpen(parent)
                } label: {
                    Label(
                        "\(parent.isLocked ? theme.words.continuedFrom : theme.words.branchedFrom) \(parent.displayTitle)",
                        systemImage: theme.symbols.branch
                    )
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
            }
            if let title = idea.originTitle {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.primaryText)
            }
            if let pitch = idea.originPitch, !pitch.isEmpty {
                Text(pitch)
                    .font(.subheadline)
                    .foregroundStyle(theme.primaryText.opacity(0.85))
            }
            if let keeps = idea.originKeeps {
                TraitLine(symbol: theme.symbols.liked, color: theme.likedColor, label: theme.words.keeps, text: keeps)
            }
            if let fixes = idea.originFixes {
                TraitLine(symbol: theme.symbols.broke, color: theme.brokeColor, label: theme.words.fixes, text: fixes)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: .rect(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(theme.surfaceStroke, lineWidth: 0.5))
        .padding(.top, 8)
    }
}

private struct FailureRow: View {
    @Environment(CoachSession.self) private var session
    @Environment(\.theme) private var theme
    let failure: CoachSession.Failure
    let canRetry: Bool
    var onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(failure.message, systemImage: "exclamationmark.triangle")
                .font(.subheadline)
                .foregroundStyle(theme.primaryText)
            HStack(spacing: 10) {
                if failure.needsAPIKey {
                    Button("Open Settings") { session.showSettings = true }
                }
                if canRetry {
                    Button("Try Again", action: onRetry)
                }
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: .rect(cornerRadius: 18))
    }
}

private struct LockingOverlay: View {
    @Environment(\.theme) private var theme
    let label: String

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text(label)
                .font(.headline)
                .foregroundStyle(theme.primaryText)
        }
        .padding(28)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }
}
