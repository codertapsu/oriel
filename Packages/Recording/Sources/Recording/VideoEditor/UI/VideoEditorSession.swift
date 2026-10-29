import CoreGraphics
import Foundation
import Observation

/// The state of one video editor window (PLAN §17): the movie, the edit, what is selected and the undo history.
/// The window's views turn input into calls on this; tests drive it the same way.
///
/// Every change of the edit goes through `commit` (one undo step, optionally coalesced with the previous one),
/// `preview` (an intermediate state of a drag, no undo step) and `finish` (the drag's one undo step, from the
/// snapshot taken when it began). Undo restores whole snapshots, which are small values.
@Observable
final class VideoEditorSession {
    /// What is selected on the timeline.
    enum Selection: Equatable {
        case zoom(UUID)
        case chapter(UUID)
    }

    let info: MovieInfo
    private(set) var edit: VideoEdit
    /// The clicks saved with the recording, for Auto Zoom; nil when there are none.
    private(set) var clicks: ClickSidecar?
    var autoZoom: AutoZoomSettings
    var selection: Selection?
    /// Whether closing would lose edits: the edit changes the movie and differs from what was last exported.
    private(set) var hasUnexportedChanges = false
    /// The edit the last export wrote.
    @ObservationIgnored private var exportedEdit: VideoEdit?
    /// Bumped whenever the undo stack may have changed, so `canUndo` and `canRedo` can be observed.
    private(set) var undoRevision = 0

    @ObservationIgnored let undoManager: UndoManager
    /// Called after every change the views have to show.
    @ObservationIgnored var onChange: (() -> Void)?
    /// The last commit's coalescing key; a commit coalesces only with the same.
    @ObservationIgnored private var coalescingKey: String?

    init(info: MovieInfo, edit: VideoEdit = VideoEdit(), clicks: ClickSidecar? = nil, autoZoom: AutoZoomSettings = AutoZoomSettings()) {
        self.info = info
        self.edit = edit
        self.clicks = clicks?.clicks.isEmpty == false ? clicks : nil
        self.autoZoom = autoZoom
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        undoManager.levelsOfUndo = 200
        self.undoManager = undoManager
    }

    var url: URL {
        info.url
    }

    /// The movie's name without its extension.
    var title: String {
        url.deletingPathExtension().lastPathComponent
    }

    var duration: Double {
        info.duration
    }

    /// The part an export keeps.
    var range: ClosedRange<Double> {
        edit.range(duration: duration)
    }

    var canUndo: Bool {
        _ = undoRevision
        return undoManager.canUndo
    }

    var canRedo: Bool {
        _ = undoRevision
        return undoManager.canRedo
    }

    var selectedZoom: ZoomSegment? {
        guard case let .zoom(id) = selection else { return nil }
        return edit.zoomSegment(id)
    }

    var selectedChapter: ChapterMarker? {
        guard case let .chapter(id) = selection else { return nil }
        return edit.chapters.first { $0.id == id }
    }

    // MARK: Change primitives

    /// Applies `change` as one undo step named `actionName`. Consecutive changes with the same non-nil
    /// `coalescing` key (a slider drag) share one step.
    func commit(_ actionName: String, coalescing key: String? = nil, _ change: (inout VideoEdit) -> Void) {
        var updated = edit
        change(&updated)
        guard updated != edit else { return }
        let continues = key != nil && key == coalescingKey && undoManager.canUndo
        if !continues {
            registerUndo(restoring: edit, actionName: actionName)
        }
        coalescingKey = key
        edit = updated
        didEdit()
    }

    /// Shows an intermediate state of a drag, without an undo step.
    func preview(_ updated: VideoEdit) {
        guard updated != edit else { return }
        edit = updated
        notify()
    }

    /// Ends a drag that began at `snapshot`: one undo step back to it, if anything changed.
    func finish(from snapshot: VideoEdit, actionName: String) {
        coalescingKey = nil
        guard snapshot != edit else {
            notify()
            return
        }
        registerUndo(restoring: snapshot, actionName: actionName)
        didEdit()
    }

    func undo() {
        guard undoManager.canUndo else { return }
        coalescingKey = nil
        undoManager.undo()
    }

    func redo() {
        guard undoManager.canRedo else { return }
        coalescingKey = nil
        undoManager.redo()
    }

    /// An export has written the current edit.
    func markExported() {
        exportedEdit = edit
        hasUnexportedChanges = false
        notify()
    }

