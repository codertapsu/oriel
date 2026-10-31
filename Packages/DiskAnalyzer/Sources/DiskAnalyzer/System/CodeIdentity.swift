import Security

/// Oriel's code identity, read from its own signature: what each end of the privileged helper's XPC connection asks of
/// the other (`PrivilegedReader`). A build without a team, signed ad hoc as CI signs it, has none, and is not offered the
/// helper.
nonisolated enum CodeIdentity {
    /// The extension Apple puts in Developer ID Application certificates, and the one in the authority that issues them.
    static let developerIDApplication = "1.2.840.113635.100.6.1.13"
    static let developerIDAuthority = "1.2.840.113635.100.6.2.6"

    /// A code requirement only Oriel meets: its identifier, signed by its team with a certificate Apple issued. A release
    /// (`developerID`) also wants the other end signed with Developer ID and closed to debuggers: a build with
    /// `get-task-allow`, as every Release build made on this Mac has and no notarized one may, lets any process of the
    /// user's take it over and speak through it. A Debug build is signed for development and always debuggable; it has
    /// its own identifier and helper (CLAUDE.md rule 14), so it keeps the plain requirement.
    static func requirement(identifier: String, team: String, developerID: Bool) -> String {
        let signed = "identifier \"\(identifier)\" and anchor apple generic and certificate leaf[subject.OU] = \"\(team)\""
        guard developerID else { return signed }
        return signed + " and certificate 1[field.\(developerIDAuthority)] exists"
            + " and certificate leaf[field.\(developerIDApplication)] exists"
            + " and !entitlement[\"com.apple.security.get-task-allow\"] exists"
    }

    /// That requirement for this process's own signature; nil without a team.
    static func ownRequirement() -> String? {
        var code: SecCode?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code else { return nil }
        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode else { return nil }
        var information: CFDictionary?
        let flags = SecCSFlags(rawValue: kSecCSSigningInformation)
        guard SecCodeCopySigningInformation(staticCode, flags, &information) == errSecSuccess,
              let values = information as? [String: Any],
              let identifier = values[kSecCodeInfoIdentifier as String] as? String,
              let team = values[kSecCodeInfoTeamIdentifier as String] as? String
        else { return nil }
        let leaf = (values[kSecCodeInfoCertificates as String] as? [SecCertificate])?.first
        return requirement(identifier: identifier, team: team, developerID: leaf.map(isDeveloperIDApplication) ?? false)
    }

    /// Whether `certificate` is a Developer ID Application certificate.
    static func isDeveloperIDApplication(_ certificate: SecCertificate) -> Bool {
        let values = SecCertificateCopyValues(certificate, [developerIDApplication] as CFArray, nil) as? [String: Any]
        return values?[developerIDApplication] != nil
    }
}
