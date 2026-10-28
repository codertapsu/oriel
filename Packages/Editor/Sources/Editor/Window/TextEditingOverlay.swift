import AppKit

/// The NSTextView laid over a label while it is edited (PLAN §7.5). It uses the renderer's font at the current
/// zoom, so the text does not jump when editing ends, and keeps its own undo history for the typing; the whole
/// edit becomes one document undo step when it ends.
final class TextEditingOverlay: NSObject, NSTextViewDelegate {
    private(set) var textView: NSTextView?
    private weak var canvas: EditorCanvasView?
    private var editingID: UUID?
    private var isResigning = false
    private let typingUndoManager = UndoManager()

    init(canvas: EditorCanvasView) {
        self.canvas = canvas
    }

    /// Shows, moves or removes the text view to match the session.
    func sync() {
        guard let canvas else { return }
        let session = canvas.session
        guard let id = session.editingTextID, case let .text(box) = session.document.item(withID: id) else {
            tearDown()
            return
        }
        if editingID != id {
            tearDown()
            begin(box, in: canvas)
        }
        layout(box, in: canvas)
    }

    // MARK: - NSTextViewDelegate

    func textDidChange(_: Notification) {
        guard let textView else { return }
        canvas?.session.updateEditingText(textView.string)
        if let canvas, let id = editingID, case let .text(box) = canvas.session.document.item(withID: id) {
            layout(box, in: canvas)
        }
    }

    /// The text view lost focus (a click elsewhere, another tool): editing is over.
    func textDidEndEditing(_: Notification) {
        isResigning = true
        canvas?.session.endEditingText()
        isResigning = false
    }

    func textView(_: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard selector == #selector(NSResponder.cancelOperation(_:)) else { return false }
        canvas?.session.endEditingText()
        return true
    }

    func undoManager(for _: NSTextView) -> UndoManager? {
        typingUndoManager
    }

    // MARK: - Private

    private func begin(_ box: TextBox, in canvas: EditorCanvasView) {
        let textView = NSTextView(frame: .zero)
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.focusRingType = .none
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.heightTracksTextView = false
        let unlimited = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.containerSize = unlimited
        textView.maxSize = unlimited
        textView.string = box.text
        textView.setAccessibilityLabel("Label text")
        textView.delegate = self
        canvas.addSubview(textView)
        self.textView = textView
        editingID = box.id
        canvas.window?.makeFirstResponder(textView)
        textView.setSelectedRange(NSRange(location: (box.text as NSString).length, length: 0))
    }

    private func layout(_ box: TextBox, in canvas: EditorCanvasView) {
        guard let textView else { return }
        let zoom = canvas.zoom
        let font = TextLayout.font(size: box.fontSize * zoom)
        if textView.font != font {
            textView.font = font
        }
        textView.textColor = box.color.nsColor
        textView.insertionPointColor = box.color.nsColor
        let size = TextLayout.size(of: textView.string, fontSize: box.fontSize)
        textView.minSize = NSSize(width: 4, height: size.height * zoom)
        // A little room after the last character keeps the caret visible.
        textView.frame = CGRect(
            origin: canvas.viewPoint(fromImage: box.origin),
            size: CGSize(width: size.width * zoom + 4, height: size.height * zoom)
        )
    }

    private func tearDown() {
        guard let textView else { return }
        self.textView = nil
        editingID = nil
        textView.delegate = nil
        if !isResigning, textView.window?.firstResponder === textView, let canvas {
            canvas.window?.makeFirstResponder(canvas)
        }
        // Removed on the next turn: this can run inside the text view's own key or focus handling.
        textView.isHidden = true
        Task { @MainActor in textView.removeFromSuperview() }
        typingUndoManager.removeAllActions()
    }
}
