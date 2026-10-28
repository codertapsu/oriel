import AppKit

/// A borderless SF Symbol button with a tooltip and a closure, for HUD toolbars.
public final class HUDButton: NSButton {
    private let handler: @MainActor () -> Void

    public init(symbol: String, label: String, handler: @escaping @MainActor () -> Void) {
        self.handler = handler
        super.init(frame: .zero)
        image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        imagePosition = .imageOnly
        isBordered = false
        bezelStyle = .regularSquare
        contentTintColor = .labelColor
        toolTip = label
        setAccessibilityLabel(label)
        target = self
        action = #selector(run)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 28).isActive = true
        heightAnchor.constraint(equalToConstant: 28).isActive = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Panels that never become key would otherwise swallow the first click.
    override public func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    @objc private func run() {
        handler()
    }
}
