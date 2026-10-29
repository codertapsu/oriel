import OrielCore

/// Capture's commands (PLAN §6.5), the capture modes beyond the app's own actions, such as Capture Text.
extension CaptureCoordinator: CommandProviding {
    public var commands: [ToolCommand] {
        []
    }
}
