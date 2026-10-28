import AppKit

/// A borderless panel that floats above other apps without activating Oriel, so the app the user is in keeps
/// focus (PLAN §7.1.10). Used by the switcher, the Quick Access Overlay, the recording bar and toolbars.
public final class FloatingPanel: NSPanel {
    /// Whether the panel may become key, e.g. to take typing in a search field. Off by default.
    public var allowsKey = false

    public init(contentRect: CGRect = .zero, level: NSWindow.Level = .popUpMenu, joinsAllSpaces: Bool = true) {
        super.init(contentRect: contentRect, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: true)
        self.level = level
        var behavior: NSWindow.CollectionBehavior = [.fullScreenAuxiliary, .transient, .ignoresCycle]
        if joinsAllSpaces {
            behavior.insert(.canJoinAllSpaces)
        }
        collectionBehavior = behavior
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
        animationBehavior = AccessibilityDisplay.current.reduceMotion ? .none : .utilityWindow
    }

    /// Reduce Motion can change while the panel exists, so it is read again every time the panel appears.
    override public func orderFront(_ sender: Any?) {
        animationBehavior = AccessibilityDisplay.current.reduceMotion ? .none : .utilityWindow
        super.orderFront(sender)
    }

    override public func orderFrontRegardless() {
        animationBehavior = AccessibilityDisplay.current.reduceMotion ? .none : .utilityWindow
        super.orderFrontRegardless()
    }

    override public var canBecomeKey: Bool {
        allowsKey
    }

    override public var canBecomeMain: Bool {
        false
    }
}
