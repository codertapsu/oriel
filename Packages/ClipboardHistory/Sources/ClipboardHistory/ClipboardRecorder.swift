import AppKit
import OrielCore
import os
import SharedUI

/// Keeps what is copied (PLAN §7.9): Oriel's own copies as `Pasteboard.writes()` announces them, and other apps'
/// copies when the watcher sees the pasteboard change and macOS lets Oriel read it (Paste from Other Apps).
final class ClipboardRecorder {
    let store: ClipboardStore
    /// Whether macOS lets Oriel read other apps' copies, as of the last look.
    private(set) var access = ClipboardAccess.current
    /// Other apps' copies seen since launch that could not be kept, because macOS kept Oriel from reading them.
    private(set) var missedCopies = 0
    /// Called after the history, `access` or `missedCopies` changed.
    var onChange: (() -> Void)?
    /// Called after an image was kept, so its text can be read.
    var onImageAdded: (() -> Void)?

    private let settings: SettingsStore
    private let permissions: any PermissionChecking
    private lazy var watcher = PasteboardWatcher { [weak self] in
        self?.permissions.status(of: .accessibility) == .granted
    }

    private var writes: Task<Void, Never>?
    private var settingsObserver: (any NSObjectProtocol)?
    private var isReading = false
    private var readsAgain = false
    private let log = Log.logger("clipboard")

    init(store: ClipboardStore, settings: SettingsStore, permissions: any PermissionChecking) {
        self.store = store
        self.settings = settings
        self.permissions = permissions
    }

    /// The name Oriel's own copies are listed under ("Oriel", or "Oriel Debug").
    static var ownName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Oriel"
    }

    var isPaused: Bool {
        settings[ClipboardSettings.isPaused]
    }

    var isWatching: Bool {
        watcher.isRunning
    }

    func start() {
        refreshAccess()
        watcher.onChange = { [weak self] _ in self?.otherAppCopied() }
        watcher.start()
        writes = Task { [weak self] in
            for await write in Pasteboard.writes() {
                self?.ownCopy(write)
            }
        }
        settingsObserver = NotificationCenter.default.addObserver(
            forName: SettingsStore.didChangeNotification, object: settings, queue: .main
        ) { [weak self] note in
            let name = note.userInfo?["key"] as? String ?? ""
            MainActor.assumeIsolated {
                if ClipboardSettings.limitNames.contains(name) {
                    self?.applyLimits()
                }
            }
        }
    }

    func stop() {
        watcher.stop()
        writes?.cancel()
        writes = nil
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
        settingsObserver = nil
    }

    /// Looks at the clipboard now, as Clipboard History opens, so a copy made a moment ago is in the list.
    func checkNow() {
        refreshAccess()
        watcher.refreshMonitors()
        watcher.checkNow()
    }

    func setPaused(_ paused: Bool) {
        settings[ClipboardSettings.isPaused] = paused
        onChange?()
    }

    // MARK: Copies

    private func ownCopy(_ write: PasteboardWrite) {
        guard !isPaused else { return }
        Task {
            await keep(write.snapshot, label: write.label, sourceName: Self.ownName, sourceBundleID: Bundle.main.bundleIdentifier)
        }
    }

    private func otherAppCopied() {
        refreshAccess()
        guard !isPaused else { return }
        guard access.readsOtherApps else {
            missedCopies += 1
            onChange?()
            return
        }
        // While one of Oriel's windows has the keyboard (the panel's search field, Settings), the copy was made there.
        if NSApplication.shared.keyWindow != nil {
            read(sourceName: Self.ownName, sourceBundleID: Bundle.main.bundleIdentifier)
            return
        }
        // macOS does not say which app wrote the pasteboard; the app in front is the one the user copied in.
        let app = NSWorkspace.shared.frontmostApplication
        guard !PrivacyFilter.ignores(bundleID: app?.bundleIdentifier, in: settings[ClipboardSettings.ignoredApps]) else { return }
        read(sourceName: app?.localizedName, sourceBundleID: app?.bundleIdentifier)
    }

    /// One read at a time; a change during a read is read once it is done.
    private func read(sourceName: String?, sourceBundleID: String?) {
        guard !isReading else {
            readsAgain = true
            return
        }
        isReading = true
        let accessBefore = access
        Task {
            let outcome = await Task.detached(priority: .userInitiated) { PasteboardReader.read(.general) }.value
            isReading = false
            refreshAccess()
            var gotCopy = false
            if case let .snapshot(snapshot) = outcome {
                gotCopy = true
                await keep(snapshot, label: nil, sourceName: sourceName, sourceBundleID: sourceBundleID)
            }
            if accessBefore == .notAsked, access != .notAsked {
                macOSAsked(thisCopyAllowed: gotCopy)
            }
            if readsAgain {
                readsAgain = false
                otherAppCopied()
            }
        }
    }

    private func keep(_ snapshot: PasteboardSnapshot, label: String?, sourceName: String?, sourceBundleID: String?) async {
        do {
            let item = try await store.record(snapshot, label: label, sourceName: sourceName, sourceBundleID: sourceBundleID, date: Date())
            guard let item else { return }
            try await store.prune(ClipboardSettings.limits(in: settings))
            onChange?()
            if item.kind == .image, item.recognizedText == nil {
                onImageAdded?()
            }
        } catch {
            log.error("A copy could not be kept: \(error.localizedDescription, privacy: .private)")
        }
    }

    private func applyLimits() {
        let limits = ClipboardSettings.limits(in: settings)
        Task {
            if await (try? store.prune(limits)) ?? 0 > 0 {
                onChange?()
            }
        }
    }

    // MARK: Paste from Other Apps

    private func refreshAccess() {
        let current = ClipboardAccess.current
        guard current != access else { return }
        let wasAllowed = access == .allowed
        access = current
        onChange?()
        // Allowed in System Settings just now: what is on the clipboard has not been kept yet.
        if !wasAllowed, current == .allowed, !isPaused {
            read(sourceName: nil, sourceBundleID: nil)
        }
    }

    /// macOS has just asked the user about Oriel for the first time. When they let the copy through, Paste from Other
    /// Apps opens once, where Oriel can be set to Allow so that macOS stops asking at every copy.
    private func macOSAsked(thisCopyAllowed: Bool) {
        let state = access.rawValue
        log.notice("macOS asked about Paste from Other Apps; access is now \(state, privacy: .public)")
        guard access != .allowed, thisCopyAllowed, !settings[ClipboardSettings.openedPasteboardSettings] else { return }
        settings[ClipboardSettings.openedPasteboardSettings] = true
        permissions.openSystemSettings(for: .pasteboard)
        Toast.show("Set Oriel to Allow, so Clipboard History keeps every copy", symbol: "list.clipboard", duration: .seconds(5))
    }
}
