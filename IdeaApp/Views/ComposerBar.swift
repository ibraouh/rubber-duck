import SwiftUI

/// The message field, styled like Messages on iOS 26: one glass field that grows
/// with the text, with the send button appearing inside it once there's something to send.
/// Use it inside `safeAreaBar(edge: .bottom)` so the conversation fades under it.
struct ComposerBar: View {
    @Environment(\.theme) private var theme
    @Binding var draft: String
    var focus: FocusState<Bool>.Binding
    var isBusy: Bool
    var onSend: (String) -> Void

    private var trimmed: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSend: Bool { !trimmed.isEmpty && !isBusy }

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            TextField(theme.words.composerPlaceholder, text: $draft, axis: .vertical)
                .lineLimit(1...6)
                .focused(focus)
                // Leave the text color to the glass, which picks a legible one
                // for whatever is behind it (Farm's hills turn it dark).
                .padding(.vertical, 10)
                .padding(.leading, 16)
                .padding(.trailing, canSend ? 0 : 16)

            if canSend {
                Button(action: submit) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(theme.onAccent)
                        .frame(width: 30, height: 30)
                        .background(theme.accent, in: .circle)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 5)
                .padding(.bottom, 5)
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel("Send")
            }
        }
        .frame(minHeight: 40)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 8)
        .animation(.snappy(duration: 0.2), value: canSend)
    }

    private func submit() {
        guard canSend else { return }
        onSend(trimmed)
    }
}
