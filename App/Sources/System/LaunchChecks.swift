import AppKit
import OrielCore

/// Checks made once at launch (PLAN §3.2, §15.6).
@MainActor
enum LaunchChecks {
    /// Debug builds have their own bundle ID, so that macOS keeps their permissions apart from the installed app's.
    nonisolated static let debugSuffix = ".debug"
    /// Move to Applications launches the moved copy with this argument and its own process ID.
    nonisolated static let replacingArgument = "--replacing"
    /// How long a moved copy waits for the copy it replaces to quit before leaving that one running instead.
    nonisolated static let replacementDeadline: Duration = .seconds(30)

    /// Another copy (a Debug build next to an installed one, say) already owns the socket and the hotkeys.
    static func otherInstance() -> NSRunningApplication? {
        guard let bundleID = Bundle.main.bundleIdentifier else { return nil }
        let me = ProcessInfo.processInfo.processIdentifier
        return family(of: bundleID).lazy
            .flatMap { NSRunningApplication.runningApplications(withBundleIdentifier: $0) }
            .first { $0.processIdentifier != me }
    }

    /// The release bundle ID and its Debug variant: either one running counts as Oriel.
    nonisolated static func family(of bundleID: String) -> [String] {
        let base = bundleID.hasSuffix(debugSuffix) ? String(bundleID.dropLast(debugSuffix.count)) : bundleID
        return [base, base + debugSuffix]
    }

    /// The arguments that tell a moved copy which process it replaces.
    nonisolated static func relaunchArguments(replacing processID: pid_t) -> [String] {
        [replacingArgument, String(processID)]
    }

    /// The process this copy was launched to replace, from its launch arguments.
    nonisolated static func replacedProcessID(in arguments: [String]) -> pid_t? {
        guard let index = arguments.firstIndex(of: replacingArgument), arguments.indices.contains(index + 1) else { return nil }
        return pid_t(arguments[index + 1])
    }

    /// Whether Oriel opens its window as it starts (PLAN §10.1), so that starting it shows something besides an icon in
    /// the menu bar: when the user opened it, not when macOS starts it at login, and not when it was launched to open a
    /// file or a URL (`launchIsDefault` is false then).
    nonisolated static func opensWindowAtLaunch(launchIsDefault: Bool, launchedAtLogin: Bool) -> Bool {
        launchIsDefault && !launchedAtLogin
    }

    /// From `applicationDidFinishLaunching`'s notification, the only moment the launch's Apple event is current: the
    /// open-application event carries `keyAELaunchedAsLogInItem` when macOS starts a login item.
    static func opensWindow(launch notification: Notification) -> Bool {
        let launchIsDefault = notification.userInfo?[NSApplication.launchIsDefaultUserInfoKey] as? Bool ?? true
        let event = NSAppleEventManager.shared().currentAppleEvent
        let launchedAtLogin = event?.eventID == kAEOpenApplication
            && event?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        return opensWindowAtLaunch(launchIsDefault: launchIsDefault, launchedAtLogin: launchedAtLogin)
    }

    /// True when an XCTest/Swift Testing bundle hosts itself in this process (`make test`).
    static var isTestHost: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] != nil || environment["XCTestSessionIdentifier"] != nil
            || environment["XCTestBundlePath"] != nil
    }

    static func showArchitectureNotices(settings: SettingsStore) {
        if HardwareInfo.isTranslated, !settings[AppSettings.rosettaWarningShown] {
            settings[AppSettings.rosettaWarningShown] = true
            alert(
                "Oriel is running under Rosetta",
                "This Mac has Apple silicon, but the Intel half of the app is running. Reinstall the Universal build."
            )
        } else if !HardwareInfo.isAppleSiliconHardware, !settings[AppSettings.intelNoticeShown] {
            settings[AppSettings.intelNoticeShown] = true
            alert(
                "Running on Intel",
                "Everything works, but the on-device AI features (Foundation Models, Apple Intelligence) are unavailable, and "
                    + "a translation model running on this Mac is very slow."
            )
        }
    }

    /// Run from a disk image or a translocated copy, Oriel offers to move itself to /Applications, where its
    /// permissions survive updates (PLAN §15.6). Returns true when it moved: the copy in Applications is launching,
    /// told to wait until this one has quit (the two would fight over the socket and the shortcuts), and this one
    /// quits without starting anything else.
    @discardableResult
    static func offerMoveToApplications() -> Bool {
        let path = Bundle.main.bundlePath
        let readOnly = (try? URL(fileURLWithPath: path).resourceValues(forKeys: [.volumeIsReadOnlyKey]))?.volumeIsReadOnly ?? false
        guard path.contains("/AppTranslocation/") || readOnly, !path.hasPrefix("/Applications/") else { return false }
        let alert = NSAlert()
        alert.messageText = "Move Oriel to the Applications folder?"
        alert.informativeText = "Oriel is running from a disk image. Permissions you grant a copy that is not in "
            + "Applications are lost the next time it moves."
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        let destination = URL(fileURLWithPath: "/Applications/Oriel.app")
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.trashItem(at: destination, resultingItemURL: nil)
            }
            try FileManager.default.copyItem(at: Bundle.main.bundleURL, to: destination)
        } catch {
            Self.alert("Oriel could not move itself", error.localizedDescription)
            return false
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.arguments = relaunchArguments(replacing: ProcessInfo.processInfo.processIdentifier)
        NSWorkspace.shared.openApplication(at: destination, configuration: configuration) { _, error in
            let reason = error?.localizedDescription
            Task { @MainActor in
                if let reason {
                    Self.alert("Oriel is in Applications now", "Open it from there: it could not be opened for you (\(reason)).")
                }
                NSApp.terminate(nil)
            }
        }
        return true
    }

    static func alert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        NSApp.activate()
        alert.runModal()
    }
}
