import SwiftUI

/// Shows a locked idea's card, or the conversation for one still being explored.
struct IdeaDetailView: View {
    let idea: Idea
    @Binding var selectionID: Idea.ID?
    @State private var showConversation = false

    var body: some View {
        if idea.isLocked && !showConversation {
            IdeaCardView(idea: idea, selectionID: $selectionID, showConversation: $showConversation)
        } else {
            ConversationView(idea: idea, selectionID: $selectionID, showConversation: $showConversation)
        }
    }
}
