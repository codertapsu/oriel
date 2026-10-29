import SwiftUI

/// Settings → Translation (PLAN §7.7.5, §17): languages, default provider, every provider's endpoint, model, key and
/// options with "Test connection", the language-pack sheet, glossary projects and history.
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
        .task { await model.glossaries.loadIfNeeded() }
        .sheet(isPresented: $model.showsLanguagePackSheet) {
            LanguagePackDownloadView(
                source: "en", target: targetCode == "en" ? "fr" : targetCode, allowsChoosingLanguages: true
            ) { _ in model.showsLanguagePackSheet = false }
        }
        .sheet(isPresented: $model.showsGlossaryEditor) {
            GlossaryEditorView(glossaries: model.glossaries) {
                model.showsGlossaryEditor = false
                Task { await model.glossaries.saveNow() }
            }
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
            Picker("Use glossary", selection: model.activeGlossary) {
                Text("None").tag(UUID?.none)
                if !model.glossaries.projects.isEmpty {
                    Divider()
                }
                ForEach(model.glossaries.projects) { project in
                    Text(project.name.isEmpty ? "Untitled" : project.name).tag(UUID?.some(project.id))
                }
            }
            LabeledContent("Glossary projects") {
                Button("Edit Glossaries…") { model.showsGlossaryEditor = true }
            }
            if let problem = model.glossaries.loadProblem {
                Label(problem, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        } header: {
            Text("Glossary")
        } footer: {
            Text(Self.glossaryFooter)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private static let glossaryFooter = """
    A glossary keeps names and terms translated the same way. DeepL uses its own glossaries, Google a Cloud \
    glossary named in the project, language models get the terms that occur in the text, and Apple Translation keeps \
    them with placeholders.
    """

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
