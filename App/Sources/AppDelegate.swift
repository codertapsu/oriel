import AppKit
import DiskAnalyzer

/// Entry point and application delegate of the menu-bar agent.
@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: AppController?
    /// Whether this launch opens the window (`LaunchChecks.opensWindow(launch:)`), decided while the launch event is current.
    private var opensWindow = false
    /// What macOS asked Oriel to open before it started: launched to open a file or URL, `application(_:open:)` comes
    /// before `applicationDidFinishLaunching`.
    private(set) var pendingURLs: [URL] = []
    /// Set while waiting for the copy this one replaces to quit (Move to Applications).
    private var exitObserver: (any NSObjectProtocol)?

    static func main() {
        // Disk Space Analyzer's helper is this executable, started by launchd as root: it only lists folders for Oriel.
        PrivilegedReaderDaemon.runIfRequested()
        // Read as Administrator through the password prompt runs it as root too, only to list folders.
        if let status = ElevatedRead.runIfRequested(CommandLine.arguments) {
            exit(status)
        }
        if CommandLine.arguments.contains("--self-test") {
            exit(SelfTest.run())
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // As the host of `make test`, start nothing: a test run must not take the socket, the shortcuts or the
        // event tap from the copy the user is running.
        guard !LaunchChecks.isTestHost else { return }
        opensWindow = LaunchChecks.opensWindow(launch: notification)
        if let other = LaunchChecks.otherInstance() {
            if LaunchChecks.replacedProcessID(in: CommandLine.arguments) == other.processIdentifier {
                start(after: other)
            } else {
                other.activate()
                NSApp.terminate(nil)
            }
            return
        }
        start()
    }

    private func start() {
        guard controller == nil else { return }
        let controller = AppController()
        self.controller = controller
        controller.start(opensWindow: opensWindow, opening: pendingURLs)
        pendingURLs = []
    }

    /// Starts once `other`, the copy that moved this one to Applications, has quit, so the two never hold the socket,
    /// the shortcuts or the event tap at once. Should it still be there after `replacementDeadline`, it stays the
    /// one running.
    private func start(after other: NSRunningApplication) {
        let processID = other.processIdentifier
        exitObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard app?.processIdentifier == processID else { return }
            MainActor.assumeIsolated { self?.replacedCopyQuit() }
        }
        // It may have quit before the observer was in place.
        if other.isTerminated {
            replacedCopyQuit()
            return
        }
        Task { [weak self] in
            try? await Task.sleep(for: LaunchChecks.replacementDeadline)
            guard let self, exitObserver != nil else { return }
            stopWaitingForExit()
            other.activate()
            NSApp.terminate(nil)
        }
    }

    private func replacedCopyQuit() {
        guard exitObserver != nil else { return }
        stopWaitingForExit()
        start()
    }

    private func stopWaitingForExit() {
        if let exitObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(exitObserver)
        }
        exitObserver = nil
    }

    func application(_: NSApplication, open urls: [URL]) {
        guard let controller else {
            pendingURLs += urls
            return
        }
        for url in urls {
            controller.handle(url)
        }
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows _: Bool) -> Bool {
        controller?.showSettings()
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let controller else { return .terminateNow }
        // Restores Cmd-Tab, finishes a recording and closes the socket before the process goes.
        Task { @MainActor in
            await controller.shutdown()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
