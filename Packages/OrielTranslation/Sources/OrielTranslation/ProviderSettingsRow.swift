import OrielCore
import SharedUI
import SwiftUI
import UniformTypeIdentifiers

/// One provider in Settings: an enable switch and, expanded, everything configurable about it (PLAN §7.7.5).
struct ProviderSettingsRow: View {
    let model: TranslationSettingsModel
    @Binding var config: ProviderConfig
    @State private var isExpanded = false
    @State private var importsServiceAccount = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                TextField("Name", text: $config.displayName)
                if config.kind.usesNetwork {
                    connection
                }
                if config.kind.requiresAPIKey || config.kind == .openAICompatible {
                    apiKey
                }
                options
                usage
                actions
            }
            .padding(.vertical, 6)
        } label: {
            Toggle(isOn: $config.isEnabled) {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(config.displayName)
                        if config.kind.needsPro {
                            ProBadge(.translationProviders)
                        }
                    }
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .fileImporter(isPresented: $importsServiceAccount, allowedContentTypes: [.json]) { result in
            if case let .success(url) = result {
                model.importServiceAccount(from: url, for: config.id)
            }
        }
    }

    private var subtitle: String {
        let model = config.model.trimmingCharacters(in: .whitespaces)
        return model.isEmpty ? config.kind.displayName : "\(config.kind.displayName) · \(model)"
    }

    @ViewBuilder private var connection: some View {
        TextField("Endpoint", text: $config.baseURL, prompt: Text(config.kind.defaultBaseURL ?? "http://localhost:11434/v1"))
            .textContentType(.URL)
        HStack {
            TextField(
                config.kind.requiresModel ? "Model" : "Model (optional)", text: $config.model,
                prompt: Text(config.kind.requiresModel ? "Required" : "Default")
            )
            if model.canFetchModels(config) {
                Menu("Models") {
                    Button("Fetch from Server") { model.fetchModels(config.id) }
                    if let models = model.fetchedModels[config.id], !models.isEmpty {
                        Divider()
                        ForEach(models, id: \.self) { name in
                            Button(name) { config.model = name }
                        }
                    }
                }
                .fixedSize()
            }
        }
    }

    /// What the empty key field says. A Google provider with a glossary uses the service account key instead.
    private var keyPrompt: String {
        if model.hasKey(config.id) {
            return "Stored in the Keychain"
        }
        if config.kind == .google, !config.glossaryResource.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Not used with a glossary"
        }
        return config.kind.requiresAPIKey ? "Required" : "Optional"
    }

    private var apiKey: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                SecureField(
                    "API key", text: Binding(get: { model.keyDrafts[config.id] ?? "" }, set: { model.keyDrafts[config.id] = $0 }),
                    prompt: Text(keyPrompt)
                )
                Button("Save") { model.saveKey(for: config.id) }
                    .disabled((model.keyDrafts[config.id] ?? "").isEmpty)
                if model.hasKey(config.id) {
                    Button("Remove", role: .destructive) { model.deleteKey(for: config.id) }
                }
            }
            if let message = model.keyMessages[config.id] {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var options: some View {
        if config.kind.countsTokens {
            HStack {
                Toggle("Temperature", isOn: Binding(
                    get: { config.temperature != nil },
                    set: { config.temperature = $0 ? (config.temperature ?? 0.2) : nil }
                ))
                if let temperature = config.temperature {
                    Slider(value: Binding(get: { temperature }, set: { config.temperature = ($0 * 20).rounded() / 20 }), in: 0 ... 2)
                    Text(temperature.formatted(.number.precision(.fractionLength(2)))).monospacedDigit()
                }
            }
        }
        if config.kind.usesNetwork {
            Stepper(value: $config.timeoutSeconds, in: 5 ... 600, step: 5) {
                Text("Timeout: \(Int(config.timeoutSeconds)) s")
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Custom headers, one “Name: value” per line").font(.caption).foregroundStyle(.secondary)
                TextEditor(text: model.headerText(for: config))
                    .font(.body.monospaced())
                    .frame(minHeight: 36, maxHeight: 80)
            }
        }
        switch config.kind {
        case .openAICompatible:
            Toggle("Ask for structured JSON output", isOn: $config.usesStructuredOutput)
                .help("Uses response_format when the server supports it, and retries without it when it doesn't")
            if let warning = model.localModelWarning(for: config) {
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .anthropic:
            Stepper(value: $config.maxOutputTokens, in: 256 ... 64000, step: 256) {
                Text("Maximum answer length: \(config.maxOutputTokens) tokens")
            }
        case .deepl:
            Picker("Formality", selection: $config.formality) {
                Text("Default").tag(ProviderConfig.Formality.automatic)
                Text("More formal").tag(ProviderConfig.Formality.more)
                Text("Less formal").tag(ProviderConfig.Formality.less)
            }
        case .google:
            googleGlossary
        case .apple, .foundationModels:
            EmptyView()
        }
    }

    /// A glossary moves Google to Cloud Translation Advanced (v3), which takes a service account key instead.
    @ViewBuilder private var googleGlossary: some View {
        TextField("Glossary (optional)", text: $config.glossaryResource, prompt: Text("projects/…/locations/us-central1/glossaries/…"))
        HStack {
            if let email = model.serviceAccountEmail(config.id) {
                Label(email, systemImage: "person.badge.key")
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Remove Key", role: .destructive) { model.removeServiceAccount(for: config.id) }
            } else {
                Button("Add Service Account Key…") { importsServiceAccount = true }
            }
        }
        Text(Self.glossaryNote)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private static let glossaryNote = """
    With a glossary, Google uses Cloud Translation Advanced, which takes a service account key (the JSON file from \
    the Google Cloud console) instead of the API key. A glossary named by its ID is looked for in us-central1 of \
    the key's project.
    """

    @ViewBuilder private var usage: some View {
        if config.kind.usesNetwork {
            HStack {
                TextField(
                    config.kind.countsTokens ? "Monthly cap (tokens)" : "Monthly cap (characters)", value: $config.monthlyCap,
                    format: .number,
                    prompt: Text("No cap")
                )
                Button("Reset Counter") { model.resetUsage(config.id) }
            }
            Text(model.usageText(for: config)).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var actions: some View {
        HStack {
            Button("Test Connection") { model.test(config.id) }
                .disabled(model.tests[config.id] == .running)
            switch model.tests[config.id] {
            case .running:
                ProgressView().controlSize(.small)
            case let .succeeded(message):
                Label(message, systemImage: "checkmark.circle").foregroundStyle(.green).font(.caption)
            case let .failed(message):
                Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.red).font(.caption)
            case nil:
                EmptyView()
            }
            Spacer()
            if !config.isBuiltIn {
                Button("Remove Provider", role: .destructive) { model.remove(config.id) }
            }
        }
    }
}
