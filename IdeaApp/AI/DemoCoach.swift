import Foundation

/// Scripted replies for screenshots and UI work in debug builds, with no API calls
/// (see `CoachSession.isUsingDemoReplies`). Not a stand-in for the real coach.
final class DemoCoach: IdeaCoach {
    func reply(to history: [TranscriptMessage], buildingIdeas: Bool) async throws -> CoachReply {
        try await Task.sleep(for: .milliseconds(buildingIdeas ? 2500 : 900))

        let userTurns = history.filter { $0.role == .user }
        let answers = userTurns.filter { !$0.isSeed }.map(\.text)
            .filter { $0 != Prompts.goAheadMessage }
        let isBranch = userTurns.first?.isSeed == true
        let afterGoAhead = userTurns.last?.text == Prompts.goAheadMessage
        let realAnswers = answers.filter { $0 != Prompts.showIdeasMessage }

        let diagnosis = Diagnosis(
            liked: realAnswers.dropFirst(isBranch ? 0 : 1).first.map { [Self.phrase($0)] } ?? [],
            broke: realAnswers.dropFirst(isBranch ? 1 : 2).first.map { [Self.phrase($0)] } ?? [],
            mustBeTrue: realAnswers.dropFirst(isBranch ? 2 : 3).first.map { [Self.phrase($0)] } ?? [],
            confidence: realAnswers.count >= 3 ? .high : realAnswers.count >= 2 ? .medium : .low
        )
        let title = isBranch ? "" : Self.title(from: answers.first ?? "")

        let turn: CoachTurn
        if buildingIdeas {
            turn = CoachTurn(
                kind: .ideas,
                title: title,
                message: afterGoAhead ? "" : "Here are a few directions that keep what you liked and route around what broke.",
                quickReplies: ["The first one is close", "None of these click", "Mix the first two"],
                ideas: Self.ideas,
                diagnosis: diagnosis
            )
        } else if answers.count >= (isBranch ? 3 : 4) {
            turn = CoachTurn(
                kind: .ready,
                title: title,
                message: "Got it: you like the idea, but it grew past what you'd enjoy building. Let me put a few directions together.",
                quickReplies: [],
                ideas: [],
                diagnosis: diagnosis
            )
        } else {
            let script = isBranch ? Self.branchQuestions : Self.freshQuestions
            let step = min(isBranch ? answers.count : answers.count - 1, script.count - 1)
            let (question, replies) = script[max(step, 0)]
            turn = CoachTurn(
                kind: .question,
                title: title,
                message: question,
                quickReplies: replies,
                ideas: [],
                diagnosis: diagnosis
            )
        }

        let json = String(data: try JSONEncoder().encode(turn), encoding: .utf8) ?? ""
        let raw = try JSONSerialization.data(withJSONObject: [["type": "text", "text": json]])
        return CoachReply(turn: turn, rawContent: raw)
    }

    func card(for transcript: String) async throws -> IdeaCard {
        try await Task.sleep(for: .milliseconds(900))
        return IdeaCard(
            title: "",
            oneLiner: "A smaller, sharper version of the idea that keeps the part you cared about.",
            whyItWorks: "It starts from the part that excited you and leaves out the parts that turned it into a chore. It's small enough to try this month.",
            whatItFixed: "The original kept growing until it stopped being fun. This one has a clear edge.",
            openQuestions: ["Who would try it first?", "What does a good first week look like?"],
            nextStep: "Sketch the one screen that matters most and show it to two people."
        )
    }

    func look(for request: String) async throws -> IdeaLook {
        try await Task.sleep(for: .milliseconds(600))
        let isBranch = request.contains("It grew out of:")
        return isBranch
            ? IdeaLook(emoji: "🌱", category: "App")
            : IdeaLook(emoji: "🍽️", category: "App")
    }

    private static let freshQuestions: [(String, [String])] = [
        ("What made this feel exciting when you first had it?",
         ["It solved my own problem", "Nobody seemed to have done it", "It sounded fun to build"]),
        ("What changed? When did it start to feel wrong?",
         ["It got too big", "Someone already built it", "I stopped caring about the problem"]),
        ("If a version of this felt exciting again, what would have to be true?",
         ["I could finish it fast", "Real people would use it", "It would still be fun"]),
    ]

    private static let branchQuestions: [(String, [String])] = [
        ("What about this direction pulls you in most?",
         ["It's small enough to start", "It fixes what bugged me", "I can picture using it"]),
        ("Which part of it still feels vague?",
         ["Who it's for", "What the first version is", "Why anyone would care"]),
        ("Who would use this first, and what would they do on day one?",
         ["Me, honestly", "A few friends", "Not sure yet"]),
    ]

    private static let ideas: [IdeaSuggestion] = [
        IdeaSuggestion(
            title: "A smaller first version",
            pitch: "Strip it down to the one part you were most excited about and build only that, in a weekend.",
            keeps: "The part that excited you first",
            fixes: "It got too big to start"
        ),
        IdeaSuggestion(
            title: "Same problem, new crowd",
            pitch: "Keep the problem but aim it at a small group you know well, so you can test it with real people this month.",
            keeps: "The problem you cared about",
            fixes: "Not knowing who it's for"
        ),
        IdeaSuggestion(
            title: "Make the tool, not the product",
            pitch: "Build the tool you'd need to make the original idea, and see whether that's the more interesting thing.",
            keeps: "The building you enjoyed",
            fixes: "The parts that felt like a chore"
        ),
    ]

    private static func phrase(_ text: String) -> String {
        let words = text.split(separator: " ").prefix(6).joined(separator: " ")
        return words.trimmingCharacters(in: .punctuationCharacters)
    }

    private static func title(from text: String) -> String {
        let words = text
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
            .prefix(4)
            .joined(separator: " ")
        return words.prefix(1).uppercased() + words.dropFirst()
    }
}
