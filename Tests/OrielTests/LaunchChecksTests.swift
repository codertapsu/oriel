@testable import Oriel
import Testing

struct LaunchChecksTests {
    /// The installed app and a Debug build share the socket, the hotkeys and the event tap, so either one
    /// running makes the other hand over.
    @Test func theReleaseAndItsDebugBuildAreOneFamily() {
        let family = ["com.codertapsu.oriel", "com.codertapsu.oriel.debug"]
        #expect(LaunchChecks.family(of: "com.codertapsu.oriel") == family)
        #expect(LaunchChecks.family(of: "com.codertapsu.oriel.debug") == family)
    }

    /// Move to Applications launches the moved copy with its own process ID, and the moved copy waits for that
    /// process to quit before it starts (PLAN §15.6).
    @Test func theMovedCopyLearnsWhichProcessItReplaces() {
        let arguments = ["/Applications/Oriel.app/Contents/MacOS/Oriel"] + LaunchChecks.relaunchArguments(replacing: 4242)
        #expect(LaunchChecks.replacedProcessID(in: arguments) == 4242)
        #expect(LaunchChecks.replacedProcessID(in: ["Oriel"]) == nil)
        #expect(LaunchChecks.replacedProcessID(in: ["Oriel", "--replacing"]) == nil)
        #expect(LaunchChecks.replacedProcessID(in: ["Oriel", "--replacing", "soon"]) == nil)
    }

    /// Opened by the user, Oriel shows its window, so the launch is seen; started at login, or to open a file or a
    /// URL, it stays in the menu bar (PLAN §10.1).
    @Test func theWindowOpensWhenTheUserStartsOrielOnly() {
        #expect(LaunchChecks.opensWindowAtLaunch(launchIsDefault: true, launchedAtLogin: false))
        #expect(!LaunchChecks.opensWindowAtLaunch(launchIsDefault: true, launchedAtLogin: true))
        #expect(!LaunchChecks.opensWindowAtLaunch(launchIsDefault: false, launchedAtLogin: false))
    }
}
