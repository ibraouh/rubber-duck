import SwiftUI

extension View {
    /// The System theme's background for a top-level list: a soft glow of color
    /// behind the large title, like Health's Summary, that fades as you scroll.
    /// The other themes keep their own drawn background.
    func tabGlow(_ colors: [Color]) -> some View {
        modifier(TabGlow(colors: colors))
    }
}

private struct TabGlow: ViewModifier {
    @Environment(\.theme) private var theme
    let colors: [Color]
    @State private var scrollOffset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background {
                if theme.isSystem {
                    Glow(colors: colors, strength: max(0, 1 - scrollOffset / 260))
                } else {
                    ThemeBackground()
                }
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                scrollOffset = offset
            }
    }
}

private struct Glow: View {
    @Environment(\.colorScheme) private var colorScheme
    let colors: [Color]
    let strength: Double

    var body: some View {
        Color(uiColor: .systemGroupedBackground)
            .overlay(alignment: .top) {
                LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
                    .frame(height: 420)
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black.opacity(0.45), location: 0.45),
                                .init(color: .clear, location: 1),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .opacity((colorScheme == .dark ? 0.7 : 0.4) * strength)
            }
            .ignoresSafeArea()
    }
}
