import AppKit
import ApplicationServices
import AVFoundation
import CoreGraphics
import Observation
import OrielCore

/// Live permission state for the UI, and the ways to ask for each permission (PLAN §8.1–8.2).
///
/// Oriel is a menu-bar app, and coming back from System Settings rarely activates it, so state is re-read when
/// Oriel becomes active, when any app comes to the front (the user leaving System Settings), and shortly after
/// macOS reports a change to the Accessibility list. Nothing polls (PLAN §7.1.6); call `refresh()` after
/// anything else that could change it.
@MainActor
@Observable
public final class PermissionCenter: PermissionChecking {
    /// Posted by macOS when the list of apps allowed to use Accessibility changes.
    public static let accessibilityListChanged = Notification.Name("com.apple.accessibility.api")
    /// The Accessibility check lags `accessibilityListChanged` slightly.
    static let accessibilitySettleDelay: Duration = .milliseconds(300)

    public private(set) var statuses: [PermissionKind: PermissionStatus] = [:]
    @ObservationIgnored private let reader: @MainActor (PermissionKind) -> PermissionStatus
    @ObservationIgnored private var observers: [(center: NotificationCenter, token: any NSObjectProtocol)] = []
    @ObservationIgnored private var pendingRefresh: Task<Void, Never>?

    public convenience init() {
        self.init(
            reader: { Self.currentStatus(of: $0) },
            local: .default,
            workspace: NSWorkspace.shared.notificationCenter,
            distributed: DistributedNotificationCenter.default()
        )
    }

    /// For tests: a fake reader and private notification centers.
    init(
        reader: @escaping @MainActor (PermissionKind) -> PermissionStatus,
        local: NotificationCenter,
        workspace: NotificationCenter,
        distributed: NotificationCenter
    ) {
        self.reader = reader
        refresh()
        observe(NSApplication.didBecomeActiveNotification, on: local) { $0.refresh() }
        observe(NSWorkspace.didActivateApplicationNotification, on: workspace) { $0.refresh() }
        observe(Self.accessibilityListChanged, on: distributed) { $0.refreshAfterAccessibilitySettles() }
    }

    public func status(of kind: PermissionKind) -> PermissionStatus {
        statuses[kind] ?? reader(kind)
    }

    public var allRequiredGranted: Bool {
        PermissionKind.allCases.filter(\.isRequired).allSatisfy { status(of: $0) == .granted }
    }

    public func refresh() {
        var fresh: [PermissionKind: PermissionStatus] = [:]
        for kind in PermissionKind.allCases {
            fresh[kind] = reader(kind)
        }
        if fresh != statuses {
            statuses = fresh
        }
    }

    private func observe(
        _ name: Notification.Name,
        on center: NotificationCenter,
        perform: @escaping @MainActor (PermissionCenter) -> Void
    ) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                perform(self)
            }
        }
        observers.append((center, token))
    }

    /// One short wait, not a polling loop.
    private func refreshAfterAccessibilitySettles() {
        pendingRefresh?.cancel()
        pendingRefresh = Task { [weak self] in
            try? await Task.sleep(for: Self.accessibilitySettleDelay)
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }

    public func request(_ kind: PermissionKind) async -> PermissionStatus {
        switch kind {
        case .accessibility:
            // The literal, not kAXTrustedCheckOptionPrompt, which Swift 6 sees as shared mutable state.
            _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        case .screenRecording:
            // Shows the system alert the first time; afterwards it only answers.
            _ = CGRequestScreenCaptureAccess()
        case .microphone:
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        case .camera:
            _ = await AVCaptureDevice.requestAccess(for: .video)
        case .pasteboard:
            await Self.readPasteboardOnce()
        }
        refresh()
        return status(of: kind)
    }

    /// Reads what is on the clipboard, which makes macOS ask whether Oriel may paste from the app that copied it and
    /// lists Oriel in Paste from Other Apps. Off the main thread: macOS holds the read while it asks. Nothing is kept.
    private static func readPasteboardOnce() async {
        await Task.detached(priority: .userInitiated) {
            guard let item = NSPasteboard.general.pasteboardItems?.first, let type = item.types.first else { return }
            _ = item.data(forType: type)
        }.value
    }

    public func openSystemSettings(for kind: PermissionKind) {
        let anchor = switch kind {
        case .accessibility: "Privacy_Accessibility"
        case .screenRecording: "Privacy_ScreenCapture"
        case .microphone: "Privacy_Microphone"
        case .camera: "Privacy_Camera"
        case .pasteboard: "Privacy_Pasteboard"
        }
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Permission name → state, for Diagnostics and `oriel debug capabilities`.
    public var summary: [String: String] {
        Dictionary(uniqueKeysWithValues: PermissionKind.allCases.map { ($0.rawValue, status(of: $0).rawValue) })
    }

    /// Reads the state through the public APIs only; Oriel never touches the TCC database (PLAN §8.2). Paste from Other
    /// Apps counts as granted only when set to Allow: while macOS asks each time, Clipboard History cannot read.
    public nonisolated static func currentStatus(of kind: PermissionKind) -> PermissionStatus {
        switch kind {
        case .accessibility:
            AXIsProcessTrusted() ? .granted : .notDetermined
        case .screenRecording:
            CGPreflightScreenCaptureAccess() ? .granted : .notDetermined
        case .microphone:
            map(AVCaptureDevice.authorizationStatus(for: .audio))
        case .camera:
            map(AVCaptureDevice.authorizationStatus(for: .video))
        case .pasteboard:
            map(NSPasteboard.general.accessBehavior)
        }
    }

    private nonisolated static func map(_ behavior: NSPasteboard.AccessBehavior) -> PermissionStatus {
        switch behavior {
        case .alwaysAllow: .granted
        case .alwaysDeny: .denied
        case .default, .ask: .notDetermined
        @unknown default: .notDetermined
        }
    }

    private nonisolated static func map(_ status: AVAuthorizationStatus) -> PermissionStatus {
        switch status {
        case .authorized: .granted
        case .denied, .restricted: .denied
        case .notDetermined: .notDetermined
        @unknown default: .notDetermined
        }
    }
}
