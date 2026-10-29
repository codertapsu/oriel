import Foundation

/// Who signed a process's executable, from `SecStaticCode`: the file on disk, which anyone can read, so this works for
/// every user's processes.
nonisolated struct CodeSignatureInfo: Sendable, Equatable {
    enum Authority: String, Sendable {
        /// Part of macOS, or another Apple program signed by Apple.
        case apple
        case appStore
        case developerID
        /// Signed by a development certificate or another chain.
        case other
        /// Signed without a certificate, as local builds are.
        case adHoc
        case unsigned
        /// The file could not be read or its signature is broken.
        case invalid

        var title: String {
            switch self {
            case .apple: "Apple"
            case .appStore: "Mac App Store"
            case .developerID: "Developer ID"
            case .other: "Other certificate"
            case .adHoc: "Ad hoc (no certificate)"
            case .unsigned: "Not signed"
            case .invalid: "Invalid signature"
            }
        }
    }

    let authority: Authority
    let identifier: String?
    let teamID: String?
    /// The leaf certificate's name, "Developer ID Application: Google LLC (EQHXZ8M8AV)".
    let signer: String?
    let isSandboxed: Bool
    let hasHardenedRuntime: Bool

    /// One line for the details: "Developer ID · Google LLC (EQHXZ8M8AV)".
    var summary: String {
        var parts = [authority.title]
        if let signer, authority == .developerID || authority == .other {
            parts.append(signer.replacingOccurrences(of: "Developer ID Application: ", with: ""))
        } else if let teamID {
            parts.append("Team \(teamID)")
        }
        return parts.joined(separator: " · ")
    }
}
