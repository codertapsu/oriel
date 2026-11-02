import FoundationModels
import OrielCore
import Permissions
import Translation
#if !APP_STORE
    import PrivateAPIs
#endif

/// Fills in `Capabilities` (PLAN §3.2) for Settings → Diagnostics and `oriel debug capabilities --json`.
@MainActor
enum CapabilitiesProbe {
    static func current(permissions: PermissionCenter, translationPair: (source: String, target: String)) async -> Capabilities {
        await Capabilities(
            appleIntelligence: appleIntelligence(),
            translationPacks: translationPacks(translationPair),
            privateSymbols: privateSymbols,
            permissions: permissions.summary
        )
    }

    /// None in the App Store edition, which links no private API (PLAN §19).
    private static var privateSymbols: [String: Bool] {
        #if APP_STORE
            [:]
        #else
            PrivateAPIs.shared.presenceByName
        #endif
    }

    static func appleIntelligence() -> String {
        switch SystemLanguageModel.default.availability {
        case .available: "available"
        case let .unavailable(reason): "unavailable: \(reason)"
        }
    }

    static func translationPacks(_ pair: (source: String, target: String)) async -> String {
        let status = await LanguageAvailability().status(
            from: Locale.Language(identifier: pair.source),
            to: Locale.Language(identifier: pair.target)
        )
        let state = switch status {
        case .installed: "installed"
        case .supported: "supported, not downloaded"
        case .unsupported: "unsupported"
        @unknown default: "unknown"
        }
        return "\(state) \(pair.source)→\(pair.target)"
    }
}
