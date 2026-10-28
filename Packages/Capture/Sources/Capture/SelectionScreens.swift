import ScreenCaptureKit

/// Everything gathered at the start of an interactive capture (PLAN §7.2, item 2): the displays, their frozen
/// pictures unless the screen stays live, the windows window mode can pick, and the shareable content they came from
/// (for capturing a picked window by itself, or a display once a live selection is made).
struct SelectionScreens {
    /// The displays the overlay covers: every display while live; when frozen, those whose picture was taken.
    let displays: [DisplayFrame]
    /// One picture per display when frozen; empty while the screen stays live.
    let frozen: [FrozenDisplay]
    let windows: [WindowTarget]
    let content: SCShareableContent

    var isLive: Bool {
        frozen.isEmpty
    }

    /// What each display's overlay shows.
    var backdrops: [SelectionBackdrop] {
        Self.backdrops(displays: displays, frozen: frozen)
    }

    func frozenDisplay(_ id: CGDirectDisplayID) -> FrozenDisplay? {
        frozen.first { $0.id == id }
    }

    /// Each display with its frozen picture, or none while live.
    nonisolated static func backdrops(displays: [DisplayFrame], frozen: [FrozenDisplay]) -> [SelectionBackdrop] {
        displays.map { display in
            SelectionBackdrop(display: display, image: frozen.first { $0.id == display.id }?.image)
        }
    }
}
