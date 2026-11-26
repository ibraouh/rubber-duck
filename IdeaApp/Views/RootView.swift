import SwiftUI
import UIKit

struct RootView: View {
    @AppStorage("themeID") private var themeID = Theme.system.id
    @AppStorage("hasChosenTheme") private var hasChosenTheme = false

    private var theme: Theme { Theme.named(themeID) }

    var body: some View {
        MainTabView()
            .sheet(isPresented: Binding(get: { !hasChosenTheme }, set: { if !$0 { hasChosenTheme = true } })) {
                ThemeOnboardingView()
                    .themed(theme)
                    .tint(theme.accent)
                    .interactiveDismissDisabled()
            }
            .themed(theme)
            .onChange(of: themeID, initial: true) { applyAppearance() }
    }

    /// Sets Light, Dark or the device's own mode on the window. SwiftUI's
    /// `preferredColorScheme(nil)` doesn't undo an earlier forced mode, so going from
    /// Mono (always dark) to System would otherwise stay dark.
    private func applyAppearance() {
        let style: UIUserInterfaceStyle = switch theme.colorScheme {
        case .dark?: .dark
        case .light?: .light
        default: .unspecified
        }
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}

extension View {
    /// Applies a theme's environment, font and tint. Light or dark is set on the
    /// window by `RootView`, so sheets follow it too.
    ///
    /// The System theme tints controls with the label color, like iOS 26: toolbar
    /// buttons are black or white on glass, and color is saved for the actions that
    /// should stand out, which set `.tint(theme.accent)` themselves.
    func themed(_ theme: Theme) -> some View {
        environment(\.theme, theme)
            .controlTint(theme)
            .fontDesign(theme.fontDesign)
    }

    /// The tint for controls inside a screen. The tab bar is the exception: its
    /// selected tab takes the accent (blue in System), as in Apple's own apps.
    func controlTint(_ theme: Theme) -> some View {
        tint(theme.isSystem ? Color.primary : theme.accent)
    }
}
