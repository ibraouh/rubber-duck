import SwiftUI
import UIKit

/// The words the app uses, so each theme can speak in its own vocabulary.
struct ThemeWords {
    var sidebarTitle: String
    var newIdea: String
    var emptyListTitle: String
    var emptyListBody: String
    var noSelectionTitle: String
    var noSelectionBody: String
    var firstPromptTitle: String
    var firstPromptBody: String
    var composerPlaceholder: String
    var thinking: String
    var showIdeas: String
    var buildingIdeas: String
    var ideasHeading: String
    var explore: String
    var explored: String
    var lock: String
    var locking: String
    var locked: String
    var keepDeveloping: String
    var diagnosis: String
    var confidence: String
    var liked: String
    var broke: String
    var mustBeTrue: String
    var keeps: String
    var fixes: String
    var branchedFrom: String
    var continuedFrom: String
}

struct ThemeSymbols {
    var newIdea: String
    var idea: String
    var lock: String
    var locked: String
    var branch: String
    var showIdeas: String
    var diagnosis: String
    var liked: String
    var broke: String
    var mustBeTrue: String
}

struct Theme: Identifiable, Equatable {
    enum HeadingStyle {
        /// As written, like iOS section headers.
        case plain
        /// All caps.
        case uppercase
        /// `// lowercase`, like a code comment.
        case code
    }

    let id: String
    let name: String
    let tagline: String
    /// `nil` follows the device's Light or Dark Mode.
    let colorScheme: ColorScheme?
    let fontDesign: Font.Design
    let headingStyle: HeadingStyle

    let accent: Color
    let onAccent: Color
    /// For switches, where a white accent would hide the knob.
    let controlTint: Color
    let primaryText: Color
    let secondaryText: Color
    let surface: Color
    let surfaceStroke: Color
    let userBubble: Color
    let userText: Color
    let likedColor: Color
    let brokeColor: Color
    let needsColor: Color

    let words: ThemeWords
    let symbols: ThemeSymbols

    static func == (lhs: Theme, rhs: Theme) -> Bool { lhs.id == rhs.id }

    /// Section headings in the theme's voice.
    func heading(_ text: String) -> String {
        switch headingStyle {
        case .plain, .uppercase: text
        case .code: "// " + text.lowercased()
        }
    }

    var headingTextCase: Text.Case? {
        headingStyle == .uppercase ? .uppercase : nil
    }

    /// The System theme keeps iOS's own list and background styling.
    var isSystem: Bool { id == Theme.system.id }

    static let all: [Theme] = [.system, .mono, .farm]

    static func named(_ id: String) -> Theme {
        all.first { $0.id == id } ?? .system
    }
}

extension Theme {
    /// Standard iOS: system colors and font, blue tint, and it follows Light and Dark Mode.
    static let system = Theme(
        id: "system",
        name: "System",
        tagline: "Standard iOS. Follows Light and Dark Mode.",
        colorScheme: nil,
        fontDesign: .default,
        headingStyle: .plain,
        accent: .blue,
        onAccent: .white,
        controlTint: .green,
        primaryText: .primary,
        secondaryText: .secondary,
        surface: Color(uiColor: .secondarySystemBackground),
        surfaceStroke: .clear,
        userBubble: .blue,
        userText: .white,
        likedColor: .green,
        brokeColor: .red,
        needsColor: .indigo,
        words: ThemeWords(
            sidebarTitle: "Ideas",
            newIdea: "New Idea",
            emptyListTitle: "No Ideas",
            emptyListBody: "Start with an idea that isn't quite there, or one you've gone off.",
            noSelectionTitle: "No Idea Selected",
            noSelectionBody: "Choose an idea, or start a new one.",
            firstPromptTitle: "What's the idea?",
            firstPromptBody: "Describe an idea that isn't quite there, or one you've gone off. I'll ask questions until I understand why, then suggest better ones.",
            composerPlaceholder: "Message",
            thinking: "Thinking",
            showIdeas: "Suggest Ideas",
            buildingIdeas: "Building suggestions",
            ideasHeading: "Suggestions",
            explore: "Explore",
            explored: "Exploring",
            lock: "Lock In",
            locking: "Writing the card…",
            locked: "Locked",
            keepDeveloping: "Keep Developing",
            diagnosis: "Diagnosis",
            confidence: "Confidence",
            liked: "What you like",
            broke: "What's not working",
            mustBeTrue: "What it needs",
            keeps: "Keeps",
            fixes: "Fixes",
            branchedFrom: "From",
            continuedFrom: "Continued from"
        ),
        symbols: ThemeSymbols(
            newIdea: "square.and.pencil",
            idea: "lightbulb",
            lock: "lock",
            locked: "lock.fill",
            branch: "arrow.triangle.branch",
            showIdeas: "sparkles",
            diagnosis: "stethoscope",
            liked: "hand.thumbsup",
            broke: "exclamationmark.triangle",
            mustBeTrue: "checklist"
        )
    )
}

