import AppKit
import OrielCore
import SwiftUI

/// Disk Space Analyzer (PLAN §7.10): where the space on each drive goes, and safe ways to get it back.
///
/// The window shows the volumes with their capacity and purgeable space, the cloud folders and the folders scanned
/// before; a scan of any of them as a sunburst, a treemap or a list, with the biggest and oldest files, duplicates,
/// file types and space hogs; and copies, moves and removals with confirmations, progress and Undo. Nothing runs
/// while the window is closed: scans, file watching and volume watching start with the window and stop with it.
public final class DiskAnalyzerModule: UtilityModule {
    public static let id: ModuleID = .diskAnalyzer

    public let displayName = "Disk Space Analyzer"

    public private(set) var isActive = false
    private var settings: SettingsStore?
    private var openSettings: (@MainActor @Sendable () -> Void)?
    private var model: DiskAnalyzerModel?
    private var window: DiskWindowController?
    private lazy var standaloneSettings = SettingsStore()
    private lazy var settingsModel = DiskSettingsModel(module: self)

    public init() {}

    /// Nothing is required. Full Disk Access lets a scan count every folder, and is asked for in the window when a
    /// scan could not read some; it is not a permission Oriel can check without reading the TCC database.
    public var requiredPermissions: Set<PermissionKind> {
        []
    }

    public var menuItems: [NSMenuItem] {
        []
    }

    public var settingsPane: AnyView? {
        AnyView(DiskSettingsView(model: settingsModel))
    }

    public var settingsSymbol: String {
        "internaldrive"
    }

    /// Opens the window (`oriel://disk`), and asks for a folder to scan (`oriel://disk/scan`).
    public var commands: [ToolCommand] {
        [
            ToolCommand(
                id: "openDiskAnalyzer", title: "Disk Space Analyzer", symbol: "internaldrive", group: .tools, route: "disk",
                perform: { [weak self] in self?.openWindow() }
            ),
            ToolCommand(
                id: "scanFolderWithDiskAnalyzer", title: "Scan Folder…", symbol: "folder.badge.gearshape", group: .tools,
                route: "disk/scan", showsInMenu: false, perform: { [weak self] in self?.scanFolder() }
            ),
        ]
    }

    /// `disk volumes [--json]` and `disk scan <path> [--top <n>] [--json]`, which only read.
    public var ipcCommands: [IPCCommandHandler] {
        [
            IPCCommandHandler(verb: "disk.volumes", usage: "disk volumes [--json]") { request in
                await DiskCommandLine.volumes(request)
            },
            IPCCommandHandler(verb: "disk.scan", usage: "disk scan <path> [--top <n>] [--json]") { [weak self] request in
                guard let self else { return .failure(request, "Oriel is shutting down.") }
                return await DiskCommandLine.scan(request, settings: currentSettings)
            },
        ]
    }

    var currentSettings: SettingsStore {
        settings ?? standaloneSettings
    }

    public func activate(context: ModuleContext) async {
        guard !isActive else { return }
        isActive = true
        settings = context.settings
        openSettings = context.openSettings
    }

    public func deactivate() async {
        guard isActive else { return }
        isActive = false
        window?.close()
        window = nil
        model = nil
    }

    /// Opens the window, or brings it to the front.
    func openWindow() {
        let model = model ?? DiskAnalyzerModel(settings: currentSettings)
        model.openSettings = openSettings
        self.model = model
        if let window {
            window.show()
            return
        }
        let controller = DiskWindowController(model: model)
        controller.onClose = { [weak self] in self?.window = nil }
        window = controller
        controller.show()
    }

    /// Opens the window and asks for a folder to scan.
    func scanFolder() {
        openWindow()
        window?.chooseFolder()
    }

    var isWindowOpen: Bool {
        window != nil
    }

    /// Settings installed or removed the helper: the window reads its state again, which it otherwise does only when it
    /// opens and when Oriel comes to the front.
    func helperChanged() {
        model?.refreshHelperStatus()
    }
}
