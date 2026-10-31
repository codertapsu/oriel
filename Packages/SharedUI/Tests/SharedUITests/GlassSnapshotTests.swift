import AppKit
import OrielTestSupport
import SharedUI
import Testing

/// Reduce Transparency switches the switcher to opaque live (PLAN §10.2, checklist Phase 1): the glass turns into the
/// window background with a 1 px separator, in the light and the dark appearance, and back. The options are forced on
/// the view; the system's are untouched. Image-diff against `Tests/Fixtures/snapshots/` (PLAN §14.4).
@MainActor
struct GlassSnapshotTests {
    private let plain = AccessibilityDisplay(reduceTransparency: false, increaseContrast: false, reduceMotion: false)
    private let reduced = AccessibilityDisplay(reduceTransparency: true, increaseContrast: false, reduceMotion: false)
    private let contrast = AccessibilityDisplay(reduceTransparency: false, increaseContrast: true, reduceMotion: false)

    /// The switcher's background (`SwitcherPanelController`: corner radius 20) at a small panel's size.
    private func switcherBackground() -> GlassBackgroundView {
        let view = Material.make(cornerRadius: 20)
        view.frame = CGRect(x: 0, y: 0, width: 160, height: 100)
        view.appearance = NSAppearance(named: .aqua)
        return view
    }

    @Test(.snapshots("switcher-opaque-light"))
    func reduceTransparencyTurnsTheSwitcherOpaqueAndBack() throws {
        let view = switcherBackground()
        view.apply(reduced)
        #expect(!view.subviews.contains { $0 is NSGlassEffectView })
        Snapshot.expect(Snapshot.render(view), matches: "switcher-opaque-light")

        // Glass is composited by the window server, so only its structure can be checked off screen.
        view.apply(plain)
        #expect(view.layer?.backgroundColor == nil && view.layer?.borderWidth == 0)
        let glass = try #require(view.subviews.first { $0 is NSGlassEffectView })
        #expect(view.contentView.isDescendant(of: glass))

        view.apply(contrast)
        Snapshot.expect(Snapshot.render(view), matches: "switcher-opaque-light")
    }

    /// The fill follows Dark Mode while the panel is open: a layer keeps the color it was given.
    @Test(.snapshots("switcher-opaque-dark"))
    func theOpaqueFillFollowsTheAppearance() {
        let view = switcherBackground()
        view.apply(reduced)
        view.appearance = NSAppearance(named: .darkAqua)
        Snapshot.expect(Snapshot.render(view), matches: "switcher-opaque-dark")
    }

    /// macOS announces a change of the options; the view then draws for the system's.
    @Test func aChangeOfTheSystemsOptionsIsFollowed() {
        let view = switcherBackground()
        let forced = AccessibilityDisplay.current.allowsGlass ? reduced : plain
        view.apply(forced)
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
        #expect(view.display == AccessibilityDisplay.current)
    }
}
