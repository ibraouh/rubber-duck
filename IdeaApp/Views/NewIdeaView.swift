import SwiftData
import SwiftUI

/// The page for a brand-new idea. It's only a draft: the idea is saved when you
/// send the first message, and leaving without sending discards it.
struct NewIdeaView: View {
    @Environment(\.modelContext) private var context
    @Environment(CoachSession.self) private var session
    @Environment(\.theme) private var theme
    var onCreated: (Idea) -> Void

    @State private var draft = ""
    @FocusState private var composerFocused: Bool

    var body: some View {
        ScrollView {
            FirstPromptView()
                .padding(.horizontal, 16)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(ThemeBackground())
        .safeAreaBar(edge: .bottom) {
            ComposerBar(draft: $draft, focus: $composerFocused, isBusy: false, onSend: start)
                .frame(maxWidth: 760)
        }
        .navigationTitle(theme.words.newIdea)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { composerFocused = true }
    }

    private func start(_ text: String) {
        let idea = session.startIdea(with: text, in: context)
        draft = ""
        onCreated(idea)
    }
}
