import SwiftUI

/// A Messages-style bubble: rounded, with a tail at the bottom corner on the
/// sender's side.
struct BubbleShape: Shape {
    var fromUser: Bool

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        // Drawn with the tail at the bottom right, then mirrored for the coach's side.
        path.move(to: CGPoint(x: w - 20, y: h))
        path.addLine(to: CGPoint(x: 20, y: h))
        path.addCurve(to: CGPoint(x: 0, y: h - 20), control1: CGPoint(x: 8, y: h), control2: CGPoint(x: 0, y: h - 8))
        path.addLine(to: CGPoint(x: 0, y: 20))
        path.addCurve(to: CGPoint(x: 20, y: 0), control1: CGPoint(x: 0, y: 8), control2: CGPoint(x: 8, y: 0))
        path.addLine(to: CGPoint(x: w - 21, y: 0))
        path.addCurve(to: CGPoint(x: w - 4, y: 20), control1: CGPoint(x: w - 12, y: 0), control2: CGPoint(x: w - 4, y: 8))
        path.addLine(to: CGPoint(x: w - 4, y: h - 11))
        path.addCurve(to: CGPoint(x: w, y: h), control1: CGPoint(x: w - 4, y: h - 1), control2: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: w + 0.05, y: h - 0.01))
        path.addCurve(to: CGPoint(x: w - 11, y: h - 4), control1: CGPoint(x: w - 4, y: h + 0.5), control2: CGPoint(x: w - 8, y: h - 1))
        path.addCurve(to: CGPoint(x: w - 20, y: h), control1: CGPoint(x: w - 15, y: h), control2: CGPoint(x: w - 20, y: h))
        path.closeSubpath()

        let placed = fromUser
            ? path
            : path.applying(CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -w, y: 0))
        return placed.offsetBy(dx: rect.minX, dy: rect.minY)
    }
}

/// One message, sized to its text, on the sender's side.
struct MessageBubble: View {
    @Environment(\.theme) private var theme
    let text: String
    let fromUser: Bool

    var body: some View {
        HStack(spacing: 0) {
            if fromUser { Spacer(minLength: 56) }
            Text(text)
                .foregroundStyle(fromUser ? theme.userText : theme.primaryText)
                .textSelection(.enabled)
                .padding(.vertical, 9)
                .padding(.leading, fromUser ? 14 : 18)
                .padding(.trailing, fromUser ? 18 : 14)
                .background(fromUser ? theme.userBubble : theme.surface, in: BubbleShape(fromUser: fromUser))
                .overlay {
                    if !fromUser {
                        BubbleShape(fromUser: false).stroke(theme.surfaceStroke, lineWidth: 0.5)
                    }
                }
            if !fromUser { Spacer(minLength: 56) }
        }
    }
}

/// The three pulsing dots Messages shows while the other side is typing.
struct TypingIndicator: View {
    @Environment(\.theme) private var theme

    var body: some View {
        HStack {
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { dot in
                        let wave = sin(t * 5 - Double(dot) * 0.7)
                        Circle()
                            .frame(width: 8, height: 8)
                            .opacity(0.35 + 0.65 * max(0, wave))
                    }
                }
                .foregroundStyle(theme.secondaryText)
            }
            .padding(.vertical, 14)
            .padding(.leading, 20)
            .padding(.trailing, 16)
            .background(theme.surface, in: BubbleShape(fromUser: false))
            .overlay(BubbleShape(fromUser: false).stroke(theme.surfaceStroke, lineWidth: 0.5))
            .accessibilityElement()
            .accessibilityLabel(theme.words.thinking)
            Spacer(minLength: 0)
        }
    }
}

/// Shown while the coach works out its ideas: a pulsing sparkle, a shimmering
/// "Building suggestions…", and placeholder cards where the ideas will land.
struct BuildingIdeasIndicator: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: theme.symbols.showIdeas)
                    .foregroundStyle(theme.accent)
                    .symbolEffect(.breathe, isActive: !reduceMotion)
                ShimmerText(text: theme.words.buildingIdeas + "…", animated: !reduceMotion)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.leading, 4)

            ForEach(0..<2, id: \.self) { card in
                PlaceholderCard(seed: card, animated: !reduceMotion)
            }
        }
        .padding(.top, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(theme.words.buildingIdeas)
    }
}

