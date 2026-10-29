import CoreGraphics
import Foundation
import Observation

/// The state of one editor window: the document, the current tool and style, the selection and the undo
/// history. The canvas view turns mouse and keyboard input into calls on this; tests drive it the same way.
///
/// Every document change goes through three primitives: `commit` (one undo step, optionally coalesced with the
/// previous one), `preview` (an intermediate state of a gesture, no undo step) and `finish` (the gesture's one
/// undo step, from the snapshot taken when it began). Undo restores whole document snapshots.
@Observable
final class EditorSession {
    private(set) var document: EditorDocument
    private(set) var tool: EditorTool = .select
    private(set) var color: RGBAColor
    private(set) var strokeWidth: CGFloat
    /// The label being edited in the text overlay.
    private(set) var editingTextID: UUID?
    /// Whether there are edits that were neither saved nor copied, exported, dragged or uploaded.
    private(set) var hasUnsavedChanges = false
    /// Bumped whenever the undo stack may have changed, so `canUndo` and `canRedo` can be observed.
    private(set) var undoRevision = 0
    /// The exported image's size in pixels. Set only when it changes, so observers do not update on every drag.
    private(set) var outputPixelSize: CGSize = .zero
    /// What the step tool puts down next.
    var stepStyle = StepStyle()
    /// Set by Restart Numbering (or a chosen start number): the next step begins a new sequence at this number.
    var pendingStepStart: Int?

    /// Selected item ids. Transient view state, not part of the document or of undo.
    var selection: Set<UUID> = []
    /// The crop tool's pending rect (image space), applied when the tool is left or Return is pressed.
    var cropDraft: CGRect?
    /// The rubber band being dragged with the select tool (image space).
    var marquee: CGRect?
    /// View points per canvas point, and whether the zoom follows the window size.
    var zoom: CGFloat = 1
    var zoomsToFit = true
    var title: String
    /// The `.oriel` bundle this document was opened from or saved to; ⌘S writes there.
    var fileURL: URL?
    /// The file the document came from (an image or a bundle), where save panels start.
    var sourceURL: URL?
    var uploadAvailable = false
    let defaults: EditorDefaults

    @ObservationIgnored let undoManager: UndoManager
    @ObservationIgnored let effects = EffectCache()
    /// Called after every change the canvas has to redraw for.
    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored var gesture: ActiveGesture?
    @ObservationIgnored var gestureSnapshot: EditorDocument?
    @ObservationIgnored var gestureTolerance: CGFloat = 4
    @ObservationIgnored private var textSnapshot: EditorDocument?
    /// The last commit's coalescing key and the selection it applied to; a commit coalesces only with the same.
    @ObservationIgnored private var coalescing: (key: String, selection: Set<UUID>)?

    init(document: EditorDocument, title: String = "Screenshot", fileURL: URL? = nil, defaults: EditorDefaults = EditorDefaults()) {
        self.document = document
        self.title = title
        self.fileURL = fileURL
        self.defaults = defaults
        color = defaults.color
        strokeWidth = defaults.strokeWidth
        let undoManager = UndoManager()
        // One explicit group per change, so undo steps are the same in tests and behind a window's run loop.
        undoManager.groupsByEvent = false
        undoManager.levelsOfUndo = 200
        self.undoManager = undoManager
        sourceURL = fileURL
        updateOutputPixelSize()
    }

    /// The canvas as shown now (the crop tool shows the whole image).
    var layout: CanvasLayout {
        CanvasLayout(document: document, showsUncroppedImage: tool == .crop)
    }

    var renderOptions: RenderOptions {
        RenderOptions(showsUncroppedImage: tool == .crop, hiddenItems: editingTextID.map { [$0] } ?? [])
    }

    var canUndo: Bool {
        _ = undoRevision
        return undoManager.canUndo
    }

    var canRedo: Bool {
        _ = undoRevision
        return undoManager.canRedo
    }

    // MARK: - Change primitives

    /// Applies `change` as one undo step named `actionName`. Consecutive changes with the same non-nil
    /// `coalescing` key on the same selection (a slider drag, repeated nudges) share one step.
    func commit(_ actionName: String, coalescing key: String? = nil, _ change: (inout EditorDocument) -> Void) {
        var updated = document
        change(&updated)
        guard updated != document else { return }
        let continues = key != nil && coalescing?.key == key && coalescing?.selection == selection && undoManager.canUndo
        if !continues {
            registerUndo(restoring: document, actionName: actionName)
        }
        coalescing = key.map { ($0, selection) }
        document = updated
        documentDidChange()
    }

    /// Shows an intermediate state (a drag in progress, text being typed) without an undo step.
    func preview(_ updated: EditorDocument) {
        guard updated != document else { return }
        document = updated
        notify()
    }

    /// Ends a gesture or text edit that began at `snapshot`: one undo step back to it, if anything changed.
    func finish(from snapshot: EditorDocument, actionName: String) {
        coalescing = nil
        guard snapshot != document else {
            notify()
            return
        }
        registerUndo(restoring: snapshot, actionName: actionName)
        documentDidChange()
    }

    func undo() {
        settleBeforeHistoryChange()
        guard undoManager.canUndo else { return }
        undoManager.undo()
        undoRevision &+= 1
    }

