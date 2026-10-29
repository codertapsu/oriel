/// What the details pane reads once for the selected process, off the main thread.
nonisolated struct ProcessDetails: Sendable, Equatable {
    /// The user's own processes only.
    var commandLine: ProcessCommandLine?
    /// The user's own processes only.
    var openFiles: [OpenFile]?
    var signature: CodeSignatureInfo?
}
