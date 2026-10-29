import AppKit
import SharedUI

/// Capture Text's editing panel (⇧ while selecting, or Settings → Capture → Open captured text for editing): the text
/// in a text view with spelling underlined, to correct or trim it before copying. Copy (⌘Return) puts it on the
/// clipboard, and so in Clipboard History, and closes the panel; Close (Esc) closes it without copying. One panel,
/// reused, so it keeps the size and place the user gave it.
final class CapturedTextPanel: NSObject, NSTextViewDelegate {
    private static let autosaveName = "OrielCapturedText"

    /// Called with the text when Copy is pressed.
    var onCopy: ((String) -> Void)?
    lazy var panel = makePanel()
    private let textView = NSTextView()
    private let summary = NSTextField(labelWithString: "")

    var isVisible: Bool {
        panel.isVisible
    }

    /// The text being edited.
    var text: String {
        textView.string
    }

    /// Opens the panel with `text`, in front and ready for typing.
    func show(_ text: String) {
        load(text)
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(textView)
        textView.scrollToBeginningOfDocument(nil)
    }

    /// Puts `text` in the panel, with the cursor at its start and nothing to undo.
    func load(_ text: String) {
        _ = panel
        textView.string = text
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.undoManager?.removeAllActions()
        updateSummary()
    }

    func close() {
        panel.orderOut(nil)
    }

    func textDidChange(_: Notification) {
        updateSummary()
    }

    @objc private func copyPressed() {
        let text = textView.string
        close()
        onCopy?(text)
    }

    @objc private func closePressed() {
        close()
    }

    private func updateSummary() {
        let text = textView.string
        let lines = text.split(whereSeparator: \.isNewline).count
        let characters = text.count
        let lineCount = lines == 1 ? "1 line" : "\(lines) lines"
        summary.stringValue = "\(lineCount) · \(characters == 1 ? "1 character" : "\(characters) characters")"
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: CGRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: true
        )
        panel.title = "Captured Text"
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
        panel.contentMinSize = CGSize(width: 320, height: 200)
        panel.contentView = makeContent()
        if !panel.setFrameUsingName(Self.autosaveName) {
            panel.center()
        }
        panel.setFrameAutosaveName(Self.autosaveName)
        return panel
    }

    private func makeContent() -> NSView {
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = .systemFont(ofSize: 13)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.isContinuousSpellCheckingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.minSize = .zero
        textView.maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        textView.delegate = self
        textView.setAccessibilityLabel("Captured text")

        let scroll = NSScrollView()
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = true
        scroll.translatesAutoresizingMaskIntoConstraints = false

        summary.font = .systemFont(ofSize: 11)
        summary.textColor = .secondaryLabelColor
        summary.lineBreakMode = .byTruncatingTail
        summary.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        // It takes the slack, so the buttons sit at the right edge.
        summary.setContentHuggingPriority(NSLayoutConstraint.Priority(1), for: .horizontal)

        let close = NSButton(title: "Close", target: self, action: #selector(closePressed))
        close.keyEquivalent = "\u{1b}"
        let copy = NSButton(title: "Copy", target: self, action: #selector(copyPressed))
        copy.keyEquivalent = "\r"
        copy.keyEquivalentModifierMask = .command
        copy.bezelColor = .controlAccentColor
        copy.toolTip = "Copy the text and close (⌘Return)"
        let bar = NSStackView(views: [summary, close, copy])
        bar.distribution = .fill
        bar.spacing = 8
        bar.edgeInsets = NSEdgeInsets(top: 10, left: 14, bottom: 12, right: 14)
        bar.translatesAutoresizingMaskIntoConstraints = false

        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        content.addSubview(scroll)
        content.addSubview(separator)
        content.addSubview(bar)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: content.topAnchor),
            separator.topAnchor.constraint(equalTo: scroll.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            bar.topAnchor.constraint(equalTo: separator.bottomAnchor),
            bar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            bar.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        return content
    }
}
