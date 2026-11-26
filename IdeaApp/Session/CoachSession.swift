import Foundation
import Observation
import SwiftData

/// App-wide state for talking to the coach: which ideas are waiting on a reply,
/// errors per idea, and the API key. Keeping it here (not in a view) means a reply
/// still lands if you navigate away while it's thinking.
@Observable
final class CoachSession {
    struct Failure {
        var message: String
        var needsAPIKey: Bool
    }

    static let apiKeyAccount = "anthropic-api-key"

    private(set) var thinking: Set<PersistentIdentifier> = []
    private(set) var locking: Set<PersistentIdentifier> = []
    private(set) var failures: [PersistentIdentifier: Failure] = [:]
    /// Ideas waiting on their icon and category.
    private var naming: Set<PersistentIdentifier> = []
    private(set) var apiKey: String
    var showSettings = false

    /// Scripted `DemoCoach` replies instead of Claude, for screenshots and UI work.
    /// Debug builds only: debug scenarios turn it on, or launch with `-DemoReplies YES`.
    /// It's never saved, and the conversation shows a "not Claude" label while it's on.
    var isUsingDemoReplies: Bool = {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "DemoReplies")
        #else
        false
        #endif
    }()

    init() {
        apiKey = Keychain.string(for: Self.apiKeyAccount) ?? ""
    }

    var hasAPIKey: Bool { !apiKey.isEmpty }

    @discardableResult
    func saveAPIKey(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let saved = Keychain.set(trimmed, for: Self.apiKeyAccount)
        if saved { apiKey = trimmed }
        return saved
    }

    func isThinking(_ idea: Idea) -> Bool { thinking.contains(idea.persistentModelID) }

    /// True while the reply on its way is the set of ideas, so the app can say so.
    func isBuildingIdeas(_ idea: Idea) -> Bool { isThinking(idea) && Self.expectsIdeas(idea) }

    /// Worked out from the conversation itself, so it holds for retries and relaunches:
    /// the last message is the go-ahead after "ready", or you asked for ideas.
    private static func expectsIdeas(_ idea: Idea) -> Bool {
        guard let last = idea.sortedMessages.last, last.role == .user else { return false }
        return last.isHidden || last.text == Prompts.showIdeasMessage
    }

    func isLocking(_ idea: Idea) -> Bool { locking.contains(idea.persistentModelID) }
    func failure(for idea: Idea) -> Failure? { failures[idea.persistentModelID] }
    func isBusy(_ idea: Idea) -> Bool { isThinking(idea) || isLocking(idea) }

    // MARK: - Ideas

    /// Creates an idea from its first message. Until then a new idea is only a draft
    /// on screen, so nothing is saved if you back out without sending.
    func startIdea(with text: String, in context: ModelContext) -> Idea {
        let idea = Idea()
        context.insert(idea)
        append(.user, text: text.trimmingCharacters(in: .whitespacesAndNewlines), to: idea, in: context)
        requestReply(for: idea, in: context)
        return idea
    }


    /// Creates (or reopens) the child idea for a suggestion and starts its conversation.
    func explore(_ suggestion: IdeaSuggestion, from parent: Idea, in context: ModelContext) -> Idea {
        if let existing = parent.child(exploring: suggestion) { return existing }

        let child = Idea(title: suggestion.title)
        context.insert(child)
        child.parent = parent
        child.originTitle = suggestion.title
        child.originPitch = suggestion.pitch
        child.originKeeps = suggestion.keeps
        child.originFixes = suggestion.fixes
        append(.user, text: Prompts.branchSeed(parent: parent, suggestion: suggestion), isSeed: true, to: child, in: context)
        requestReply(for: child, in: context)
        return child
    }

    /// Locked ideas stay as they are; developing one further starts a child.
    func keepDeveloping(_ locked: Idea, in context: ModelContext) -> Idea {
        let child = Idea(title: locked.title)
        context.insert(child)
        child.parent = locked
        child.originTitle = locked.title
        child.originPitch = locked.cardOneLiner
        append(.user, text: Prompts.continueSeed(from: locked), isSeed: true, to: child, in: context)
        requestReply(for: child, in: context)
        return child
    }

    /// Deletes an idea along with every direction that branched from it, so no
    /// branch is left behind without the idea it came from.
    func delete(_ idea: Idea, in context: ModelContext) {
        for branch in idea.descendants {
            context.delete(branch)
        }
        context.delete(idea)
        try? context.save()
    }

    func togglePin(_ idea: Idea, in context: ModelContext) {
        idea.pinnedAt = idea.isPinned ? nil : .now
        try? context.save()
    }

    // MARK: - Conversation

    func send(_ text: String, in idea: Idea, context: ModelContext) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isBusy(idea) else { return }
        append(.user, text: trimmed, to: idea, in: context)
        requestReply(for: idea, in: context)
    }

    func retry(_ idea: Idea, in context: ModelContext) {
        requestReply(for: idea, in: context)
    }

    private func requestReply(for idea: Idea, in context: ModelContext) {
        let id = idea.persistentModelID
        failures[id] = nil
        thinking.insert(id)
        let history = idea.sortedMessages.map {
            TranscriptMessage(role: $0.role, text: $0.text, isSeed: $0.isSeed, rawContent: $0.rawContent)
        }
        let buildingIdeas = Self.expectsIdeas(idea)

        Task {
            do {
                let reply = try await makeCoach().reply(to: history, buildingIdeas: buildingIdeas)
                // Clear before applying: applying a "ready" reply starts the next request.
                thinking.remove(id)
                apply(reply, to: idea, in: context)
            } catch {
                thinking.remove(id)
                record(error, for: id)
            }
        }
    }

    private func apply(_ reply: CoachReply, to idea: Idea, in context: ModelContext) {
        let turn = reply.turn
        let followsGoAhead = idea.sortedMessages.last?.isHidden ?? false
        let message = append(.assistant, text: turn.message, to: idea, in: context)
        message.quickReplies = turn.kind == .ready ? [] : turn.quickReplies
        message.suggestions = turn.kind == .ideas ? turn.ideas : []
        message.rawContent = reply.rawContent

        if idea.title.isEmpty, !turn.title.isEmpty {
            idea.title = turn.title
        }
        idea.liked = turn.diagnosis.liked
        idea.broke = turn.diagnosis.broke
        idea.mustBeTrue = turn.diagnosis.mustBeTrue
        idea.confidence = turn.diagnosis.confidence
        idea.updatedAt = .now
        try? context.save()
        requestLookIfNeeded(for: idea, in: context)

        // The coach said it's putting ideas together: go ahead for it, out of sight,
        // so the ideas arrive as their own step. Never twice in a row.
        if turn.kind == .ready, !followsGoAhead {
            append(.user, text: Prompts.goAheadMessage, isHidden: true, to: idea, in: context)
            requestReply(for: idea, in: context)
        }
    }

    // MARK: - Icon and category

    /// Once an idea has a name, asks Claude for its emoji, color and category, in a
    /// separate small request so the conversation's history stays untouched. If it
    /// fails, the idea keeps its gray placeholder and the next reply tries again.
    /// Ideas from before icons existed get theirs the next time you reply in them.
    private func requestLookIfNeeded(for idea: Idea, in context: ModelContext) {
        let id = idea.persistentModelID
        guard idea.iconEmoji == nil, !idea.title.isEmpty, !naming.contains(id) else { return }
        naming.insert(id)
        let categories = IdeaCategories.available(from: (try? context.fetch(FetchDescriptor<Idea>())) ?? [])
        let request = Prompts.lookRequest(for: idea, categories: categories)

        Task {
            defer { naming.remove(id) }
            guard let look = try? await makeCoach().look(for: request) else { return }
            idea.apply(IdeaLook(
                emoji: IdeaLook.cleanEmoji(look.emoji),
                category: IdeaCategories.canonical(look.category, among: categories)
            ))
            try? context.save()
        }
    }

    // MARK: - Locking

    func lock(_ idea: Idea, in context: ModelContext) {
        let id = idea.persistentModelID
        guard !locking.contains(id) else { return }
        failures[id] = nil
        locking.insert(id)
        let request = Prompts.cardRequest(for: idea)

        Task {
            defer { locking.remove(id) }
            do {
                let card = try await makeCoach().card(for: request)
                if !card.title.isEmpty { idea.title = card.title }
                idea.cardOneLiner = card.oneLiner
                idea.cardWhyItWorks = card.whyItWorks
                idea.cardWhatItFixed = card.whatItFixed
                idea.cardOpenQuestions = card.openQuestions
                idea.cardNextStep = card.nextStep
                idea.status = .locked
                idea.lockedAt = .now
                idea.updatedAt = .now
                try? context.save()
            } catch {
                record(error, for: id)
            }
        }
    }

    // MARK: - Helpers

    private func makeCoach() throws -> any IdeaCoach {
        if isUsingDemoReplies { return DemoCoach() }
        guard hasAPIKey else { throw CoachError.missingAPIKey }
        return ClaudeCoach(apiKey: apiKey)
    }

    private func record(_ error: Error, for id: PersistentIdentifier) {
        if error is CancellationError { return }
        let needsKey = (error as? CoachError)?.needsAPIKey ?? false
        failures[id] = Failure(message: error.localizedDescription, needsAPIKey: needsKey)
    }

    @discardableResult
    private func append(_ role: MessageRole, text: String, isSeed: Bool = false, isHidden: Bool = false, to idea: Idea, in context: ModelContext) -> IdeaMessage {
        let next = ((idea.messages ?? []).map(\.index).max() ?? -1) + 1
        let message = IdeaMessage(index: next, role: role, text: text, isSeed: isSeed, isHidden: isHidden)
        context.insert(message)
        message.idea = idea
        idea.updatedAt = .now
        try? context.save()
        return message
    }
}
