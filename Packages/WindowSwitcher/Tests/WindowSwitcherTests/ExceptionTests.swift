import Foundation
import OrielCore
import Testing
@testable import WindowSwitcher

/// Application exceptions by bundle ID (PLAN §13.2: "Exceptions exclude apps by bundle ID").
struct ExceptionTests {
    @Test(arguments: [
        ("com.vmware.fusion", "com.vmware.fusion", true),
        ("com.vmware.fusion", "COM.VMware.Fusion", true),
        ("com.vmware.fusion", "com.vmware.fusionhelper", false),
        ("com.parallels.*", "com.parallels.desktop.console", true),
        ("com.parallels.*", "com.parallels.winapp.notepad", true),
        ("com.parallels.*", "com.paralle", false),
        ("", "com.example", false),
    ])
    func rulesMatchExactlyOrByPrefix(_ rule: String, _ bundleID: String, _ matches: Bool) {
        #expect(AppException(bundleID: rule).matches(bundleID) == matches)
    }

    @Test func nothingMatchesAnAppWithoutABundleID() {
        #expect(!AppException(bundleID: "com.parallels.*").matches(nil))
    }

    @Test func theDefaultsCoverVirtualMachinesAndRemoteDesktops() {
        let defaults = AppException.defaults
        for bundleID in [
            "com.vmware.fusion", "com.parallels.desktop.console", "org.virtualbox.app.VirtualBoxVM", "com.utmapp.UTM",
            "com.microsoft.rdc.macos", "com.citrix.receiver.icaviewer.mac", "com.apple.ScreenSharing",
        ] {
            let rule = defaults.rule(for: bundleID)
            #expect(rule?.ignoresShortcuts == true, "\(bundleID)")
            // Their windows stay switchable.
            #expect(rule?.hidesWindows == false, "\(bundleID)")
        }
        #expect(defaults.rule(for: "com.apple.Safari") == nil)
    }

    @Test func hidingExceptionsDropTheAppsWindows() async {
        let rules = EligibilityRules(exceptions: [AppException(bundleID: "com.apple.Notes", hidesWindows: true, ignoresShortcuts: false)])
        let (store, _) = await Fixture.store(rules: rules)
        let pids = await Set(store.entries.map(\.info.pid))
        #expect(!pids.contains(Fixture.notes))
        #expect(pids.contains(Fixture.safari))
    }

    @Test func passThroughExceptionsSuppressTheShortcuts() {
        let exceptions = AppException.defaults
        var machine = SwitcherStateMachine()
        machine.isSuppressed = exceptions.ignoresShortcuts(in: "com.vmware.fusion")
        #expect(machine.handle(.keyDown(keyCode: KeyCode.tab, modifiers: .option)) == .pass)
        machine.isSuppressed = exceptions.ignoresShortcuts(in: "com.apple.Safari")
        #expect(machine.handle(.keyDown(keyCode: KeyCode.tab, modifiers: .option)).decision == .consume)
    }

    @Test func exceptionsRoundTripThroughSettings() throws {
        let data = try JSONEncoder().encode(AppException.defaults)
        #expect(try JSONDecoder().decode([AppException].self, from: data) == AppException.defaults)
    }
}