/// Text with a highlight sweeping across it.
private struct ShimmerText: View {
    @Environment(\.theme) private var theme
    let text: String
    let animated: Bool

    var body: some View {
        if animated {
            TimelineView(.animation) { context in
                let cycle = 1.8
                let progress = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle) / cycle
                let x = progress * 1.6 - 0.3
                Text(text)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.secondaryText, theme.primaryText, theme.secondaryText],
                            startPoint: UnitPoint(x: x - 0.25, y: 0.5),
                            endPoint: UnitPoint(x: x + 0.25, y: 0.5)
                        )
                    )
            }
        } else {
            Text(text).foregroundStyle(theme.secondaryText)
        }
    }
}

/// A suggestion-card-shaped placeholder with gently pulsing lines.
private struct PlaceholderCard: View {
    @Environment(\.theme) private var theme
    let seed: Int
    let animated: Bool

    var body: some View {
        TimelineView(.animation(paused: !animated)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let pulse = animated ? 0.55 + 0.25 * sin(t * 3 + Double(seed)) : 0.6
            VStack(alignment: .leading, spacing: 10) {
                line(width: 0.55, height: 14)
                line(width: 0.95, height: 10)
                line(width: 0.8, height: 10)
                line(width: 0.45, height: 10)
            }
            .opacity(pulse)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: .rect(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(theme.surfaceStroke, lineWidth: 0.5))
        }
    }

    private func line(width: CGFloat, height: CGFloat) -> some View {
        Capsule()
            .fill(theme.secondaryText.opacity(0.35))
            .frame(height: height)
            .containerRelativeFrame(.horizontal) { length, _ in length * width * 0.8 }
    }
}

/// Tappable answers to the coach's last question, on your side of the conversation.
struct SuggestedReplies: View {
    @Environment(\.theme) private var theme
    let replies: [String]
    let showIdeas: Bool
    var onSend: (String) -> Void

    var body: some View {
        FlowLayout(alignment: .trailing, spacing: 8) {
            ForEach(replies, id: \.self) { reply in
                Button(reply) { onSend(reply) }
                    .buttonStyle(.bordered)
                    // The bordered fill is see-through; back it so it stays
                    // readable over busy backgrounds like Farm's hills.
                    .background(theme.surface, in: .capsule)
            }
            if showIdeas {
                Button {
                    onSend(Prompts.showIdeasMessage)
                } label: {
                    Label(theme.words.showIdeas, systemImage: theme.symbols.showIdeas)
                        .foregroundStyle(theme.onAccent)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .buttonBorderShape(.capsule)
        .tint(theme.accent)
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.leading, 40)
        .padding(.top, 2)
    }
}

/// Lays out views in rows, wrapping to a new row when one fills up.
struct FlowLayout: Layout {
    var alignment: HorizontalAlignment = .leading
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, maxWidth: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, maxWidth: bounds.width) {
            var x = bounds.minX
            if alignment == .trailing {
                x = bounds.maxX - row.width
            } else if alignment == .center {
                x = bounds.minX + (bounds.width - row.width) / 2
            }
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y + (row.height - item.size.height) / 2),
                    proposal: ProposedViewSize(item.size)
                )
                x += item.size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var items: [(index: Int, size: CGSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for (index, subview) in subviews.enumerated() {
            var size = subview.sizeThatFits(.unspecified)
            if size.width > maxWidth {
                size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            }
            let widthWithItem = row.items.isEmpty ? size.width : row.width + spacing + size.width
            if widthWithItem > maxWidth, !row.items.isEmpty {
                rows.append(row)
                row = Row()
            }
            row.width = row.items.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.items.append((index, size))
        }
        if !row.items.isEmpty { rows.append(row) }
        return rows
    }
}
