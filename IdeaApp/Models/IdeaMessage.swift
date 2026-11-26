import Foundation
import SwiftData

enum MessageRole: String, Codable {
    case user
    case assistant
}

/// One turn in an idea's conversation.
@Model
final class IdeaMessage {
    var index: Int = 0
    var createdAt: Date = Date()
    var roleRaw: String = MessageRole.user.rawValue

    /// What the app shows: the person's words, or the coach's question.
    var text: String = ""

    /// A hidden opening message the app writes when an idea is branched or continued.
    var isSeed: Bool = false

    /// A message the app sends for you that isn't shown, like the go-ahead
    /// after the coach says it's putting ideas together.
    var isHidden: Bool = false

    var quickReplies: [String] = []
    var suggestionsData: Data?

    /// The assistant's content blocks exactly as the API returned them (JSON).
    /// They're sent back unchanged on the next request, which keeps the model's
    /// earlier reasoning valid and the prompt cache warm.
    var rawContent: Data?

    var idea: Idea?

    init(index: Int, role: MessageRole, text: String, isSeed: Bool = false, isHidden: Bool = false) {
        self.index = index
        self.roleRaw = role.rawValue
        self.text = text
        self.isSeed = isSeed
        self.isHidden = isHidden
        self.createdAt = .now
    }
}

extension IdeaMessage {
    var role: MessageRole { MessageRole(rawValue: roleRaw) ?? .user }

    var suggestions: [IdeaSuggestion] {
        get {
            guard let suggestionsData else { return [] }
            return (try? JSONDecoder().decode([IdeaSuggestion].self, from: suggestionsData)) ?? []
        }
        set {
            suggestionsData = newValue.isEmpty ? nil : try? JSONEncoder().encode(newValue)
        }
    }
}
