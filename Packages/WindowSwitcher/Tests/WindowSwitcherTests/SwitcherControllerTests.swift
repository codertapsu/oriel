import Hotkeys
import OrielCore
import Testing
@testable import WindowSwitcher

/// What the switcher controller leaves to the next main-actor turn, outside the event tap's callback (PLAN §7.1.4).
/// Nothing is shown: the session closes before the turn that would show its panel.
@MainActor
struct SwitcherControllerTests {
    @Test func theClickMonitorWaitsForTheNextTurnAndNeverOutlivesItsSession() async {
        let (store, source) = await Fixture.store()
        var configuration = SwitcherConfiguration()
        // The shortcut opens whatever app is frontmost.
        configuration.exceptions = []
        let controller = SwitcherController(
            store: store, source: source, thumbnails: ThumbnailService(capturer: FakeCapturer()), configuration: configuration
        )
        defer { controller.stop() }
        // ⌥⇥ as the event tap delivers it: the session opens inside the callback, which never waits on AppKit.
        _ = controller.handle(.flagsChanged(modifiers: .option))
        _ = controller.handle(.keyDown(keyCode: KeyCode.tab, modifiers: .option, isRepeat: false))
        #expect(controller.isOpen)
        #expect(!controller.hasOutsideClickMonitor)
        // Escape before the next turn: the session closes, and that turn installs nothing for it.
        _ = controller.handle(.keyDown(keyCode: KeyCode.escape, modifiers: .option, isRepeat: false))
        #expect(!controller.isOpen)
        for _ in 0 ..< 5 {
            await Task.yield()
        }
        #expect(!controller.hasOutsideClickMonitor)
    }
}
