import OSLog
import SwiftData
import SwiftUI

@main
struct IdeaApp: App {
    static let iCloudContainer = "iCloud.com.raouh.ideas"

    @State private var session = CoachSession()
    private let container: ModelContainer

    init() {
        #if DEBUG
        DebugScenario.applyLaunchSettings()
        #endif
        container = Self.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
        }
        .modelContainer(container)
    }

    /// Whether this build may use the iCloud container. Builds signed with a free
    /// Apple account can't, and CloudKit stops the app on launch (it doesn't throw)
    /// when asked for a container it isn't allowed, so the store checks first.
    /// Development and ad hoc builds carry their provisioning profile, which lists
    /// the containers; App Store and TestFlight builds don't carry one and always
    /// have it, and neither do simulator builds.
    private static var canUseICloud: Bool {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url)
        else { return true }
        // The profile is a signed plist; the XML sits inside it as plain text.
        guard let text = String(data: data, encoding: .isoLatin1),
              let start = text.range(of: "<?xml"),
              let end = text.range(of: "</plist>"),
              let plist = try? PropertyListSerialization.propertyList(
                  from: Data(text[start.lowerBound..<end.upperBound].utf8), format: nil
              ) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any]
        else { return false }
        let containers = entitlements["com.apple.developer.icloud-container-identifiers"] as? [String] ?? []
        return containers.contains(iCloudContainer)
    }

    /// Ideas and conversations sync to the private iCloud database of whoever is
    /// signed in on the device, so they follow you across devices and survive a lost
    /// phone. There's no login: it uses the device's Apple ID. If iCloud can't be set
    /// up, the same store opens on this device only, and nothing is lost.
    private static func makeContainer() -> ModelContainer {
        let schema = Schema([Idea.self, IdeaMessage.self])
        let log = Logger(subsystem: "com.raouh.ideas", category: "storage")

        #if DEBUG
        // Debug scenarios delete every idea; give them a throwaway store so they can
        // never touch, or sync away, real ideas.
        if DebugScenario.isRequested {
            let scratch = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            return try! ModelContainer(for: schema, configurations: scratch)
        }
        #endif

        if canUseICloud {
            do {
                let synced = ModelConfiguration(schema: schema, cloudKitDatabase: .private(iCloudContainer))
                return try ModelContainer(for: schema, configurations: synced)
            } catch {
                log.error("iCloud sync unavailable, keeping ideas on this device: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            log.notice("Signed without iCloud (a free Apple account), keeping ideas on this device")
        }
        do {
            let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: local)
        } catch {
            fatalError("Couldn't open the ideas store: \(error)")
        }
    }
}
