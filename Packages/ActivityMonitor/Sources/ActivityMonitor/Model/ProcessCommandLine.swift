/// A process's command line, from `sysctl(KERN_PROCARGS2)`, which macOS answers only for the user's own processes.
///
/// The buffer holds `argc`, the executable path, padding, the arguments, then the environment. The environment is never
/// read: it often holds tokens and passwords.
nonisolated struct ProcessCommandLine: Sendable, Equatable {
    let executable: String
    let arguments: [String]

    init(executable: String, arguments: [String]) {
        self.executable = executable
        self.arguments = arguments
    }

    init?(procargs bytes: [UInt8]) {
        guard bytes.count >= 4 else { return nil }
        let argc = bytes.withUnsafeBytes { $0.loadUnaligned(as: Int32.self) }
        guard (0 ... 65536).contains(argc) else { return nil }
        var index = 4
        func string() -> String? {
            guard index < bytes.count else { return nil }
            let end = bytes[index...].firstIndex(of: 0) ?? bytes.count
            defer { index = end + 1 }
            return ByteText.string(bytes[index ..< end])
        }
        guard let executable = string() else { return nil }
        // The path is padded with NULs to a word boundary before argv starts.
        while index < bytes.count, bytes[index] == 0 {
            index += 1
        }
        var arguments: [String] = []
        while arguments.count < argc, let argument = string() {
            arguments.append(argument)
        }
        self.init(executable: executable, arguments: arguments)
    }
}
