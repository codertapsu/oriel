import CoreGraphics
import Foundation
import OrielCore

extension EditorDocument {
    /// A new document for a base image, with the default background preset applied.
    nonisolated init(base: ImageRef, preset: BackgroundPreset) {
        self.init(base: base)
        if let style = preset.style {
            background = style
            canvasPadding = Padding(all: BackgroundPreset.defaultPadding(for: base.pointSize))
        }
    }

    /// A new document for a capture from the Quick Access Overlay, a pin or history.
    nonisolated init(capture: CaptureResult, preset: BackgroundPreset) {
        self.init(base: ImageRef(image: capture.image, scale: capture.scale), preset: preset)
    }
}
