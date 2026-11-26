import SwiftUI

/// The Settings tab.
struct SettingsView: View {
    @Environment(CoachSession.self) private var session
    @Environment(\.theme) private var currentTheme
    @AppStorage("themeID") private var themeID = Theme.system.id
    @State private var keyDraft = ""
    @State private var keyStatus: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(Theme.all) { theme in
                        ThemeTile(theme: theme, isSelected: theme.id == themeID) {
                            themeID = theme.id
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    }
                } header: {
                    Text("How your brain works")
                } footer: {
                    Text("The theme is saved on this device, so everyone can pick their own.")
                }

                Section {
                    SecureField(session.hasAPIKey ? "Key saved. Paste a new one to replace it." : "sk-ant-…", text: $keyDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Save key") {
                        keyStatus = session.saveAPIKey(keyDraft) ? "Saved to the Keychain." : "Couldn't save the key."
                        keyDraft = ""
                    }
                    .disabled(keyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if session.hasAPIKey {
                        Button("Remove key", role: .destructive) {
                            session.saveAPIKey("")
                            keyStatus = "Key removed."
                        }
                    }
                } header: {
                    Text("Claude API key")
                } footer: {
                    Text(keyStatus ?? "Stored in this device's Keychain. Requests go straight from this device to Anthropic's API.")
                }

                Section {
                    LabeledContent {
                        Text("iCloud")
                    } label: {
                        Label("Ideas and conversations", systemImage: "icloud")
                    }
                } header: {
                    Text("Sync")
                } footer: {
                    Text("Saved to your iCloud account and kept in sync on your devices signed in with the same Apple ID. Your API key and theme stay on each device.")
                }

                Section("About") {
                    LabeledContent("Model", value: ClaudeCoach.model)
                }
            }
            // Form buttons take the accent color, as in Apple's own settings screens.
            .tint(currentTheme.accent)
            .tracksTabBarMinimizing()
            .navigationTitle("Settings")
        }
    }
}

/// A small preview of a theme: its background, font and accent.
struct ThemeTile: View {
    @Environment(\.colorScheme) private var currentScheme
    let theme: Theme
    let isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                ThemeBackground()
                    .environment(\.theme, theme)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(theme.name)
                            .font(.title3.weight(.bold))
                        Spacer()
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                        }
                    }
                    Text(theme.tagline)
                        .font(.subheadline)
                }
                .fontDesign(theme.fontDesign)
                .foregroundStyle(theme.primaryText)
                .padding(14)
                .background(theme.surface, in: .rect(cornerRadius: 16))
                .padding(10)
            }
            .frame(height: 130)
            .clipShape(.rect(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(
                        // System keeps blue for message bubbles only, so its ring is neutral.
                        isSelected ? (theme.isSystem ? Color.primary : theme.accent) : Color.secondary.opacity(0.3),
                        lineWidth: isSelected ? 2.5 : 1
                    )
            )
            .environment(\.colorScheme, theme.colorScheme ?? currentScheme)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// First launch: pick the theme that matches how your brain works.
struct ThemeOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("themeID") private var themeID = Theme.system.id
    @AppStorage("hasChosenTheme") private var hasChosenTheme = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("How does your brain work?")
                        .font(.largeTitle.weight(.bold))
                    Text("Pick a look. You can change it any time in Settings.")
                        .foregroundStyle(.secondary)
                    ForEach(Theme.all) { theme in
                        ThemeTile(theme: theme, isSelected: theme.id == themeID) {
                            themeID = theme.id
                        }
                    }
                }
                .padding(20)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        hasChosenTheme = true
                        dismiss()
                    }
                }
            }
        }
    }
}
