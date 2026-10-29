import Foundation
@testable import Oriel
import OrielCore
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

    /// A tool's command names its URL by the same route, which the app's own table does not claim.
    @Test func toolRoutesComeFromTheURLsPath() throws {
        #expect(try AppAction.route(of: #require(URL(string: "oriel://clipboard"))) == "clipboard")
        #expect(try AppAction.route(of: #require(URL(string: "oriel://capture/instant"))) == "capture/instant")
        #expect(try AppAction.route(of: #require(URL(string: "https://clipboard"))) == nil)
        #expect(try AppAction(url: #require(URL(string: "oriel://clipboard"))) == nil)
    }

    /// Every default shortcut is different, so none of them fails to register because of another.
    @Test func defaultShortcutsDoNotCollide() {
        let defaults = AppAction.shortcutActions.compactMap(\.defaultShortcut)
        #expect(Set(defaults).count == defaults.count)
    }
}
