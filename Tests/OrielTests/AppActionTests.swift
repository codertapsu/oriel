import Foundation
@testable import Oriel
import Testing

/// The status menu's actions: their `oriel://` URLs and global shortcuts (PLAN §7.2, §10.1).
@MainActor
struct AppActionTests {
    @Test(arguments: [
        ("oriel://capture/area", "captureArea"),
        ("oriel://capture/timer", "captureWithTimer"),
        ("oriel://capture/all", "captureAllDisplays"),
        ("oriel://record/area", "recordArea"),
        ("oriel://record/window", "recordWindow"),
        ("oriel://record/screen", "recordScreen"),
        ("oriel://record/stop", "stopRecording"),
        ("oriel://settings", "showSettings"),
    ])
    func urlsNameTheirActions(_ address: String, _ action: String) throws {
        #expect(try AppAction(url: #require(URL(string: address)))?.rawValue == action)
    }

    @Test func unknownURLsAreRefused() throws {
        #expect(try AppAction(url: #require(URL(string: "oriel://capture/everything"))) == nil)
        #expect(try AppAction(url: #require(URL(string: "https://capture/area"))) == nil)
    }

    /// The timer and window recording can have a shortcut, but none by default, so they never take a key the user
    /// already relies on.
    @Test func theTimerAndWindowRecordingTakeShortcutsButHaveNoneByDefault() {
        for action in [AppAction.captureWithTimer, .recordWindow] {
            #expect(AppAction.shortcutActions.contains(action))
            #expect(action.defaultShortcut == nil)
        }
    }
}