    /// Selection and view changes the views have to show, without an undo step.
    func notify() {
        onChange?()
    }

    private func registerUndo(restoring snapshot: VideoEdit, actionName: String) {
        undoManager.beginUndoGrouping()
        undoManager.registerUndo(withTarget: self) { session in
            MainActor.assumeIsolated {
                session.restore(snapshot, actionName: actionName)
            }
        }
        undoManager.setActionName(actionName)
        undoManager.endUndoGrouping()
        undoRevision &+= 1
    }

    /// Undo: puts `snapshot` back and registers the way forward again.
    private func restore(_ snapshot: VideoEdit, actionName: String) {
        let current = edit
        edit = snapshot
        registerUndo(restoring: current, actionName: actionName)
        if let selection, !isSelectable(selection) {
            self.selection = nil
        }
        didEdit()
    }

    private func didEdit() {
        hasUnexportedChanges = !edit.isEmpty && edit != exportedEdit
        undoRevision &+= 1
        notify()
    }

    private func isSelectable(_ selection: Selection) -> Bool {
        switch selection {
        case let .zoom(id): edit.zoomSegment(id) != nil
        case let .chapter(id): edit.chapters.contains { $0.id == id }
        }
    }

    // MARK: Trim

    func setTrimStart(at time: Double) {
        commit("Set In Point") { $0.setTrimStart(time, duration: duration) }
    }

    func setTrimEnd(at time: Double) {
        commit("Set Out Point") { $0.setTrimEnd(time, duration: duration) }
    }

    func clearTrimStart() {
        commit("Clear In Point") { $0.trimStart = nil }
    }

    func clearTrimEnd() {
        commit("Clear Out Point") { $0.trimEnd = nil }
    }

    // MARK: Chapters

    /// M: a chapter at `time`, selected. Returns nil when one is already there.
    @discardableResult
    func addChapter(at time: Double) -> UUID? {
        var added: UUID?
        commit("Add Chapter") { added = $0.addChapter(at: min(max(time, 0), duration)) }
        if let added {
            selection = .chapter(added)
            notify()
        }
        return added
    }

    func renameChapter(_ id: UUID, to title: String) {
        commit("Rename Chapter") { $0.renameChapter(id, to: title) }
    }

    // MARK: Zoom

    /// Z: a zoom at `time` looking at the middle of the frame, at Auto Zoom's level, selected.
    @discardableResult
    func addZoom(at time: Double) -> UUID? {
        var added: UUID?
        commit("Add Zoom") { added = $0.addZoom(at: time, duration: duration, scale: autoZoom.level, point: CGPoint(x: 0.5, y: 0.5)) }
        if let added {
            selection = .zoom(added)
            notify()
        }
        return added
    }

    /// Auto Zoom: replaces every zoom with segments made from the recording's clicks. Returns how many it made.
    @discardableResult
    func applyAutoZoom() -> Int {
        guard let clicks else { return 0 }
        let segments = AutoZoom.segments(for: clicks.clicks, duration: duration, settings: autoZoom)
        commit("Auto Zoom") { $0.replaceZoomSegments(segments) }
        selection = nil
        notify()
        return segments.count
    }

    func setZoomScale(_ id: UUID, scale: Double) {
        commit("Change Zoom", coalescing: "scale-\(id)") { $0.setZoomScale(id, scale: scale) }
    }

    func setZoomFocus(_ id: UUID, focusIndex: Int, point: CGPoint) {
        commit("Move Zoom Focus", coalescing: "focus-\(id)-\(focusIndex)") { $0.setZoomFocus(id, focusIndex: focusIndex, point: point) }
    }

    func removeAllZooms() {
        commit("Remove Zooms") { $0.replaceZoomSegments([]) }
        if case .zoom = selection {
            selection = nil
        }
        notify()
    }

    // MARK: Selection

    /// Delete: removes the selected zoom or chapter.
    func deleteSelection() {
        switch selection {
        case let .zoom(id):
            commit("Delete Zoom") { $0.removeZoom(id) }
        case let .chapter(id):
            commit("Delete Chapter") { $0.removeChapter(id) }
        case nil:
            return
        }
        selection = nil
        notify()
    }

    func select(_ selection: Selection?) {
        guard selection != self.selection else { return }
        self.selection = selection
        coalescingKey = nil
        notify()
    }
}
