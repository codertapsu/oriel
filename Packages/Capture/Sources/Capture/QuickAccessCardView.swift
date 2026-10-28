import AppKit
import OrielCore
import SharedUI

/// One card of the Quick Access Overlay: the thumbnail (drag it out, double-click to annotate), a row of actions and,
/// on hover, a close button. Hovering pauses the card's auto-dismiss.
final class QuickAccessCardView: NSView {
    static let size = CGSize(width: 264, height: 214)

    let thumbnail: ThumbnailView
    var onHover: ((Bool) -> Void)?
    private let actions: [QuickAccessAction]
    private let perform: (QuickAccessAction) -> Void
    private let closeButton: HUDButton

    init(result: CaptureResult, actions: [QuickAccessAction], perform: @escaping @MainActor (QuickAccessAction) -> Void) {
        thumbnail = ThumbnailView(image: result.image)
        self.actions = actions
        self.perform = perform
        closeButton = HUDButton(symbol: QuickAccessAction.close.symbol, label: QuickAccessAction.close.label) { perform(.close) }
        super.init(frame: CGRect(origin: .zero, size: Self.size))
        let background = Material.make(cornerRadius: 16)
        background.frame = bounds
        background.autoresizingMask = [.width, .height]
        addSubview(background)

        let buttons = actions.filter { $0 != .close }.map { action in
            HUDButton(symbol: action.symbol, label: action.label) { perform(action) }
        }
        let row = NSStackView(views: buttons)
        row.orientation = .horizontal
        row.distribution = .equalSpacing
        row.translatesAutoresizingMaskIntoConstraints = false
        thumbnail.translatesAutoresizingMaskIntoConstraints = false
        closeButton.isHidden = true
        let content = background.contentView
        content.addSubview(thumbnail)
        content.addSubview(row)
        content.addSubview(closeButton)
        NSLayoutConstraint.activate([
            thumbnail.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 8),
            thumbnail.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -8),
            thumbnail.topAnchor.constraint(equalTo: content.topAnchor, constant: 8),
            thumbnail.bottomAnchor.constraint(equalTo: row.topAnchor, constant: -6),
            row.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            row.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            row.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -6),
            row.heightAnchor.constraint(equalToConstant: 30),
            closeButton.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 2),
            closeButton.topAnchor.constraint(equalTo: content.topAnchor, constant: 2),
        ])
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Capture, \(result.image.width) by \(result.image.height) pixels")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func mouseEntered(with _: NSEvent) {
        closeButton.isHidden = false
        onHover?(true)
    }

    override func mouseExited(with _: NSEvent) {
        closeButton.isHidden = true
        onHover?(false)
    }

    override func menu(for _: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        for action in actions {
            menu.addItem(ActionMenuItem(action.label, symbol: action.symbol) { [perform] in perform(action) })
        }
        return menu
    }
}
