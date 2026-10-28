import AppKit

/// The hover buttons of a tile (PLAN §1.2): close, minimize or restore, full screen.
final class TileActionBar: NSView {
    var onAction: ((TileAction) -> Void)?
    private var buttons: [TileActionButton] = []
    private static let spacing: CGFloat = 4

    override var isFlipped: Bool {
        true
    }

    var fittingWidth: CGFloat {
        CGFloat(buttons.count) * TileActionButton.side + CGFloat(max(buttons.count - 1, 0)) * Self.spacing
    }

    func configure(isMinimized: Bool) {
        let actions = TileAction.actions(isMinimized: isMinimized)
        guard actions != buttons.map(\.tileAction) else { return }
        buttons.forEach { $0.removeFromSuperview() }
        buttons = actions.map { action in
            let button = TileActionButton(action) { [weak self] in self?.onAction?($0) }
            addSubview(button)
            return button
        }
        needsLayout = true
    }

    override func layout() {
        super.layout()
        for (index, button) in buttons.enumerated() {
            button.frame = CGRect(
                x: CGFloat(index) * (TileActionButton.side + Self.spacing), y: 0, width: TileActionButton.side,
                height: TileActionButton.side
            )
        }
    }
}