extension Theme {
    /// Abe's brain: monochrome, with the coding font.
    static let mono = Theme(
        id: "mono",
        name: "Mono",
        tagline: "Black, white and a coding font.",
        colorScheme: .dark,
        fontDesign: .monospaced,
        headingStyle: .code,
        accent: Color(white: 0.94),
        onAccent: .black,
        controlTint: Color(white: 0.5),
        primaryText: Color(white: 0.94),
        secondaryText: Color(white: 0.58),
        surface: Color(white: 0.09),
        surfaceStroke: Color(white: 0.22),
        userBubble: Color(white: 0.94),
        userText: .black,
        likedColor: Color(white: 0.94),
        brokeColor: Color(white: 0.6),
        needsColor: Color(white: 0.8),
        words: ThemeWords(
            sidebarTitle: "~/ideas",
            newIdea: "new idea",
            emptyListTitle: "nothing here yet",
            emptyListBody: "start with an idea that isn't quite there, or one you've gone off.",
            noSelectionTitle: "no idea selected",
            noSelectionBody: "pick one from the list, or start a new one.",
            firstPromptTitle: "what's the idea?",
            firstPromptBody: "describe an idea that isn't quite there, or one you've gone off. i'll ask questions until i understand why, then suggest better ones.",
            composerPlaceholder: "describe the idea…",
            thinking: "thinking",
            showIdeas: "show forks",
            buildingIdeas: "building forks",
            ideasHeading: "forks",
            explore: "checkout",
            explored: "checked out",
            lock: "commit",
            locking: "writing the commit…",
            locked: "committed",
            keepDeveloping: "branch from here",
            diagnosis: "diff",
            confidence: "confidence",
            liked: "keep",
            broke: "broke",
            mustBeTrue: "needs",
            keeps: "keeps",
            fixes: "fixes",
            branchedFrom: "forked from",
            continuedFrom: "branched from"
        ),
        symbols: ThemeSymbols(
            newIdea: "plus",
            idea: "chevron.left.forwardslash.chevron.right",
            lock: "checkmark.seal",
            locked: "checkmark.seal.fill",
            branch: "arrow.triangle.branch",
            showIdeas: "arrow.triangle.branch",
            diagnosis: "plusminus",
            liked: "plus",
            broke: "minus",
            mustBeTrue: "exclamationmark"
        )
    )

    /// Juliette's brain: a farm, with a lot of colors.
    static let farm = Theme(
        id: "farm",
        name: "Farm",
        tagline: "Sunny fields and a lot of colors.",
        colorScheme: .light,
        fontDesign: .rounded,
        headingStyle: .uppercase,
        accent: Color(hex: 0xD9483B),
        onAccent: .white,
        controlTint: Color(hex: 0x3E9A4E),
        primaryText: Color(hex: 0x2E2A22),
        secondaryText: Color(hex: 0x6B6455),
        surface: Color(hex: 0xFFFBF0, opacity: 0.92),
        surfaceStroke: Color(hex: 0xE9DFC4),
        userBubble: Color(hex: 0xFFD866),
        userText: Color(hex: 0x3A2E10),
        likedColor: Color(hex: 0x3E9A4E),
        brokeColor: Color(hex: 0xC7533C),
        needsColor: Color(hex: 0x3D86C6),
        words: ThemeWords(
            sidebarTitle: "My garden",
            newIdea: "Plant a seed",
            emptyListTitle: "An empty field",
            emptyListBody: "Plant an idea that hasn't sprouted yet, or one that wilted.",
            noSelectionTitle: "Pick a plot",
            noSelectionBody: "Choose an idea from your garden, or plant a new one.",
            firstPromptTitle: "What's growing?",
            firstPromptBody: "Tell me about an idea that hasn't sprouted, or one that wilted. I'll ask questions until I know why, then suggest new seeds.",
            composerPlaceholder: "Tell me about your idea…",
            thinking: "Digging",
            showIdeas: "Show me sprouts",
            buildingIdeas: "Growing sprouts",
            ideasHeading: "Sprouts",
            explore: "Grow this one",
            explored: "Growing",
            lock: "Harvest",
            locking: "Harvesting…",
            locked: "Harvested",
            keepDeveloping: "Replant it",
            diagnosis: "Soil check",
            confidence: "Ready",
            liked: "Good soil",
            broke: "Weeds",
            mustBeTrue: "Needs to grow",
            keeps: "Keeps",
            fixes: "Fixes",
            branchedFrom: "Sprouted from",
            continuedFrom: "Replanted from"
        ),
        symbols: ThemeSymbols(
            newIdea: "leaf",
            idea: "leaf",
            lock: "basket",
            locked: "basket.fill",
            branch: "leaf.arrow.triangle.circlepath",
            showIdeas: "camera.macro",
            diagnosis: "sun.max",
            liked: "heart",
            broke: "ant",
            mustBeTrue: "drop"
        )
    )
}

extension EnvironmentValues {
    @Entry var theme: Theme = .system
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
