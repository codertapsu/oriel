import AppKit
import OrielCore
import SharedUI

/// The Quick Access Overlay (PLAN §7.2, item 6): one small non-activating card per capture, stacked in a corner of
/// the screen with the newest nearest the corner. A card goes away after the configured number of seconds unless
/// the pointer is on it; cards that no longer fit on the screen go first.
final class QuickAccessController {
    private struct Card {
        let result: CaptureResult
        let panel: FloatingPanel
        var dismissal: Task<Void, Never>?
    }

    /// Runs an action for a card's capture (the coordinator copies, saves, pins or hands it to the app).
    var perform: ((QuickAccessAction, CaptureResult) -> Void)?
    /// Called whenever cards appear or go, because Oriel's own windows are left out of every capture.
    var windowsChanged: (() -> Void)?
    private let settings: SettingsStore
    private let makePromise: (CaptureResult) -> PromisedImageFile
    private var cards: [Card] = []
    private var screen: NSScreen?
    private var keptPromises: [ObjectIdentifier: PromisedImageFile] = [:]

    init(settings: SettingsStore, makePromise: @escaping (CaptureResult) -> PromisedImageFile) {
        self.settings = settings
        self.makePromise = makePromise
    }

    var isEmpty: Bool {
        cards.isEmpty
    }

    func present(_ result: CaptureResult, actions: [QuickAccessAction]) {
        let id = result.id
        dismiss(id, animated: false)
        let view = QuickAccessCardView(result: result, actions: actions) { [weak self] action in
            self?.handle(action, for: id)
        }
        view.thumbnail.makePromise = { [makePromise] in makePromise(result) }
        view.thumbnail.onDragEnded = { [weak self] promise, accepted in
            self?.dragEnded(promise, accepted: accepted, id: id)
        }
        view.thumbnail.onDoubleClick = { [weak self] in
            if actions.contains(.annotate) {
                self?.handle(.annotate, for: id)
            }
        }
        view.onHover = { [weak self] hovering in
            self?.hoverChanged(hovering, id: id)
        }
        let panel = FloatingPanel(contentRect: CGRect(origin: .zero, size: QuickAccessCardView.size), level: .statusBar)
        panel.animationBehavior = .none
        panel.contentView = view
        panel.setAccessibilityLabel("Quick Access")

        let rect = result.rect
        screen = rect.isEmpty ? ScreenLocator.screenUnderMouse : ScreenLocator.screen(containing: rect) ?? ScreenLocator.screenUnderMouse
        cards.insert(Card(result: result, panel: panel), at: 0)
        trimToCapacity()
        layOut(appearing: panel)
        panel.orderFrontRegardless()
        scheduleDismissal(for: id)
        windowsChanged?()
    }

    func dismiss(_ id: UUID, animated: Bool = true) {
        guard let index = cards.firstIndex(where: { $0.result.id == id }) else { return }
        let card = cards.remove(at: index)
        card.dismissal?.cancel()
        let panel = card.panel
        if animated, !AccessibilityDisplay.current.reduceMotion {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                panel.animator().alphaValue = 0
            }
            Task {
                try? await Task.sleep(for: .milliseconds(200))
                panel.orderOut(nil)
            }
        } else {
            panel.orderOut(nil)
        }
        layOut(appearing: nil)
        windowsChanged?()
    }

    func dismissAll() {
        for card in cards {
            dismiss(card.result.id, animated: false)
        }
    }

    /// Lets the mouse through every card while a scrolling capture runs, so scroll events posted where a card covers
    /// the region reach the app underneath.
    func setPassingThrough(_ passing: Bool) {
        for card in cards {
            card.panel.ignoresMouseEvents = passing
        }
    }

    private func handle(_ action: QuickAccessAction, for id: UUID) {
        guard let card = cards.first(where: { $0.result.id == id }) else { return }
        if action != .close {
            perform?(action, card.result)
        }
        if action.dismissesCard {
            dismiss(id)
        }
    }

    /// The drop target writes the file after the drag has ended, and a file promise provider keeps its delegate
    /// weakly, so the promise is kept for a while after the card has gone.
    private func dragEnded(_ promise: PromisedImageFile, accepted: Bool, id: UUID) {
        guard accepted else { return }
        let key = ObjectIdentifier(promise)
        keptPromises[key] = promise
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(120))
            self?.keptPromises[key] = nil
        }
        dismiss(id)
    }

    private func hoverChanged(_ hovering: Bool, id: UUID) {
        guard let index = cards.firstIndex(where: { $0.result.id == id }) else { return }
        if hovering {
            cards[index].dismissal?.cancel()
            cards[index].dismissal = nil
        } else {
            scheduleDismissal(for: id)
        }
    }

    /// A one-shot delay per card; hovering cancels it and leaving starts it again.
    private func scheduleDismissal(for id: UUID) {
        let seconds = settings[CaptureSettings.quickAccessSeconds]
        guard seconds > 0, let index = cards.firstIndex(where: { $0.result.id == id }) else { return }
        cards[index].dismissal?.cancel()
        cards[index].dismissal = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            self?.dismiss(id)
        }
    }

    private func trimToCapacity() {
        guard let frame = (screen ?? NSScreen.main)?.visibleFrame else { return }
        let capacity = QuickAccessLayout.capacity(cardHeight: QuickAccessCardView.size.height, in: frame, margin: 16, spacing: 10)
        while cards.count > capacity, let oldest = cards.last {
            dismiss(oldest.result.id, animated: false)
        }
    }

    /// Moves every card to its slot; a new card slides in from the screen's edge.
    private func layOut(appearing newPanel: FloatingPanel?) {
        guard let screen = screen ?? NSScreen.main else { return }
        let corner = settings[CaptureSettings.quickAccessCorner]
        let frames = QuickAccessLayout.frames(
            count: cards.count,
            cardSize: QuickAccessCardView.size,
            in: screen.visibleFrame,
            corner: corner
        )
        let animates = !AccessibilityDisplay.current.reduceMotion
        for (card, frame) in zip(cards, frames) where card.panel === newPanel {
            card.panel.setFrame(frame.offsetBy(dx: corner.isRight ? 40 : -40, dy: 0), display: false)
            card.panel.alphaValue = animates ? 0 : 1
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = animates ? 0.22 : 0
            for (card, frame) in zip(cards, frames) {
                card.panel.animator().setFrame(frame, display: true)
                card.panel.animator().alphaValue = 1
            }
        }
    }
}
