import AppKit

/// A round hover button on a tile. Accepts the first click, because the panel never becomes key.
final class TileActionButton: NSButton {
    static let side: CGFloat = 22

    let tileAction: TileAction
    private let handler: (TileAction) -> Void

    init(_ tileAction: TileAction, handler: @escaping (TileAction) -> Void) {
        self.tileAction = tileAction
        self.handler = handler
        super.init(frame: CGRect(x: 0, y: 0, width: Self.side, height: Self.side))
        let configuration = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
        image = NSImage(systemSymbolName: tileAction.symbolName, accessibilityDescription: tileAction.label)?
            .withSymbolConfiguration(configuration)
        imagePosition = .imageOnly
        isBordered = false
        contentTintColor = .white
        wantsLayer = true
        layer?.cornerRadius = Self.side / 2
        layer?.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
        toolTip = tileAction.label
        setAccessibilityLabel(tileAction.label)
        target = self
        action = #selector(run)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func acceptsFirstMouse(for _: NSEvent?) -> Bool {
        true
    }

    @objc private func run() {
        handler(tileAction)
    }
}
