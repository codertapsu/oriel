import Security

/// Oriel's code identity, read from its own signature: what each end of the privileged helper's XPC connection asks of
/// the other (`PrivilegedReader`). A build without a team, signed ad hoc as CI signs it, has none, and is not offered the
/// helper.
nonisolated enum CodeIdentity {
    /// A code requirement only Oriel meets: its identifier, signed by its team with a certificate Apple issued.
    static func requirement(identifier: String, team: String) -> String {
        "identifier \"\(identifier)\" and anchor apple generic and certificate leaf[subject.OU] = \"\(team)\""
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
        return requirement(identifier: identifier, team: team)
    }
}
