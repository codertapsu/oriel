import SwiftUI

/// Settings → Translation (PLAN §7.7.5): languages, default provider, every provider's endpoint, model, key and
/// options with "Test connection", the language-pack sheet, glossary and history.
struct TranslationSettingsView: View {
    @Bindable var model: TranslationSettingsModel

    private static let retentionChoices = [7, 30, 90, 365, 0]

    var body: some View {
        Form {
            languages
            providers
            glossary
            history
        }
        .formStyle(.grouped)
        .sheet(isPresented: $model.showsLanguagePackSheet) {
            LanguagePackDownloadView(
                source: "en", target: targetCode == "en" ? "fr" : targetCode, allowsChoosingLanguages: true
            ) { _ in model.showsLanguagePackSheet = false }
        }
    }

    private var targetCode: String {
        LanguageCatalog.code(for: LanguageCatalog.language(for: model.settings[TranslationKeys.targetLanguage]))
    }

    private var languages: some View {
        Section("Translation") {
            Picker("Translate into", selection: model.settings.binding(TranslationKeys.targetLanguage)) {
                Text("System Language (\(LanguageCatalog.name(of: LanguageCatalog.code(for: LanguageCatalog.systemLanguage))))").tag("")
                Divider()
                ForEach(LanguageCatalog.targets, id: \.self) { code in
                    Text(LanguageCatalog.name(of: code)).tag(code)
                }
            }
            Picker("Text is in", selection: model.settings.binding(TranslationKeys.sourceLanguage)) {
                Text("Detect Automatically").tag("")
                Divider()
                ForEach(LanguageCatalog.targets, id: \.self) { code in
                    Text(LanguageCatalog.name(of: code)).tag(code)
                }
            }
            Picker("Default provider", selection: model.settings.binding(TranslationKeys.defaultProvider)) {
                ForEach(model.selectableConfigs) { config in
                    Text(config.displayName).tag(config.id.rawValue)
                }
            }
            if model.offersHighFidelity {
                Toggle("Use high-fidelity Apple Translation", isOn: model.settings.binding(TranslationKeys.appleHighFidelity))
                    .help("Slower, better translations with Apple Intelligence")
            }
            LabeledContent("Apple Translation language packs") {
                Button("Download…") { model.showsLanguagePackSheet = true }
            }
        }
    }

    private var providers: some View {
        Section {
            ForEach(model.configs) { config in
                ProviderSettingsRow(model: model, config: model.binding(for: config.id))
            }
        } header: {
            HStack {
                Text("Providers")
                Spacer()
                Menu("Add Provider") {
                    ForEach(ProviderPreset.allCases) { preset in
                        Button(preset.title) { model.add(preset) }
                    }
                }
                .fixedSize()
            }
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(
                    "⌘1…⌘9 switch between enabled providers in the translation toolbar, in this order. API keys are stored in the Keychain."
                )
                if let note = model.hiddenProviderNote {
                    Text(note)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var glossary: some View {
        Section {
            TextEditor(text: model.glossary)
                .font(.body.monospaced())
                .frame(minHeight: 60)
        } header: {
            Text("Glossary")
        } footer: {
            Text("One “term = translation” per line. Language-model providers keep these translations.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var history: some View {
        Section("History") {
            Toggle("Keep a history of translations", isOn: model.settings.binding(TranslationKeys.historyEnabled))
            Picker("Keep translations for", selection: model.settings.binding(TranslationKeys.historyRetentionDays)) {
                ForEach(Self.retentionChoices, id: \.self) { days in
                    Text(days == 0 ? "Until Deleted" : "\(days) Days").tag(days)
                }
            }
            .disabled(!model.settings[TranslationKeys.historyEnabled])
            HStack {
                Button("Open History…", action: model.openHistory)
                Spacer()
                Button("Clear History", role: .destructive) {
                    Task { await model.clearHistory() }
                }
            }
        }
    }
}
