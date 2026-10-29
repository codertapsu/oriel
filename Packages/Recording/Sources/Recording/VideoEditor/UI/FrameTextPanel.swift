import AppKit
import OrielCore
import os
import SharedUI

/// Copy Text from Frame's result (PLAN §17): the text read from one frame of a movie, in a small panel where part
/// of it can be selected and copied. The whole text is on the clipboard already.
final class FrameTextPanel: NSObject, NSWindowDelegate {
    /// Called when the panel has closed.
    var onClose: (() -> Void)?

    private let panel: NSPanel
    private let textView = NSTextView()
    private let text: String

    /// `time` is where the frame is in the movie named `movieName`.
    init(text: String, time: Double, movieName: String) {
        self.text = text
        panel = NSPanel(
            contentRect: CGRect(x: 0, y: 0, width: 440, height: 320),
            styleMask: [.titled, .closable, .resizable, .utilityWindow],
            backing: .buffered,
            defer: true
        )
        super.init()
        panel.title = "Text at \(Timecode.string(time))"
        panel.subtitle = movieName
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = false
        panel.contentMinSize = CGSize(width: 320, height: 200)
        panel.delegate = self
        build()
    }

    /// Copy Text from Frame: reads the text in the frame of `movie` at `time`, puts it on the clipboard and shows
    /// it beside `window`, or says that there is none. Returns the panel shown, which the caller keeps; nil when
    /// nothing was found, reading failed or the task was cancelled.
    static func copyText(of movie: URL, at time: Double, recognizer: any TextRecognizing, near window: NSWindow?) async -> FrameTextPanel? {
        let text: String
        do {
            text = try await FrameReader.text(of: movie, at: time, recognizer: recognizer)
        } catch {
            guard !Task.isCancelled else { return nil }
            Log.logger("video-editor").error("reading a frame's text failed: \(error.localizedDescription, privacy: .public)")
            Toast.show("The text could not be read", symbol: "exclamationmark.triangle", on: window?.screen)
            return nil
        }
        guard !Task.isCancelled else { return nil }
        guard !text.isEmpty else {
            Toast.show("No text found in this frame", symbol: "text.viewfinder", on: window?.screen)
            return nil
        }
        guard Pasteboard.copy(text) else { return nil }
        let panel = FrameTextPanel(text: text, time: time, movieName: movie.deletingPathExtension().lastPathComponent)
        panel.show(near: window)
        return panel
    }

    /// Shows the panel beside `window`, or in the middle of the screen.
    func show(near window: NSWindow?) {
        if let window {
            let frame = window.frame
            let size = panel.frame.size
            var origin = CGPoint(x: frame.maxX - size.width - 24, y: frame.maxY - size.height - 64)
            if let visible = window.screen?.visibleFrame {
                origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
                origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)
            }
            panel.setFrameOrigin(origin)
        } else {
            panel.center()
        }
        NSApplication.shared.activate()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(textView)
    }

    func close() {
        panel.close()
    }

    func windowWillClose(_: Notification) {
        let onClose = onClose
        Task { onClose?() }
    }

    private func build() {
        let note = NSTextField(wrappingLabelWithString: "Copied to the clipboard. Select part of the text to copy just that.")
        note.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        note.textColor = .secondaryLabelColor

        textView.string = text
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.textColor = .labelColor
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.setAccessibilityLabel("Text in the frame")
        let scroll = NSScrollView()
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.autohidesScrollers = true

        let copy = NSButton(title: "Copy All", target: self, action: #selector(copyAll(_:)))
        let done = NSButton(title: "Done", target: self, action: #selector(done(_:)))
        done.keyEquivalent = "\r"
        let buttons = NSStackView(views: [NSView(), copy, done])
        buttons.spacing = 8

        let stack = NSStackView(views: [note, scroll, buttons])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 14, bottom: 14, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = NSView()
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
            buttons.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
            note.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
        ])
        panel.contentView = content
    }

    @objc private func copyAll(_: Any?) {
        if Pasteboard.copy(text) {
            Toast.show("Copied the text", symbol: "doc.on.doc", on: panel.screen)
        }
    }

    @objc private func done(_: Any?) {
        panel.close()
    }
}
