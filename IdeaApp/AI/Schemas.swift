import Foundation

/// JSON schemas for structured outputs (`output_config.format`).
/// Every object needs `additionalProperties: false`; length and number limits aren't supported.
enum Schemas {
    private static let stringList: [String: Any] = [
        "type": "array",
        "items": ["type": "string"],
    ]

    private static let suggestion: [String: Any] = [
        "type": "object",
        "properties": [
            "title": ["type": "string", "description": "A 2-5 word name for the idea."],
            "pitch": ["type": "string", "description": "One or two sentences on what it is."],
            "keeps": ["type": "string", "description": "What it keeps from what they liked, in a few plain words."],
            "fixes": ["type": "string", "description": "What it fixes from what broke, in a few plain words."],
        ],
        "required": ["title", "pitch", "keeps", "fixes"],
        "additionalProperties": false,
    ]

    private static let diagnosis: [String: Any] = [
        "type": "object",
        "properties": [
            "liked": stringList,
            "broke": stringList,
            "must_be_true": stringList,
            "confidence": ["type": "string", "enum": ["low", "medium", "high"]],
        ],
        "required": ["liked", "broke", "must_be_true", "confidence"],
        "additionalProperties": false,
    ]

    static let turn: [String: Any] = [
        "type": "object",
        "properties": [
            "kind": ["type": "string", "enum": ["question", "ready", "ideas"]],
            "title": ["type": "string"],
            "message": ["type": "string"],
            "quick_replies": stringList,
            "ideas": ["type": "array", "items": suggestion],
            "diagnosis": diagnosis,
        ],
        "required": ["kind", "title", "message", "quick_replies", "ideas", "diagnosis"],
        "additionalProperties": false,
    ]

    static let card: [String: Any] = [
        "type": "object",
        "properties": [
            "title": ["type": "string"],
            "one_liner": ["type": "string"],
            "why_it_works": ["type": "string"],
            "what_it_fixed": ["type": "string"],
            "open_questions": stringList,
            "next_step": ["type": "string"],
        ],
        "required": ["title", "one_liner", "why_it_works", "what_it_fixed", "open_questions", "next_step"],
        "additionalProperties": false,
    ]

    static let look: [String: Any] = [
        "type": "object",
        "properties": [
            "emoji": ["type": "string", "description": "Exactly one emoji."],
            "category": ["type": "string"],
        ],
        "required": ["emoji", "category"],
        "additionalProperties": false,
    ]
}
