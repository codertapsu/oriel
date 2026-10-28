import AppKit

/// One display's freeze-frame window (PLAN §7.2, item 2): borderless, at screen-saver level, on every Space and over
/// full-screen apps, showing the display as it was when the capture began, or see-through over the live screen. It
/// draws what the controller's `OverlayScene` says and forwards every event to the controller.
///
/// A non-activating panel that can become key: the controller asks for activation (so the pointer can be set), and
/// should macOS decline it the panel still receives the keyboard, so Esc, Return and the arrows keep working.
final class OverlayWindow: NSPanel {
    let backdrop: SelectionBackdrop
    let geometry: OverlayGeometry
    weak var handler: OverlayEventHandling? {
        didSet { chrome.handler = handler }
    }

    private let chrome: OverlayChromeView
    private let magnifier = MagnifierView(frame: CGRect(origin: .zero, size: MagnifierView.size))
    private let readout = OverlayBadge(fontSize: 12, monospacedDigits: true)
    private let hint = OverlayBadge(fontSize: 13, monospacedDigits: false)
    private var selectionToolbar: OverlayToolbar?

    init(backdrop: SelectionBackdrop, screen: NSScreen, tools: [OverlayTool]) {
        self.backdrop = backdrop
        geometry = OverlayGeometry(displayFrame: backdrop.display.frame, scale: backdrop.display.scale)
        let bounds = CGRect(origin: .zero, size: screen.frame.size)
        chrome = OverlayChromeView(frame: bounds, image: backdrop.image, geometry: geometry)
        super.init(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = false
        if backdrop.image == nil {
            // See-through over the live screen. Set explicitly, mouse events still arrive where nothing is drawn,
            // such as inside the selection, instead of falling through to the app underneath.
            isOpaque = false
            backgroundColor = .clear
            ignoresMouseEvents = false
        } else {
            isOpaque = true
            backgroundColor = .black
        }
        hasShadow = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        acceptsMouseMovedEvents = true
        isMovable = false

        let container = NSView(frame: bounds)
        chrome.autoresizingMask = [.width, .height]
        container.addSubview(chrome)
        magnifier.isHidden = true
        container.addSubview(magnifier)
        container.addSubview(readout)
        container.addSubview(hint)
        let toolbar = OverlayToolbar(tools: tools) { [weak self] tool in
            self?.handler?.overlay(.tool(tool))
        }
        container.addSubview(toolbar)
        selectionToolbar = toolbar
        contentView = container
        setFrame(screen.frame, display: false)
    }

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    override func keyDown(with event: NSEvent) {
        _ = handler?.overlayKeyDown(event)
    }

    override func keyUp(with event: NSEvent) {
        handler?.overlayKeyUp(event)
    }

    /// ⌘-keys arrive here first. All of them are swallowed while the overlay is up, so ⌘Q cannot quit mid-capture.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown, event.modifierFlags.contains(.command) else {
            return super.performKeyEquivalent(with: event)
        }
        _ = handler?.overlayKeyDown(event)
        return true
    }

    func render(_ scene: OverlayScene) {
        chrome.render(scene)
        let bounds = contentView?.bounds ?? .zero
        let pointer = scene.pointer.map(geometry.viewPoint)

        if let patch = scene.magnifier, let pointer {
            magnifier.patch = patch
            magnifier.caption = scene.magnifierCaption
            magnifier.setFrameOrigin(Self.place(MagnifierView.size, near: pointer, in: bounds))
            magnifier.isHidden = false
        } else {
            magnifier.isHidden = true
        }

        let selection = scene.selection.map(geometry.viewRect)
        layOutToolbar(selection: scene.showsToolbar ? selection : nil, in: bounds)
        readout.text = scene.readout
        // The readout labels the selection, or in window mode the highlighted window.
        let highlight = scene.highlightIsStrong ? scene.highlight.map(geometry.viewRect)?.intersection(bounds) : nil
        if let anchor = selection ?? highlight, !anchor.isNull, !readout.isHidden {
            readout.setFrameOrigin(readoutOrigin(for: anchor, in: bounds))
        }

        hint.text = scene.hint
        if !hint.isHidden {
            let size = hint.frame.size
            var origin = CGPoint(x: (bounds.midX - size.width / 2).rounded(), y: bounds.maxY - 64 - size.height)
            if let pointer, pointer.y > origin.y - 48 {
                origin.y = 48
            }
            hint.setFrameOrigin(origin)
        }
    }

    private func layOutToolbar(selection: CGRect?, in bounds: CGRect) {
        guard let toolbar = selectionToolbar else { return }
        guard let selection else {
            toolbar.isHidden = true
            return
        }
        let size = toolbar.frame.size
        var origin = CGPoint(x: selection.maxX - size.width, y: selection.minY - size.height - 8)
        if origin.y < 4 {
            origin.y = selection.maxY + 8
            if origin.y + size.height > bounds.maxY - 4 {
                origin.y = selection.minY + 8
            }
        }
        origin.x = min(max(origin.x, 4), bounds.maxX - size.width - 4)
        toolbar.setFrameOrigin(origin)
        toolbar.isHidden = false
    }

    /// Below the selection's left edge, or above it when the toolbar is in the way, or inside at the screen's edge.
    private func readoutOrigin(for selection: CGRect, in bounds: CGRect) -> CGPoint {
        let size = readout.frame.size
        var origin = CGPoint(x: selection.minX, y: selection.minY - size.height - 6)
        if origin.y < 4 {
            origin.y = selection.minY + 6
        }
        origin.x = min(max(origin.x, 4), bounds.maxX - size.width - 4)
        if let toolbar = selectionToolbar, !toolbar.isHidden, toolbar.frame.intersects(CGRect(origin: origin, size: size)) {
            origin.y = selection.maxY + 6 + size.height < bounds.maxY ? selection.maxY + 6 : selection.maxY - size.height - 6
        }
        return origin
    }

    /// Below and to the right of the pointer, flipped to the other side near the screen's edges.
    private static func place(_ size: CGSize, near pointer: CGPoint, in bounds: CGRect) -> CGPoint {
        var origin = CGPoint(x: pointer.x + 24, y: pointer.y - 24 - size.height)
        if origin.x + size.width > bounds.maxX - 4 {
            origin.x = pointer.x - 24 - size.width
        }
        if origin.y < 4 {
            origin.y = pointer.y + 24
        }
        return origin
    }
}
