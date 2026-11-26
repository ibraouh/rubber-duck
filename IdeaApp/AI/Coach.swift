import Foundation

/// An alternative idea the coach offers once it understands what broke.
struct IdeaSuggestion: Codable, Hashable, Identifiable {
    var title: String
    var pitch: String
    var keeps: String
    var fixes: String

    var id: String { title + pitch }
}

struct Diagnosis: Codable, Hashable {
    var liked: [String]
    var broke: [String]
    var mustBeTrue: [String]
    var confidence: Confidence

    enum CodingKeys: String, CodingKey {
        case liked
        case broke
        case mustBeTrue = "must_be_true"
        case confidence
    }
}

/// One structured reply from the coach (see `Schemas.turn`).
struct CoachTurn: Codable {
    enum Kind: String, Codable {
        case question
        /// Heard enough; about to offer ideas. The app follows up for them.
        case ready
        case ideas
    }

    var kind: Kind
    var title: String
    var message: String
    var quickReplies: [String]
    var ideas: [IdeaSuggestion]
    var diagnosis: Diagnosis

    enum CodingKeys: String, CodingKey {
        case kind
        case title
        case message
        case quickReplies = "quick_replies"
        case ideas
        case diagnosis
    }
}

struct CoachReply {
    var turn: CoachTurn
    /// The assistant content blocks to store and replay verbatim.
    var rawContent: Data?
}

/// The card written when an idea is locked (see `Schemas.card`).
struct IdeaCard: Codable {
    var title: String
    var oneLiner: String
    var whyItWorks: String
    var whatItFixed: String
    var openQuestions: [String]
    var nextStep: String

    enum CodingKeys: String, CodingKey {
        case title
        case oneLiner = "one_liner"
        case whyItWorks = "why_it_works"
        case whatItFixed = "what_it_fixed"
        case openQuestions = "open_questions"
        case nextStep = "next_step"
    }
}

struct TranscriptMessage {
    var role: MessageRole
    var text: String
    var isSeed: Bool
    var rawContent: Data?
}

protocol IdeaCoach {
    /// `buildingIdeas` is true when the reply should be the ideas, which get more thought.
    func reply(to history: [TranscriptMessage], buildingIdeas: Bool) async throws -> CoachReply
    func card(for transcript: String) async throws -> IdeaCard
    /// Picks an idea's emoji, color and category (see `Prompts.lookRequest`).
    func look(for request: String) async throws -> IdeaLook
}

enum CoachError: LocalizedError {
    case missingAPIKey
    case http(status: Int, message: String)
    case refusal(String?)
    case truncated
    case badResponse(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Add your Claude API key in Settings to get replies."
        case let .http(status, message):
            switch status {
            case 401: "The API key was rejected. Check it in Settings."
            case 429: "Too many requests right now. Try again in a minute."
            case 529: "Claude is overloaded right now. Try again in a minute."
            default: "Request failed (\(status)). \(message)"
            }
        case let .refusal(explanation):
            explanation ?? "Claude declined to answer that one."
        case .truncated:
            "The reply was cut off. Try again."
        case let .badResponse(detail):
            detail
        }
    }

    var needsAPIKey: Bool {
        switch self {
        case .missingAPIKey: true
        case let .http(status, _): status == 401
        default: false
        }
    }
}
