import SwiftUI

/// What the coach understands so far: what you liked, what broke, what a better
/// version needs, and how confident it is. Pinned above the conversation on glass.
struct DiagnosisBar: View {
    @Environment(\.theme) private var theme
    let idea: Idea
    @Binding var expanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.snappy) { expanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: theme.symbols.diagnosis)
                        .foregroundStyle(theme.accent)
                    Text(theme.words.diagnosis)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                    Spacer()
                    Text(theme.words.confidence)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                    ConfidenceMeter(level: idea.confidence.level)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 12) {
                    DiagnosisList(title: theme.words.liked, symbol: theme.symbols.liked, color: theme.likedColor, items: idea.liked)
                    DiagnosisList(title: theme.words.broke, symbol: theme.symbols.broke, color: theme.brokeColor, items: idea.broke)
                    DiagnosisList(title: theme.words.mustBeTrue, symbol: theme.symbols.mustBeTrue, color: theme.needsColor, items: idea.mustBeTrue)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }
}

private struct DiagnosisList: View {
    @Environment(\.theme) private var theme
    let title: String
    let symbol: String
    let color: Color
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
            if items.isEmpty {
                Text("…")
                    .font(.footnote)
                    .foregroundStyle(theme.secondaryText)
                    .padding(.leading, 26)
            } else {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.footnote)
                        .foregroundStyle(theme.primaryText)
                        .padding(.leading, 26)
                }
            }
        }
    }
}

private struct ConfidenceMeter: View {
    @Environment(\.theme) private var theme
    let level: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...3, id: \.self) { step in
                Capsule()
                    .fill(step <= level ? theme.accent : theme.secondaryText.opacity(0.3))
                    .frame(width: 14, height: 5)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Confidence \(level) of 3")
    }
}
