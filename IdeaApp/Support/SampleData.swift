#if DEBUG
import Foundation
import SwiftData

/// Mock ideas for seeing the app with a full history. Debug builds only.
///
/// Launch with `-SeedSampleData YES` to add them to the real store (once; it does
/// nothing if they're already there), and `-RemoveSampleData YES` to delete them
/// and nothing else. They're marked `isSample`, and their conversations and cards
/// say they're samples, since Claude didn't write them. Continuing one sends the
/// sample history to Claude like any other conversation.
enum SampleData {
    static func applyLaunchRequest(to context: ModelContext) {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "RemoveSampleData") { remove(from: context) }
        if defaults.bool(forKey: "SeedSampleData") { seed(into: context) }
    }

    static func seed(into context: ModelContext) {
        var existing = FetchDescriptor<Idea>(predicate: #Predicate { $0.isSample })
        existing.fetchLimit = 1
        guard ((try? context.fetchCount(existing)) ?? 0) == 0 else { return }
        for journey in journeys {
            insert(journey, parent: nil, parentSuggestions: [], into: context)
        }
        try? context.save()
    }

    static func remove(from context: ModelContext) {
        let samples = (try? context.fetch(FetchDescriptor<Idea>(predicate: #Predicate { $0.isSample }))) ?? []
        for idea in samples {
            context.delete(idea)
        }
        try? context.save()
    }

    // MARK: - Building

    private struct Card {
        var oneLiner: String
        var why: String
        var fixed: String
        var questions: [String]
        var next: String
    }

    private struct Sample {
        var title: String
        var look: IdeaLook
        /// When it was last worked on.
        var daysAgo: Double
        var pinned = false
        var turns: [(MessageRole, String)]
        /// Offered in the last coach message; directions pick from these by title.
        var suggestions: [IdeaSuggestion] = []
        var quickReplies: [String] = []
        var liked: [String] = []
        var broke: [String] = []
        var needs: [String] = []
        var confidence: Confidence = .low
        var card: Card?
        var directions: [Sample] = []
    }

    private static func insert(_ sample: Sample, parent: Idea?, parentSuggestions: [IdeaSuggestion], into context: ModelContext) {
        let idea = Idea(title: sample.title)
        context.insert(idea)
        idea.isSample = true
        idea.parent = parent
        idea.apply(sample.look)
        idea.liked = sample.liked
        idea.broke = sample.broke
        idea.mustBeTrue = sample.needs
        idea.confidence = sample.confidence

        let date = Date.now.addingTimeInterval(-sample.daysAgo * 86_400)
        var messages: [(MessageRole, String, Bool)] = []
        if let parent, let suggestion = parentSuggestions.first(where: { $0.title == sample.title }) {
            idea.originTitle = suggestion.title
            idea.originPitch = suggestion.pitch
            idea.originKeeps = suggestion.keeps
            idea.originFixes = suggestion.fixes
            messages.append((.user, Prompts.branchSeed(parent: parent, suggestion: suggestion), true))
        }
        messages += sample.turns.map { ($0.0, $0.1, false) }

        var last: IdeaMessage?
        for (index, (role, text, isSeed)) in messages.enumerated() {
            let message = IdeaMessage(index: index, role: role, text: text, isSeed: isSeed)
            context.insert(message)
            message.idea = idea
            message.createdAt = date.addingTimeInterval(Double(index - messages.count) * 90)
            last = message
        }
        if let last, last.role == .assistant {
            last.suggestions = sample.suggestions
            last.quickReplies = sample.quickReplies
        }

        if let card = sample.card {
            idea.cardOneLiner = card.oneLiner
            idea.cardWhyItWorks = card.why
            idea.cardWhatItFixed = card.fixed
            idea.cardOpenQuestions = card.questions
            idea.cardNextStep = card.next
            idea.status = .locked
            idea.lockedAt = date
        }
        if sample.pinned { idea.pinnedAt = date }
        idea.createdAt = date.addingTimeInterval(-Double(messages.count) * 90)
        idea.updatedAt = date

        for direction in sample.directions {
            insert(direction, parent: idea, parentSuggestions: sample.suggestions, into: context)
        }
    }

    // MARK: - The ideas

    private static let journeys: [Sample] = [
        Sample(
            title: "Neighborhood tool library",
            look: IdeaLook(emoji: "🧰", category: "Business"),
            daysAgo: 0.12,
            pinned: true,
            turns: [
                (.user, "A tool library for my street, so people can borrow a drill instead of buying one"),
                (.assistant, "What got you thinking about this? Was there a moment you needed a tool and didn't have it?"),
                (.user, "I bought a tile saw for one weekend and it's been in the garage for two years"),
                (.assistant, "When you picture it running, who keeps track of who has what, and what happens when something comes back broken?"),
                (.user, "That's where it fell apart for me. I don't want to be the guy chasing people"),
                (.assistant, "That makes sense. You like the sharing, not the policing. Here are a few directions that keep the first part and drop the second."),
            ],
            suggestions: [
                IdeaSuggestion(title: "Tool swap shelf", pitch: "A shelf in a shared spot with a sign-out sheet and no deposits. Small, trusting, and easy to stop.", keeps: "Neighbors sharing what they own", fixes: "Chasing people down"),
                IdeaSuggestion(title: "Borrow board", pitch: "A shared list of who owns what, so people ask each other directly and you never hold anything.", keeps: "Fewer duplicate tools on the street", fixes: "Being the one in charge"),
                IdeaSuggestion(title: "Repair café nights", pitch: "A monthly evening where people bring broken things and fix them together with shared tools.", keeps: "The community part", fixes: "Tools going missing"),
            ],
            quickReplies: ["The board is close", "Mix the first two", "None of these"],
            liked: ["Sharing tools with neighbors", "Less waste"],
            broke: ["Being the one chasing returns"],
            needs: ["Runs without one person in charge"],
            confidence: .high,
            directions: [
                Sample(
                    title: "Borrow board",
                    look: IdeaLook(emoji: "📋", category: "Business"),
                    daysAgo: 0.1,
                    turns: [
                        (.assistant, "Who would you invite first, and how would they add their tools?"),
                        (.user, "The group chat for our building, maybe 20 people"),
                        (.assistant, "A list in that chat could work this week. What would make someone actually post their tile saw?"),
                        (.user, "If it took ten seconds"),
                    ],
                    liked: ["Sharing without holding anything"],
                    broke: ["Needing a keeper"],
                    needs: ["Takes ten seconds to add a tool"],
                    confidence: .high,
                    card: Card(
                        oneLiner: "A shared list of who owns which tools, so neighbors borrow from each other directly.",
                        why: "You get the sharing without holding anything or chasing anyone. It starts in the group chat you already have.",
                        fixed: "The library needed a keeper. The board doesn't, because tools stay with their owners until someone asks.",
                        questions: ["What happens when two people want the same thing?", "Does it need photos?"],
                        next: "Post a list of your own five tools in the building chat and ask two neighbors to add theirs."
                    )
                ),
                Sample(
                    title: "Repair café nights",
                    look: IdeaLook(emoji: "🔧", category: "Event"),
                    daysAgo: 0.5,
                    turns: [
                        (.assistant, "What would the first night look like, and where would it happen?"),
                        (.user, "The community room downstairs, maybe on a Sunday"),
                        (.assistant, "Who do you know who likes fixing things?"),
                    ],
                    quickReplies: ["My neighbor upstairs", "Nobody yet", "Me, honestly"],
                    liked: ["Fixing things together"],
                    confidence: .low
                ),
            ]
        ),
        Sample(
            title: "Sunday soup club",
            look: IdeaLook(emoji: "🍲", category: "Food"),
            daysAgo: 0.2,
            turns: [
                (.user, "A soup club where four friends each make a big pot on Sunday and swap portions"),
                (.assistant, "What's the part you're most excited about, the cooking or the getting together?"),
                (.user, "Honestly having lunches sorted for the week"),
                (.assistant, "So the payoff is a freezer full of soup. What made you shelve it?"),
            ],
            quickReplies: ["Coordinating schedules", "Not everyone cooks", "I never started"],
            liked: ["Lunches sorted for the week"],
            confidence: .low
        ),
        Sample(
            title: "Bedtime stories podcast",
            look: IdeaLook(emoji: "🌙", category: "Video"),
            daysAgo: 0.6,
            turns: [
                (.user, "A podcast of calm bedtime stories for adults who can't sleep"),
                (.assistant, "What do you usually listen to when you can't sleep, and what's wrong with it?"),
                (.user, "Sleep stories that are too sleepy, they feel like a guided meditation"),
                (.assistant, "So you want a real story, just told slowly. Who would be telling them?"),
            ],
            quickReplies: ["Me", "A friend with a great voice", "Different guests"],
            liked: ["Real stories, told slowly"],
            broke: ["Existing ones feel like meditation"],
            confidence: .medium
        ),
        Sample(
            title: "Watercolor postcards",
            look: IdeaLook(emoji: "🎨", category: "Art"),
            daysAgo: 1.3,
            turns: [
                (.user, "Painting one small watercolor postcard a week and mailing it to a friend"),
                (.assistant, "What drew you to postcards rather than just painting?"),
                (.user, "It gives each painting somewhere to go"),
                (.assistant, "That's a nice constraint. What stopped you after the first few?"),
                (.user, "I got precious about them and stopped finishing"),
                (.assistant, "Here are a few ways to keep the mailing and lose the pressure."),
            ],
            suggestions: [
                IdeaSuggestion(title: "Ten-minute postcards", pitch: "Set a timer and send whatever's on the paper when it rings.", keeps: "A painting that goes somewhere", fixes: "Getting precious"),
                IdeaSuggestion(title: "Postcard pen pals", pitch: "Trade with one other painter, so you get one back every week.", keeps: "Mailing to a friend", fixes: "Losing steam alone"),
            ],
            liked: ["Each painting has somewhere to go"],
            broke: ["Getting precious and not finishing"],
            needs: ["Low enough stakes to finish"],
            confidence: .high,
            directions: [
                Sample(
                    title: "Ten-minute postcards",
                    look: IdeaLook(emoji: "⏱️", category: "Art"),
                    daysAgo: 1.2,
                    turns: [
                        (.assistant, "What happens to a postcard you don't like when the timer rings?"),
                        (.user, "It still goes in the mail, that's the point"),
                    ],
                    liked: ["Finishing every week"],
                    broke: ["Perfectionism"],
                    needs: ["A hard stop"],
                    confidence: .high,
                    card: Card(
                        oneLiner: "Paint a postcard against a ten-minute timer and mail it, finished or not.",
                        why: "The timer decides when it's done, so there's nothing to get precious about, and every painting still goes somewhere.",
                        fixed: "Before, unfinished postcards piled up. Now finishing is automatic.",
                        questions: ["Who gets the first ten?", "Same friend every week, or a different one?"],
                        next: "Buy a pack of watercolor postcards and paint the first one tonight with a timer."
                    )
                ),
            ]
        ),
        Sample(
            title: "Habit tracker that forgives",
            look: IdeaLook(emoji: "🌤️", category: "Life"),
            daysAgo: 1.7,
            turns: [
                (.user, "A habit tracker that doesn't punish you for breaking a streak"),
                (.assistant, "What happened the last time you broke a streak?"),
                (.user, "I deleted the app the same day"),
                (.assistant, "So the streak itself became the thing to protect. What would you want to see after a missed day instead?"),
            ],
            quickReplies: ["Nothing at all", "How the week went overall", "A nudge, not a red X"],
            liked: ["Building habits"],
            broke: ["Streaks feel punishing"],
            confidence: .medium
        ),
        Sample(
            title: "Song a week with friends",
            look: IdeaLook(emoji: "🎸", category: "Music"),
            daysAgo: 3,
            turns: [
                (.user, "Write a song a week with two friends and share them in a group chat"),
                (.assistant, "Have you written songs together before, or would this be new?"),
                (.user, "We jammed in college but never finished anything"),
                (.assistant, "What usually stopped the songs from getting finished?"),
                (.user, "Someone always wanted to fix the bridge"),
                (.assistant, "A few directions that keep the weekly rhythm and make finishing the default."),
            ],
            suggestions: [
                IdeaSuggestion(title: "Demo or it didn't happen", pitch: "Every week ends with a rough phone recording, however unfinished.", keeps: "Writing with friends", fixes: "Endless fixing"),
                IdeaSuggestion(title: "One part each", pitch: "Each friend owns one part, verse, chorus or bridge, and can't touch the others.", keeps: "Working together", fixes: "Arguing over the bridge"),
            ],
            liked: ["Writing with friends", "A weekly rhythm"],
            broke: ["Nothing gets finished"],
            needs: ["Finishing is the default"],
            confidence: .high,
            directions: [
                Sample(
                    title: "Demo or it didn't happen",
                    look: IdeaLook(emoji: "🎙️", category: "Music"),
                    daysAgo: 2.5,
                    turns: [
                        (.assistant, "What would you record on?"),
                        (.user, "Voice memos, nothing fancy"),
                        (.assistant, "Good. Who sends the first one, and by when?"),
                    ],
                    quickReplies: ["Me, by Sunday", "Whoever's ready", "We take turns"],
                    liked: ["Rough is fine"],
                    confidence: .medium
                ),
            ]
        ),
        Sample(
            title: "Trail running map",
            look: IdeaLook(emoji: "🏃", category: "Fitness"),
            daysAgo: 4,
            turns: [
                (.user, "A map of trail runs near the city, rated by how muddy they get"),
                (.assistant, "Is this for you, or for a group you run with?"),
                (.user, "Mostly me and a running club of about 30 people"),
                (.assistant, "What do people in the club ask about most before a run?"),
            ],
            quickReplies: ["Parking", "Mud, obviously", "How long it takes"],
            liked: ["Knowing what a trail is like before going"],
            confidence: .low
        ),
        Sample(
            title: "Cozy puzzle game",
            look: IdeaLook(emoji: "🧩", category: "Game"),
            daysAgo: 5,
            turns: [
                (.user, "A cozy puzzle game about organizing a messy attic"),
                (.assistant, "What's the feeling you want when someone finishes a level?"),
                (.user, "Like when you finally clean your desk"),
                (.assistant, "What made you put it down?"),
                (.user, "The art. I can't draw and it needs to look nice"),
                (.assistant, "Here are directions that keep the tidy-up feeling without needing much art."),
            ],
            suggestions: [
                IdeaSuggestion(title: "Words, not pictures", pitch: "Sort labeled boxes and lists instead of drawn objects. The reward comes from order, not art.", keeps: "The tidy-up feeling", fixes: "Needing lots of art"),
                IdeaSuggestion(title: "Photo attic", pitch: "Use photos of real objects you shoot yourself on a plain background.", keeps: "A real attic feel", fixes: "Not being able to draw"),
            ],
            liked: ["The satisfaction of tidying"],
            broke: ["Needs art you can't make"],
            needs: ["Looks good without drawing"],
            confidence: .high,
            directions: [
                Sample(
                    title: "Words, not pictures",
                    look: IdeaLook(emoji: "🗂️", category: "Game"),
                    daysAgo: 4.5,
                    turns: [
                        (.assistant, "What's the first thing a player sorts?"),
                        (.user, "A box labeled 'misc' that's full of other boxes"),
                        (.assistant, "That's a great first level. It teaches the whole game in one box."),
                    ],
                    liked: ["Order as the reward"],
                    broke: ["Art"],
                    needs: ["Text-only looks good"],
                    confidence: .high,
                    card: Card(
                        oneLiner: "A sorting puzzle game made of labels and lists, where the reward is a tidy screen.",
                        why: "It keeps the feeling of a clean desk and needs only type and a few colors, which you can make yourself.",
                        fixed: "The attic needed art you couldn't draw. Words carry the same satisfaction.",
                        questions: ["How does a level get harder?", "Is there a story?"],
                        next: "Make the 'misc' box level on paper with index cards and play it with a friend."
                    )
                ),
            ]
        ),
        Sample(
            title: "Forgotten inventions newsletter",
            look: IdeaLook(emoji: "📰", category: "Writing"),
            daysAgo: 15,
            turns: [
                (.user, "A weekly newsletter about inventions that almost made it"),
                (.assistant, "Which one got you hooked on the idea?"),
                (.user, "The electric cars from around 1900"),
                (.assistant, "What's stopped you from sending the first issue?"),
            ],
            quickReplies: ["No subscribers yet", "Research takes forever", "Picking a name"],
            liked: ["Stories of near misses"],
            confidence: .low
        ),
        Sample(
            title: "Birthday time capsule",
            look: IdeaLook(emoji: "🎁", category: "Gift"),
            daysAgo: 26,
            turns: [
                (.user, "A time capsule for a friend's 30th, with letters from everyone she knows"),
                (.assistant, "How much time do you have before the birthday?"),
                (.user, "Three weeks"),
                (.assistant, "Then the hard part is collecting the letters in time. Who would you ask first?"),
                (.user, "Her sister, she knows everyone"),
            ],
            liked: ["Letters from everyone she knows"],
            broke: ["Collecting them in time"],
            needs: ["Someone who knows everyone"],
            confidence: .high,
            card: Card(
                oneLiner: "A box of letters from her friends and family, collected by her sister and opened on her 30th.",
                why: "Her sister can reach everyone quickly, so three weeks is enough.",
                fixed: "You'd have been chasing people you barely know. Now someone close to them asks.",
                questions: ["How do you keep it a surprise?", "Paper letters or voice notes?"],
                next: "Message her sister tonight with the idea and a deadline."
            )
        ),
        Sample(
            title: "Slow road trip planner",
            look: IdeaLook(emoji: "🚐", category: "Travel"),
            daysAgo: 28,
            turns: [
                (.user, "A road trip planner that only plans two hours of driving a day"),
                (.assistant, "Where does the idea come from, a trip that went wrong?"),
                (.user, "We drove nine hours a day across the country and saw nothing"),
                (.assistant, "So the point is the stops, not the miles. What does a perfect day on the road look like?"),
                (.user, "Coffee somewhere local, a short hike, dinner in a small town"),
            ],
            liked: ["The stops, not the miles"],
            broke: ["Long driving days"],
            needs: ["Short drives with good stops"],
            confidence: .high,
            card: Card(
                oneLiner: "A trip planner that caps driving at two hours a day and fills the rest with local stops.",
                why: "It plans the trip around the parts you remember: coffee, a hike, dinner somewhere small.",
                fixed: "The last trip was all highway. This one can't be.",
                questions: ["Where do the stops come from?", "What about trips with a deadline?"],
                next: "Plan one weekend this way by hand and see how it feels."
            )
        ),
        Sample(
            title: "Language exchange dinners",
            look: IdeaLook(emoji: "🗣️", category: "Event"),
            daysAgo: 45,
            turns: [
                (.user, "Dinners where half the table is learning the other half's language"),
                (.assistant, "Which languages are you thinking of, and do you speak either?"),
                (.user, "Spanish and English. I'm the one learning Spanish"),
                (.assistant, "What usually makes language meetups awkward for you?"),
            ],
            quickReplies: ["Too many people", "I freeze up", "Nobody switches languages"],
            liked: ["Learning over dinner"],
            confidence: .low
        ),
        Sample(
            title: "Balcony herb garden",
            look: IdeaLook(emoji: "🪴", category: "Home"),
            daysAgo: 70,
            turns: [
                (.user, "Growing herbs on my balcony that I actually use when cooking"),
                (.assistant, "Which herbs do you buy most often?"),
                (.user, "Basil and cilantro, and they always die"),
                (.assistant, "Basil and cilantro want very different things. How much sun does your balcony get?"),
            ],
            quickReplies: ["Morning sun only", "All afternoon", "Barely any"],
            liked: ["Cooking with fresh herbs"],
            broke: ["Plants keep dying"],
            confidence: .low
        ),
        Sample(
            title: "Budget app for couples",
            look: IdeaLook(emoji: "💸", category: "App"),
            daysAgo: 100,
            turns: [
                (.user, "A budgeting app for couples that doesn't feel like a spreadsheet"),
                (.assistant, "What happens now when the two of you talk about money?"),
                (.user, "It turns into a spreadsheet review and nobody enjoys it"),
                (.assistant, "So the conversation is the problem, not the math. What if the app only showed the three things worth talking about this week?"),
                (.user, "That I'd actually open"),
            ],
            liked: ["Talking about money together"],
            broke: ["It turns into a spreadsheet review"],
            needs: ["Only what's worth discussing"],
            confidence: .high,
            card: Card(
                oneLiner: "A weekly money check-in for two that shows only the three things worth talking about.",
                why: "It keeps the conversation short and about what matters, so neither of you dreads it.",
                fixed: "Budgets turned into spreadsheet reviews. This picks the three items for you.",
                questions: ["How does it pick the three?", "What if you disagree?"],
                next: "Try one check-in by hand this Sunday with three things picked from last week."
            )
        ),
        Sample(
            title: "One-take short film",
            look: IdeaLook(emoji: "🎬", category: "Video"),
            daysAgo: 350,
            turns: [
                (.user, "A short film shot in one continuous take in my apartment"),
                (.assistant, "What's the story, or is the one take the idea?"),
                (.user, "The one take is the idea. The story is a dinner party going wrong"),
                (.assistant, "That's a good fit, since a dinner party already runs on a clock. How many people are in it?"),
                (.user, "Five, all friends"),
            ],
            liked: ["One continuous take"],
            broke: ["Needing a story"],
            needs: ["A story with its own clock"],
            confidence: .high,
            card: Card(
                oneLiner: "A ten-minute dinner party that falls apart in one unbroken shot.",
                why: "The party gives the take a natural clock, and five friends can rehearse it in an evening.",
                fixed: "The one take had no story. Now the story fits the take.",
                questions: ["Where does the camera start?", "Who plays the host?"],
                next: "Walk the route through the apartment with your phone and time it."
            )
        ),
    ]
}
#endif
