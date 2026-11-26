import Foundation
import SwiftData

enum IdeaStatus: String, Codable {
    case exploring
    case locked
}

enum Confidence: String, Codable, CaseIterable {
    case low
    case medium
    case high

    var level: Int {
        switch self {
        case .low: 1
        case .medium: 2
        case .high: 3
        }
    }
}

/// One idea being developed. Ideas form a tree: picking a suggestion creates a child,
/// and continuing a locked idea creates a child of the locked one.
///
/// Every stored property has a default so the store can sync through CloudKit later.
@Model
final class Idea {
    var title: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var statusRaw: String = IdeaStatus.exploring.rawValue

    // The diagnosis, rewritten by the coach after every reply.
    var liked: [String] = []
    var broke: [String] = []
    var mustBeTrue: [String] = []
    var confidenceRaw: String = Confidence.low.rawValue

    // Where this idea came from, when it was branched from a suggestion or a locked idea.
    var originTitle: String?
    var originPitch: String?
    var originKeeps: String?
    var originFixes: String?

    // The idea card, written when the idea is locked.
    var cardOneLiner: String?
    var cardWhyItWorks: String?
    var cardWhatItFixed: String?
    var cardOpenQuestions: [String] = []
    var cardNextStep: String?
    var lockedAt: Date?

    /// When it was pinned to the top of Home; nil if it isn't pinned.
    var pinnedAt: Date?

    // The emoji and category Claude picks once the idea has a name. Nil until then,
    // and on ideas from before icons existed, which show a lightbulb.
    var iconEmoji: String?
    var category: String?

    /// Mock data added for seeing the app full (see `SampleData`). Claude didn't
    /// write these conversations, and the app says so on them.
    var isSample: Bool = false

    var parent: Idea?

    @Relationship(deleteRule: .nullify, inverse: \Idea.parent)
    var children: [Idea]? = []

    @Relationship(deleteRule: .cascade, inverse: \IdeaMessage.idea)
    var messages: [IdeaMessage]? = []

    init(title: String = "") {
        self.title = title
        self.createdAt = .now
        self.updatedAt = .now
    }
}

extension Idea {
    var status: IdeaStatus {
        get { IdeaStatus(rawValue: statusRaw) ?? .exploring }
        set { statusRaw = newValue.rawValue }
    }

    var confidence: Confidence {
        get { Confidence(rawValue: confidenceRaw) ?? .low }
        set { confidenceRaw = newValue.rawValue }
    }

    var isLocked: Bool { status == .locked }

    var displayTitle: String { title.isEmpty ? "Untitled idea" : title }

    var sortedMessages: [IdeaMessage] {
        (messages ?? []).sorted { $0.index < $1.index }
    }

    var sortedChildren: [Idea] {
        (children ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    var isPinned: Bool { pinnedAt != nil }

    /// Ideas in the same category share its color.
    var categoryColor: IdeaColor? { IdeaCategories.color(for: category) }

    var categoryLabel: String { category ?? IdeaLook.uncategorized }

    func apply(_ look: IdeaLook) {
        iconEmoji = look.emoji
        category = look.category
    }

    /// Messages a person would see: not the hidden go-ahead or the branch seed.
    var visibleMessages: [IdeaMessage] {
        sortedMessages.filter { !$0.isHidden && !$0.isSeed }
    }

    /// Every idea that branched from this one, depth first, with how deep it sits.
    var descendantsWithDepth: [(idea: Idea, depth: Int)] {
        sortedChildren.flatMap { child in
            [(child, 1)] + child.descendantsWithDepth.map { ($0.idea, $0.depth + 1) }
        }
    }

    var descendants: [Idea] { descendantsWithDepth.map(\.idea) }

    /// The latest activity anywhere in the journey that starts here.
    var journeyActivity: Date {
        ([updatedAt] + descendants.map(\.updatedAt)).max() ?? updatedAt
    }

    /// A one-line preview of where the conversation is.
    var preview: String {
        guard let last = visibleMessages.last else { return originPitch ?? "" }
        if last.role == .user { return "You: \(last.text)" }
        if !last.suggestions.isEmpty && last.text.isEmpty {
            return "\(last.suggestions.count) directions to explore"
        }
        return last.text
    }

    var hasDiagnosis: Bool {
        !(liked.isEmpty && broke.isEmpty && mustBeTrue.isEmpty)
    }

    /// The child that was created by exploring this suggestion, if any.
    func child(exploring suggestion: IdeaSuggestion) -> Idea? {
        (children ?? []).first { $0.originTitle == suggestion.title && $0.originPitch == suggestion.pitch }
    }

    var hasReply: Bool {
        (messages ?? []).contains { $0.role == .assistant }
    }
}
