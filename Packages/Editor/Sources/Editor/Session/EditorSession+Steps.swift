import CoreGraphics
import Foundation

/// The numbered-steps tool: the style of the next marker (and of the selected ones), and where the numbering goes
/// on. Markers number themselves; deleting one closes the gap in its sequence (`EditorDocument.remove`).
extension EditorSession {
    /// The selected step markers.
    var selectedSteps: [Counter] {
        document.items.compactMap { item in
            guard selection.contains(item.id), case let .counter(counter) = item else { return nil }
            return counter
        }
    }

    /// Whether the step options apply: the step tool is on, or markers are selected.
    var showsStepOptions: Bool {
        tool == .counter || !selectedSteps.isEmpty
    }

    /// The label the next marker will show, in the current label style.
    var nextStepLabel: String {
        stepStyle.label.text(for: nextStepPlacement.number)
    }

    func setStepShape(_ shape: StepShape) {
        stepStyle.shape = shape
        restyleSelectedSteps { $0.styledStep(shape: shape, label: nil, pointer: nil, in: document.visibleImageRect) }
    }

    func setStepLabel(_ label: StepLabel) {
        stepStyle.label = label
        restyleSelectedSteps { $0.styledStep(shape: nil, label: label, pointer: nil, in: document.visibleImageRect) }
    }

    /// Turns the pointer on or off for new markers and the selected ones; a selected marker that gets one points
    /// towards the middle of the image, and its tip can then be dragged.
    func setStepPointer(_ enabled: Bool) {
        stepStyle.pointer = enabled
        restyleSelectedSteps { $0.styledStep(shape: nil, label: nil, pointer: enabled, in: document.visibleImageRect) }
    }

    /// The next marker starts a new sequence at `number` (1 unless the user picked another), so a second set of
    /// steps can count again from 1, or a screenshot can go on from the steps of the one before.
    func restartStepNumbering(at number: Int = 1) {
        pendingStepStart = max(1, number)
        notify()
    }

    /// The next marker goes on from the newest sequence again.
    func continueStepNumbering() {
        pendingStepStart = nil
        notify()
    }

    private func restyleSelectedSteps(_ change: (AnnotationItem) -> AnnotationItem) {
        let ids = selection.filter { id in
            if case .counter = document.item(withID: id) {
                return true
            }
            return false
        }
        guard !ids.isEmpty else {
            notify()
            return
        }
        commit("Step Style") { document in
            for id in ids {
                if let item = document.item(withID: id) {
                    document.replace(change(item))
                }
            }
        }
    }
}
