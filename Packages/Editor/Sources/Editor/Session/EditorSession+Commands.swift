import CoreGraphics
import Foundation

/// Keyboard and toolbar commands: selection, background, crop and output.
extension EditorSession {
    // MARK: - Selection

    /// Delete / Forward Delete. In the crop tool it resets the pending crop to the whole image.
    func deleteSelection() {
        if tool == .crop {
            cropDraft = document.base.bounds
            notify()
            return
        }
        guard !selection.isEmpty else { return }
        let ids = selection
        selection = []
        commit("Delete") { $0.remove(ids) }
    }

    /// Arrow keys: 1 point, or 10 with Shift. Repeated nudges are one undo step.
    func nudgeSelection(dx: CGFloat, dy: CGFloat) {
        guard tool != .crop, !selection.isEmpty else { return }
        let ids = selection
        commit("Move", coalescing: "nudge") { document in
            for id in ids {
                if let item = document.item(withID: id) {
                    document.replace(item.offsetBy(dx: dx, dy: dy))
                }
            }
        }
    }

    func selectAll() {
        guard tool != .crop else { return }
        endEditingText()
        selection = Set(document.items.map(\.id))
        notify()
    }

    /// Escape: cancels a drag, ends text editing, leaves the crop tool without cropping, or deselects.
    func cancel() {
        if gesture != nil {
            cancelGesture()
        } else if editingTextID != nil {
            endEditingText()
        } else if tool == .crop {
            cropDraft = nil
            selectTool(.select)
        } else if !selection.isEmpty {
            selection = []
            notify()
        }
    }

    /// Return: applies the crop, or edits the selected label.
    func confirm() {
        if tool == .crop {
            selectTool(.select)
        } else if selection.count == 1, let id = selection.first, case .text = document.item(withID: id) {
            beginEditingText(id)
        }
    }

    // MARK: - Background and padding

    /// Applies a preset's fill; keeps the current shadow and corner radius, adds padding if there is none.
    /// `.none` removes the background and the padding.
    func applyBackground(_ preset: BackgroundPreset) {
        commit("Background") { document in
            guard var style = preset.style else {
                document.background = nil
                document.canvasPadding = nil
                return
            }
            if let current = document.background {
                style.shadow = current.shadow
                style.cornerRadius = current.cornerRadius
            }
            document.background = style
            if document.canvasPadding == nil {
                document.canvasPadding = Padding(all: BackgroundPreset.defaultPadding(for: document.visibleImageRect.size))
            }
        }
    }

    func setPadding(_ value: CGFloat) {
        commit("Padding", coalescing: "padding") { $0.canvasPadding = Padding(all: max(0, value.rounded())) }
    }

    func setCornerRadius(_ value: CGFloat) {
        guard document.background != nil else { return }
        commit("Corner Radius", coalescing: "cornerRadius") { $0.background?.cornerRadius = max(0, value.rounded()) }
    }

    func setShadow(_ enabled: Bool) {
        guard document.background != nil else { return }
        commit("Shadow") { $0.background?.shadow = enabled }
    }

    // MARK: - Crop

    /// Makes the pending crop the document's crop (one undo step), snapped to whole base-image pixels. A crop
    /// covering the whole image removes the crop.
    func applyCropDraft() {
        guard let draft = cropDraft else { return }
        let base = document.base
        let rect = Geometry.pixelAligned(clampedCrop(draft), scale: base.scale)
        let minimum = 1 / base.scale
        guard rect.width >= minimum, rect.height >= minimum else { return }
        let tolerance = 0.5 / base.scale
        let isWholeImage = abs(rect.minX - base.bounds.minX) < tolerance && abs(rect.minY - base.bounds.minY) < tolerance
            && abs(rect.width - base.bounds.width) < tolerance && abs(rect.height - base.bounds.height) < tolerance
        commit("Crop") { $0.crop = isWholeImage ? nil : rect }
        cropDraft = document.visibleImageRect
        notify()
    }

    // MARK: - Output

    /// Finishes what is in progress (text being typed, a pending crop) so output shows what the user sees.
    func commitPendingEdits() {
        cancelGesture()
        endEditingText()
        if tool == .crop {
            applyCropDraft()
        }
    }

    /// The flattened image at the base image's resolution, for the clipboard, upload and drag-out.
    func flattenedImage() -> CGImage? {
        commitPendingEdits()
        return EditorExporter.image(document, effects: effects)
    }

    /// The document encoded as `format`.
    func encodedData(for format: EditorExportFormat) -> Data? {
        commitPendingEdits()
        return EditorExporter.data(for: document, format: format, effects: effects)
    }
}
