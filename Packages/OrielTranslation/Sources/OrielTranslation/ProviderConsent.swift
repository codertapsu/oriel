import AppKit
import OrielCore

/// Consent to send what Oriel reads from the screen or a file to a provider off this Mac (App Review Guidelines
/// 5.1.2(i), PLAN §19): asked once per provider before its first request, and kept until it is taken back in
/// Settings → Translation. Apple Translation, Apple Intelligence and servers on this Mac need none.
@MainActor
struct ProviderConsent {
    static let key = SettingKey<[String]>("translation.consentedProviders", default: [])

    let settings: SettingsStore

    /// Whether requests to `config` leave this Mac.
    nonisolated static func isNeeded(for config: ProviderConfig) -> Bool {
        config.kind.usesNetwork && !Endpoint.isLocal(config.baseURL)
    }

    /// Whether the provider may receive a request now.
    func isGranted(_ config: ProviderConfig) -> Bool {
        !Self.isNeeded(for: config) || settings[Self.key].contains(config.id.rawValue)
    }

    func set(_ granted: Bool, for config: ProviderConfig) {
        settings[Self.key] = settings[Self.key].filter { $0 != config.id.rawValue } + (granted ? [config.id.rawValue] : [])
    }

    /// Asks, above Oriel's overlays, whether `config` may receive the text, unless it may already; false when the user
    /// declines.
    func request(_ config: ProviderConfig) -> Bool {
        guard !isGranted(config) else { return true }
        let name = config.displayName
        let images = config.kind == .openAICompatible || config.kind == .anthropic ? " (with AI Vision, the image itself)" : ""
        let alert = NSAlert()
        alert.messageText = "Send text to \(name) for translation?"
        alert.informativeText = "To translate, Oriel sends the text it reads from your screen or a file\(images) to \(name), "
            + "whose privacy policy then applies. Nothing goes to \(name) until you allow it, and Settings → Translation "
            + "takes it back. Apple Translation and Apple Intelligence translate on this Mac."
        alert.addButton(withTitle: "Allow")
        alert.addButton(withTitle: "Don't Allow")
        alert.window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        set(true, for: config)
        return true
    }
}
