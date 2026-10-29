import AppKit
import OrielCore

/// The sequence window's list: ⌫ and ⌦ delete the selected steps, as in Finder.
final class StepTableView: NSTableView {
    var onDelete: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isDelete = [KeyCode.delete, KeyCode.forwardDelete].contains(event.keyCode)
        if isDelete, flags.isDisjoint(with: [.option, .control, .shift]), !selectedRowIndexes.isEmpty {
            onDelete?()
            return
        }
        super.keyDown(with: event)
    }
}
