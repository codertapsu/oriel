import CoreGraphics
import OrielCore

/// What a `WindowFilter` needs to know about the moment the switcher opened.
nonisolated struct FilterContext: Sendable, Equatable {
    /// The frontmost app (our panel never activates, so this is the user's app).
    var activePID: Int32?
    /// The display under the pointer, where the panel opens.
    var screenDisplayID: UInt32?
    /// Every active display with its global CoreGraphics bounds, for windows SkyLight did not place.
    var displays: [DisplayInfo]

    init(activePID: Int32? = nil, screenDisplayID: UInt32? = nil, displays: [DisplayInfo] = []) {
        self.activePID = activePID
        self.screenDisplayID = screenDisplayID
        self.displays = displays
    }

    /// The window's display: the one SkyLight reported, else the display showing most of its frame.
    func displayID(of window: WindowInfo) -> UInt32? {
        if let displayID = window.displayID {
            return displayID
        }
        return ScreenGeometry.bestDisplay(for: window.frame, among: displays.map(\.bounds)).map { displays[$0].id }
    }
}
