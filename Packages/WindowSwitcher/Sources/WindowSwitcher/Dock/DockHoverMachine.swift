/// When the Dock preview shows and goes (PLAN §7.1.12), as a pure machine: the controller feeds it what happened and
/// carries out its effects with one-shot delays. Resting on the icon of an app with windows shows them after a short
/// delay, at once when a preview already shows; leaving the icon hides the preview after a grace period, so the pointer
/// can cross to the panel, and the panel keeps it while the pointer is in it. A click outside the panel, or another app
/// coming forward, hides it at once, and it stays away until the pointer rests on another icon.
nonisolated struct DockHoverMachine: Sendable, Equatable {
    enum Input: Sendable, Equatable {
        /// The icon under the pointer, when it is an app with windows to show; nil anywhere else.
        case hovered(DockItem?)
        case pointerEnteredPanel
        case pointerLeftPanel
        case showDelayElapsed(DockItem)
        case hideDelayElapsed
        /// A click outside the panel, a click on a tile, or another app came forward.
        case dismissed
        /// The app has no window left to show.
        case emptied
    }

    enum Effect: Sendable, Equatable {
        case show(DockItem)
        case hide
        case scheduleShow(DockItem, after: Duration)
        case scheduleHide(after: Duration)
        case cancelScheduledShow
        case cancelScheduledHide
    }

    static let showDelay: Duration = .milliseconds(250)
    static let hideDelay: Duration = .milliseconds(350)

    /// The icon whose windows the panel shows.
    private(set) var shown: DockItem?
    private(set) var hovered: DockItem?
    private(set) var isPointerInPanel = false
    /// The icon under the pointer when the preview was dismissed, which does not bring it back.
    private var dismissedItem: DockItem?

    mutating func handle(_ input: Input) -> [Effect] {
        switch input {
        case let .hovered(item):
            hover(item)
        case .pointerEnteredPanel:
            pointerEnteredPanel()
        case .pointerLeftPanel:
            pointerLeftPanel()
        case let .showDelayElapsed(item):
            showDelayElapsed(item)
        case .hideDelayElapsed:
            hideDelayElapsed()
        case .dismissed:
            dismiss()
        case .emptied:
            empty()
        }
    }

    private mutating func hover(_ item: DockItem?) -> [Effect] {
        hovered = item
        if let item, let dismissedItem, item.isSameIcon(as: dismissedItem) {
            return []
        }
        dismissedItem = nil
        guard let item else {
            return shown != nil && !isPointerInPanel ? [.cancelScheduledShow, .scheduleHide(after: Self.hideDelay)] : [.cancelScheduledShow]
        }
        if let shown {
            guard !shown.isSameIcon(as: item) else { return [.cancelScheduledHide] }
            self.shown = item
            return [.cancelScheduledShow, .cancelScheduledHide, .show(item)]
        }
        return [.cancelScheduledHide, .scheduleShow(item, after: Self.showDelay)]
    }

    private mutating func pointerEnteredPanel() -> [Effect] {
        isPointerInPanel = true
        return [.cancelScheduledHide]
    }

    private mutating func pointerLeftPanel() -> [Effect] {
        isPointerInPanel = false
        guard let shown else { return [] }
        if let hovered, hovered.isSameIcon(as: shown) {
            return []
        }
        return [.scheduleHide(after: Self.hideDelay)]
    }

    private mutating func showDelayElapsed(_ item: DockItem) -> [Effect] {
        guard shown == nil, let hovered, hovered.isSameIcon(as: item) else { return [] }
        shown = hovered
        return [.show(hovered)]
    }

    private mutating func hideDelayElapsed() -> [Effect] {
        guard let shown, !isPointerInPanel else { return [] }
        if let hovered, hovered.isSameIcon(as: shown) {
            return []
        }
        self.shown = nil
        return [.hide]
    }

    private mutating func dismiss() -> [Effect] {
        dismissedItem = hovered
        isPointerInPanel = false
        guard shown != nil else { return [.cancelScheduledShow] }
        shown = nil
        return [.cancelScheduledShow, .cancelScheduledHide, .hide]
    }

    private mutating func empty() -> [Effect] {
        isPointerInPanel = false
        guard shown != nil else { return [] }
        shown = nil
        return [.cancelScheduledHide, .hide]
    }
}
