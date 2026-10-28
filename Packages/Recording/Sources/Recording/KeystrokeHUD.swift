import AppKit
import SharedUI

/// Shows keystrokes near the bottom of the recorded area while recording (PLAN §7.4), in a high-contrast HUD that
/// reads well in the video. A global key monitor only receives events when Oriel is trusted for Accessibility, so
/// the coordinator starts the HUD only then. Secure text fields never deliver their keys.
final class KeystrokeHUD {
    /// How long the HUD stays after the last key.
    static let visibleDuration: Duration = .milliseconds(1500)

    private let panel = FloatingPanel(level: .screenSaver)
    private let background = NSView()
    private let label = NSTextField(labelWithString: "")
    private let captureRect: CGRect
    private var monitor: Any?
    private var line = KeystrokeLine()
    private var hideTask: Task<Void, Never>?

    /// `captureRect` is the recorded area in Cocoa screen coordinates.
    init(captureRect: CGRect) {
        self.captureRect = captureRect
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        background.wantsLayer = true
        background.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.75).cgColor
        background.layer?.cornerRadius = 12
        label.font = .systemFont(ofSize: 26, weight: .semibold)
        label.textColor = .white
        label.lineBreakMode = .byTruncatingHead
        label.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 18),
            label.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -18),
            label.topAnchor.constraint(equalTo: background.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -10),
        ])
        panel.contentView = background
    }

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handle(event)
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        hideTask?.cancel()
        hideTask = nil
        line.reset()
        panel.orderOut(nil)
    }

    private func handle(_ event: NSEvent) {
        let press = KeystrokeFormatter.press(
            keyCode: event.keyCode,
            modifiers: KeystrokeFormatter.modifiers(from: event.modifierFlags),
            characters: event.characters,
            baseCharacters: event.charactersIgnoringModifiers
        )
        guard let press else { return }
        line.append(press)
        show(line.displayText)
    }

    private func show(_ text: String) {
        label.stringValue = text
        let size = background.fittingSize
        panel.setFrame(OverlayLayout.keystrokeFrame(size: size, captureRect: captureRect), display: true)
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: Self.visibleDuration)
            guard !Task.isCancelled else { return }
            self?.fadeOut()
        }
    }

    private func fadeOut() {
        line.reset()
        guard !AccessibilityDisplay.current.reduceMotion else {
            panel.orderOut(nil)
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            panel.animator().alphaValue = 0
        }
    }
}
