#if DEBUG
import Foundation
import SwiftData

/// Debug builds only. Drives the app through a scripted session using the real
/// session code and the demo coach, so screens can be checked without tapping.
///
/// Launch with `-DebugScenario <stop>`, where stop is one of
/// `empty`, `first`, `questions`, `ideas`, `branch` or `locked`.
/// It runs in a throwaway in-memory store (see `IdeaApp.makeContainer`), so real
/// and iCloud-synced ideas are never touched, and it turns on demo replies.
/// Add `-DebugTheme <id>` to start in a theme.
enum DebugScenario {
    static var isRequested: Bool {
        UserDefaults.standard.string(forKey: "DebugScenario") != nil
    }

    /// Saves `-DebugTheme` as if it had been picked in Settings. Don't pass `-themeID`
    /// on the command line: launch arguments override saved settings for the whole run,
    /// so the theme couldn't be changed until the app was relaunched.
    static func applyLaunchSettings() {
        let defaults = UserDefaults.standard
        guard let theme = defaults.string(forKey: "DebugTheme") else { return }
        defaults.set(theme, forKey: "themeID")
        defaults.set(true, forKey: "hasChosenTheme")
    }

    static func runIfRequested(
        session: CoachSession,
        context: ModelContext,
        select: (Idea?) -> Void,
        startDraft: () -> Void
    ) async {
        guard let stop = UserDefaults.standard.string(forKey: "DebugScenario") else { return }
        session.isUsingDemoReplies = true
        select(nil)
        if stop == "empty" { return }
        if stop == "gallery" {
            addGallery(to: context)
            return
        }
        if stop == "first" {
            startDraft()
            return
        }

        func waitUntilIdle(_ target: Idea) async {
            try? await Task.sleep(for: .milliseconds(100))
            while session.isBusy(target) {
                try? await Task.sleep(for: .milliseconds(150))
            }
        }
        func say(_ text: String, in target: Idea) async {
            session.send(text, in: target, context: context)
            await waitUntilIdle(target)
        }

        let idea = session.startIdea(with: "A dinner club app that matches friends into small weekly dinners", in: context)
        select(idea)
        await waitUntilIdle(idea)
        await say("It solved my own problem", in: idea)
        if stop == "questions" { return }

        await say("It got too big", in: idea)
        await say("I could finish it fast", in: idea)
        if stop == "ideas" { return }

        guard let suggestion = idea.sortedMessages.last?.suggestions.first else { return }
        let child = session.explore(suggestion, from: idea, in: context)
        select(child)
        await waitUntilIdle(child)
        if stop == "branch" { return }

        await say("It's small enough to start", in: child)
        await say("Who it's for", in: child)
        session.lock(child, in: context)
        await waitUntilIdle(child)
    }

    /// Sample ideas with varied icons, for comparing how icons look in lists.
    /// No conversation happens; it only fills the throwaway store.
    private static func addGallery(to context: ModelContext) {
        func add(_ title: String, _ look: IdeaLook?, said: String, replied: String, parent: Idea? = nil, card: String? = nil, minutesAgo: Double) -> Idea {
            let idea = Idea(title: title)
            context.insert(idea)
            idea.parent = parent
            if let look { idea.apply(look) }
            let date = Date.now.addingTimeInterval(-minutesAgo * 60)
            for (index, (role, text)) in [(MessageRole.user, said), (.assistant, replied)].enumerated() {
                let message = IdeaMessage(index: index, role: role, text: text)
                context.insert(message)
                message.idea = idea
            }
            if let card {
                idea.cardOneLiner = card
                idea.status = .locked
                idea.lockedAt = date
            }
            idea.updatedAt = date
            return idea
        }

        let wine = add("Wine tasting app", IdeaLook(emoji: "🍷", category: "App"),
                       said: "An app for blind wine tastings with friends", replied: "What made the tastings fun when you ran them?", minutesAgo: 20)
        _ = add("Party in a Box", IdeaLook(emoji: "🎉", category: "Event"),
                said: "", replied: "", parent: wine,
                card: "The host picks a budget and a theme, and the app builds the shopping list and score cards.", minutesAgo: 15)
        _ = add("A podcast about abandoned projects", IdeaLook(emoji: "🎙️", category: "Video"),
                said: "A podcast where people talk about projects they gave up on", replied: "What would you want listeners to walk away with?", minutesAgo: 60)
        _ = add("Weekend pottery class", IdeaLook(emoji: "🏺", category: "Art"),
                said: "Teaching a small pottery class on weekends", replied: "Who do you picture in the first class?", minutesAgo: 180)
        _ = add("Song a day", IdeaLook(emoji: "🎸", category: "Music"),
                said: "Write and record one short song every day for a month", replied: "What stopped you the last time you tried?", minutesAgo: 60 * 26)
        _ = add("Garden planner", IdeaLook(emoji: "🌱", category: "Home"),
                said: "Plan what to plant where in a small backyard", replied: "What went wrong in the garden this year?", minutesAgo: 60 * 50)
        _ = add("Board game night kit", IdeaLook(emoji: "🎲", category: "Game"),
                said: "A box with everything for a game night", replied: "Who would you host first?",
                card: "A ready-to-go game night for four, with snacks and a two-hour plan.", minutesAgo: 60 * 75)
        _ = add("Old notes app", nil,
                said: "A notes app that sorts itself", replied: "What do you lose track of most?", minutesAgo: 60 * 24 * 9)
        try? context.save()
    }
}
#endif
