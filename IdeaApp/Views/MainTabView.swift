import SwiftData
import SwiftUI

/// The app's structure: Home (your journeys), Ideas (the ones you've locked in),
/// Settings, and Search at the trailing end, on the iOS 26 tab bar.
struct MainTabView: View {
    @Environment(\.modelContext) private var context
    @Environment(CoachSession.self) private var session
    @Environment(\.theme) private var theme

    enum TabID: Hashable {
        case home
        case ideas
        case settings
        case search
    }

    @State private var tab: TabID = .home
    @State private var homePath: [AppRoute] = []
    @State private var ideasPath: [AppRoute] = []
    @State private var searchPath: [AppRoute] = []
    @State private var tabBar = TabBarState()

    var body: some View {
        TabView(selection: $tab) {
            Tab("Home", systemImage: "house", value: TabID.home) {
                NavigationStack(path: $homePath) {
                    HomeView(path: $homePath)
                        .navigationDestination(for: AppRoute.self) { IdeaDestination(route: $0, path: $homePath) }
                }
                .controlTint(theme)
            }
            Tab("Ideas", systemImage: "lightbulb", value: TabID.ideas) {
                NavigationStack(path: $ideasPath) {
                    IdeasLibraryView()
                        .navigationDestination(for: AppRoute.self) { IdeaDestination(route: $0, path: $ideasPath) }
                }
                .controlTint(theme)
            }
            Tab("Settings", systemImage: "gearshape", value: TabID.settings) {
                SettingsView()
                    .controlTint(theme)
            }
            Tab(value: TabID.search, role: .search) {
                NavigationStack(path: $searchPath) {
                    SearchView()
                        .navigationDestination(for: AppRoute.self) { IdeaDestination(route: $0, path: $searchPath) }
                }
                .controlTint(theme)
            }
        }
        // The selected tab takes the accent and the others stay the label color,
        // like Health or Music; while the bar is minimized it's the label color too.
        // Each tab's content goes back to the control tint.
        .tint(tabBar.isMinimized ? theme.primaryText : theme.accent)
        .environment(tabBar)
        .onChange(of: tab) { tabBar.set(minimized: false) }
        .tabViewStyle(.sidebarAdaptable)
        .tabBarMinimizeBehavior(.onScrollDown)
        // "Open Settings" from an error in a conversation switches to the Settings tab.
        .onChange(of: session.showSettings) {
            if session.showSettings {
                tab = .settings
                session.showSettings = false
            }
        }
        .task { await runDebugScenario() }
    }

    private func runDebugScenario() async {
        #if DEBUG
        SampleData.applyLaunchRequest(to: context)
        await DebugScenario.runIfRequested(
            session: session,
            context: context,
            select: { idea in
                tab = .home
                homePath = idea.map { [.idea($0.id)] } ?? []
            },
            startDraft: {
                tab = .home
                homePath = [.newIdea]
            }
        )
        #endif
    }
}
