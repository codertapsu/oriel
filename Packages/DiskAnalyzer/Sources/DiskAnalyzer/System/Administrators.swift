import Darwin.membership

/// Whether an account is an administrator's: a member of the `admin` group, directly or through nested groups, as
/// macOS's directory services say (`mbr_check_membership`). Oriel's helper answers administrators only, who could read
/// the folders it lists anyway, with `sudo` and their password (`PrivilegedReaderListener`).
nonisolated enum Administrators {
    static func contains(_ userID: uid_t) -> Bool {
        var user = [UInt8](repeating: 0, count: 16)
        var group = [UInt8](repeating: 0, count: 16)
        var isMember: Int32 = 0
        guard mbr_uid_to_uuid(userID, &user) == 0,
              mbr_identifier_to_uuid(ID_TYPE_GROUPNAME, "admin", strlen("admin"), &group) == 0,
              mbr_check_membership(user, group, &isMember) == 0
        else { return false }
        return isMember != 0
    }
}
