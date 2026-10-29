/// Reads the selected process's details: its command line and open files when it is the user's own, and its code
/// signature whoever owns it. Each read is a few milliseconds of system calls and file reads, so it runs off the main
/// thread.
nonisolated enum ProcessInspector {
    static func details(of pid: Int32, path: String?, isMine: Bool) -> ProcessDetails {
        ProcessDetails(
            commandLine: isMine ? ProcessTable.commandLine(of: pid) : nil,
            openFiles: isMine ? OpenFileReader.openFiles(of: pid) : nil,
            signature: path.map(CodeSignatureReader.signature(atPath:))
        )
    }
}
