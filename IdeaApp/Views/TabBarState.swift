import SwiftUI

/// Whether the tab bar is minimized, so its selected tab can drop the accent
/// color while it's small. iOS doesn't tell apps when it minimizes the bar, so
/// this follows what `.tabBarMinimizeBehavior(.onScrollDown)` was seen doing on
/// iOS 26: it minimizes as soon as you scroll down, stays small while you scroll
/// back up, and comes back once you're at the top again.
@Observable
final class TabBarState {
    var isMinimized = false

    func set(minimized: Bool) {
        if isMinimized != minimized { isMinimized = minimized }
    }
}

extension View {
    /// Reports this scroll view's direction to `TabBarState`. Goes on each
    /// scrolling screen that shows the tab bar.
    func tracksTabBarMinimizing() -> some View {
        modifier(TabBarMinimizeTracker())
    }
}

private struct TabBarMinimizeTracker: ViewModifier {
    @Environment(TabBarState.self) private var tabBar: TabBarState?

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                // How far it's scrolled, ignoring the bounce past either end.
                let top = -geometry.contentInsets.top
                let bottom = max(top, geometry.contentSize.height - geometry.containerSize.height + geometry.contentInsets.bottom)
                return min(max(geometry.contentOffset.y, top), bottom) - top
            } action: { old, new in
                guard let tabBar else { return }
                if new <= 4 {
                    tabBar.set(minimized: false)
                } else if new > old {
                    tabBar.set(minimized: true)
                }
            }
            // Coming back to a screen (from a conversation, say) shows the full bar.
            .onAppear { tabBar?.set(minimized: false) }
    }
}