    func redo() {
        settleBeforeHistoryChange()
        guard undoManager.canRedo else { return }
        undoManager.redo()
        undoRevision &+= 1
    }

    /// The user got the image out (saved, copied, exported, dragged or uploaded it).
    func markDelivered() {
        hasUnsavedChanges = false
    }

    func notify() {
        updateOutputPixelSize()
        onChange?()
    }

    // MARK: - Tool and style

    func selectTool(_ newTool: EditorTool) {
        guard newTool != tool else { return }
        cancelGesture()
        endEditingText()
        if tool == .crop {
            applyCropDraft()
        }
        tool = newTool
        marquee = nil
        if newTool == .crop {
            selection = []
            cropDraft = document.visibleImageRect
        } else {
            cropDraft = nil
        }
        notify()
    }

    /// Sets the colour for new items and recolours the selection (one undo step while the colour panel drags).
    func setColor(_ newColor: RGBAColor) {
        color = newColor
        applyStyle(color: newColor, width: nil, actionName: "Colour", coalescing: "colour")
    }

    /// Sets the width for new items and applies it to the selection (see `ToolStyle` for what it means per kind).
    func setStrokeWidth(_ width: CGFloat) {
        strokeWidth = ToolStyle.clampedWidth(width)
        applyStyle(color: nil, width: strokeWidth, actionName: "Width", coalescing: "width")
    }

    /// Shows `item`'s colour and width in the toolbar (and a step marker's shape, label and pointer in the step
    /// style) without changing anything.
    func adoptStyle(of item: AnnotationItem) {
        if let itemColor = item.color {
            color = itemColor
        }
        if let width = ToolStyle.width(of: item) {
            strokeWidth = width
        }
        if case let .counter(counter) = item {
            stepStyle = StepStyle(shape: counter.shape, label: counter.label, pointer: counter.pointer != nil)
        }
    }

    // MARK: - Text editing

    /// Starts editing a label in the text overlay. `snapshot` is the document to undo back to (before the label
    /// was created, when it is new).
    func beginEditingText(_ id: UUID, snapshot: EditorDocument? = nil) {
        guard case .text = document.item(withID: id) else { return }
        if editingTextID != nil {
            endEditingText()
        }
        textSnapshot = snapshot ?? document
        editingTextID = id
        selection = [id]
        notify()
    }

    func updateEditingText(_ text: String) {
        guard let id = editingTextID, case var .text(box) = document.item(withID: id), box.text != text else { return }
        box.text = text
        var updated = document
        updated.replace(.text(box))
        preview(updated)
    }

    /// Ends editing: an empty label is removed, anything else becomes one undo step.
    func endEditingText() {
        guard let id = editingTextID else { return }
        editingTextID = nil
        let snapshot = textSnapshot ?? document
        textSnapshot = nil
        if case let .text(box) = document.item(withID: id), box.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            var updated = document
            updated.remove([id])
            selection.remove(id)
            preview(updated)
        }
        finish(from: snapshot, actionName: "Text")
    }

    // MARK: - Private

    private func applyStyle(color: RGBAColor?, width: CGFloat?, actionName: String, coalescing key: String) {
        if let editingTextID, let item = document.item(withID: editingTextID) {
            // Part of the text edit, which becomes one undo step when it ends.
            var updated = document
            updated.replace(item.styled(color: color, width: width))
            preview(updated)
            return
        }
        guard !selection.isEmpty else {
            notify()
            return
        }
        let ids = selection
        commit(actionName, coalescing: key) { document in
            for id in ids {
                if let item = document.item(withID: id) {
                    document.replace(item.styled(color: color, width: width))
                }
            }
        }
    }

    /// Undo and redo act on whole steps: a drag in progress is cancelled and a text edit is committed first.
    private func settleBeforeHistoryChange() {
        cancelGesture()
        endEditingText()
        coalescing = nil
    }

    private func registerUndo(restoring snapshot: EditorDocument, actionName: String) {
        let opensGroup = !undoManager.isUndoing && !undoManager.isRedoing
        if opensGroup {
            undoManager.beginUndoGrouping()
        }
        undoManager.registerUndo(withTarget: self) { session in
            session.restore(snapshot, actionName: actionName)
        }
        undoManager.setActionName(actionName)
        if opensGroup {
            undoManager.endUndoGrouping()
        }
        undoRevision &+= 1
    }

    /// Runs inside undo or redo: registers the way back, then puts `snapshot` in place.
    private func restore(_ snapshot: EditorDocument, actionName: String) {
        gesture = nil
        gestureSnapshot = nil
        registerUndo(restoring: document, actionName: actionName)
        document = snapshot
        selection = selection.filter { snapshot.item(withID: $0) != nil }
        if tool == .crop {
            cropDraft = snapshot.visibleImageRect
        }
        coalescing = nil
        documentDidChange()
    }

    private func documentDidChange() {
        hasUnsavedChanges = true
        notify()
    }

    private func updateOutputPixelSize() {
        let pixels = CanvasLayout(document: document).exportPixelSize(baseScale: document.base.scale)
        let size = CGSize(width: pixels.width, height: pixels.height)
        if size != outputPixelSize {
            outputPixelSize = size
        }
    }
}
