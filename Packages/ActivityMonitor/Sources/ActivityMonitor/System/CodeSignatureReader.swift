import Foundation
import Security

/// Reads who signed an executable from its file (`SecStaticCode`), checking the signature's structure and its
/// certificate chain but not hashing every file of the bundle, which can take seconds for a large app.
nonisolated enum CodeSignatureReader {
    static func signature(atPath path: String) -> CodeSignatureInfo {
        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(URL(fileURLWithPath: path) as CFURL, [], &staticCode) == errSecSuccess,
              let code = staticCode
        else { return info(.invalid) }
        var information: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
              let details = information as? [String: Any]
        else { return info(.invalid) }
        guard let identifier = details[kSecCodeInfoIdentifier as String] as? String else { return info(.unsigned) }
        let flags = SecCodeSignatureFlags(rawValue: (details[kSecCodeInfoFlags as String] as? NSNumber)?.uint32Value ?? 0)
        let certificates = details[kSecCodeInfoCertificates as String] as? [SecCertificate] ?? []
        let entitlements = details[kSecCodeInfoEntitlementsDict as String] as? [String: Any]
        return CodeSignatureInfo(
            authority: authority(of: code, flags: flags),
            identifier: identifier,
            teamID: details[kSecCodeInfoTeamIdentifier as String] as? String,
            signer: certificates.first.flatMap { SecCertificateCopySubjectSummary($0) as String? },
            isSandboxed: entitlements?["com.apple.security.app-sandbox"] as? Bool == true,
            hasHardenedRuntime: flags.contains(.runtime)
        )
    }

    private static func authority(of code: SecStaticCode, flags: SecCodeSignatureFlags) -> CodeSignatureInfo.Authority {
        if flags.contains(.adhoc) {
            return .adHoc
        }
        guard SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSBasicValidateOnly), nil) == errSecSuccess else {
            return .invalid
        }
        if satisfies(code, "anchor apple") {
            return .apple
        }
        if satisfies(code, "anchor apple generic and certificate leaf[field.1.2.840.113635.100.6.1.9] exists") {
            return .appStore
        }
        let developerID = "anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists"
            + " and certificate leaf[field.1.2.840.113635.100.6.1.13] exists"
        return satisfies(code, developerID) ? .developerID : .other
    }

    private static func satisfies(_ code: SecStaticCode, _ text: String) -> Bool {
        var requirement: SecRequirement?
        guard SecRequirementCreateWithString(text as CFString, [], &requirement) == errSecSuccess, let requirement else { return false }
        return SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSBasicValidateOnly), requirement) == errSecSuccess
    }

    private static func info(_ authority: CodeSignatureInfo.Authority) -> CodeSignatureInfo {
        CodeSignatureInfo(authority: authority, identifier: nil, teamID: nil, signer: nil, isSandboxed: false, hasHardenedRuntime: false)
    }
}
