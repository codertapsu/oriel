import Darwin

/// User names by uid. A system account such as `_windowserver` comes from Open Directory, which takes an IPC round
/// trip, so the sampler asks once per uid and keeps the answer.
nonisolated enum UserDirectory {
    static func name(of uid: UInt32) -> String {
        var entry = passwd()
        var result: UnsafeMutablePointer<passwd>?
        var buffer = [CChar](repeating: 0, count: 2048)
        guard getpwuid_r(uid, &entry, &buffer, buffer.count, &result) == 0, result != nil, let name = entry.pw_name else {
            return String(uid)
        }
        return String(cString: name)
    }
}
