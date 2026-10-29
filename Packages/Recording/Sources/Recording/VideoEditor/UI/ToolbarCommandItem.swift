import AppKit

/// A toolbar item that sends a video editor command.
final class ToolbarCommandItem: NSToolbarItem {
    private let command: VideoEditorCommand
    private let handler: (VideoEditorCommand) -> Void

    init(itemIdentifier: NSToolbarItem.Identifier, command: VideoEditorCommand, handler: @escaping (VideoEditorCommand) -> Void) {
        self.command = command
        self.handler = handler
        super.init(itemIdentifier: itemIdentifier)
        target = self
        action = #selector(run)
    }

    @objc private func run() {
        handler(command)
    }
}
