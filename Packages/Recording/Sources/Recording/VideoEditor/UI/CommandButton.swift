import AppKit

/// A borderless symbol button that sends a video editor command, for the transport bar.
final class CommandButton: NSButton {
    private let command: VideoEditorCommand
    private let handler: (VideoEditorCommand) -> Void

    init(command: VideoEditorCommand, handler: @escaping (VideoEditorCommand) -> Void) {
        self.command = command
        self.handler = handler
        super.init(frame: .zero)
        imagePosition = .imageOnly
        isBordered = false
        bezelStyle = .regularSquare
        contentTintColor = .labelColor
        symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        target = self
        action = #selector(run)
        // Keys belong to the editor (Space plays), not to whichever button was clicked last.
        refusesFirstResponder = true
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 28).isActive = true
        heightAnchor.constraint(equalToConstant: 26).isActive = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func run() {
        handler(command)
    }
}
