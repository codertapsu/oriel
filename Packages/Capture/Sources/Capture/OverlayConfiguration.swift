/// How one freeze-frame overlay behaves.
nonisolated struct OverlayConfiguration: Sendable, Equatable {
    var mode: OverlayMode
    /// Space switches between area and window mode.
    var allowsModeSwitch = true
    /// Shown at the top of the screen, e.g. "Select the area to translate".
    var prompt: String?
    /// The toolbar next to an area selection.
    var tools: [OverlayTool] = OverlayTool.captureTools
    var showsMagnifier = true

    /// The line of help at the top of the screen in `mode` (Space can change the mode while the overlay is up).
    func hint(for mode: OverlayMode) -> String {
        if let prompt {
            return "\(prompt) · Esc to cancel"
        }
        switch mode {
        case .area:
            return allowsModeSwitch
                ? "Drag to select · Click a window to pick it · Space for window mode · Esc to cancel"
                : "Drag to select · Esc to cancel"
        case .window:
            return "Click a window to capture it · Space for area mode · Esc to cancel"
        case .screen:
            return "Click a display to capture it · Esc to cancel"
        }
    }
}
