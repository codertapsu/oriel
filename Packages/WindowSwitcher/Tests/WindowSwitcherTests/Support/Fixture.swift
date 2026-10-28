import CoreGraphics
import OrielCore
@testable import WindowSwitcher

/// A system shaped like the dev Mac's on macOS 27.0.1 (see the S1-style probe in the phase report): every app
/// owns menu-bar-sized and 500×500 helper windows at layer 0 on no Space, accessory agents expose odd AX
/// windows, and real windows sit on the current Space, another Space, a full-screen Space, minimized, or in
/// a hidden app.
enum Fixture {
    static let safari: Int32 = 100
    static let notes: Int32 = 200
    static let agent: Int32 = 300
    static let menuAgent: Int32 = 400
    static let fusion: Int32 = 500

    static let display = DisplayInfo(id: 1, uuid: "DISPLAY-1", bounds: CGRect(x: 0, y: 0, width: 1512, height: 982))

    static let apps = [
        AppRecord(pid: safari, bundleID: "com.apple.Safari", name: "Safari", isActive: true),
        AppRecord(pid: notes, bundleID: "com.apple.Notes", name: "Notes", isHidden: true),
        AppRecord(pid: agent, bundleID: "com.example.agent", name: "Agent", policy: .accessory),
        AppRecord(pid: menuAgent, bundleID: "com.apple.MenuBarAgent", name: "MenuBarAgent", policy: .accessory),
        AppRecord(pid: fusion, bundleID: "com.vmware.fusion", name: "VMware Fusion"),
    ]

    static let windowFrame = CGRect(x: 100, y: 100, width: 1200, height: 800)

    /// Front to back.
    static let server = [
        ServerWindowRecord(id: 10, pid: safari, frame: windowFrame, isOnScreen: true),
        ServerWindowRecord(id: 50, pid: fusion, frame: CGRect(x: 200, y: 150, width: 1024, height: 768), isOnScreen: true),
        // A layer-8 utility window, and a floating palette, both listed by AX.
        ServerWindowRecord(id: 16, pid: safari, layer: 8, frame: CGRect(x: 0, y: 0, width: 300, height: 300), isOnScreen: true),
        ServerWindowRecord(id: 15, pid: safari, frame: CGRect(x: 0, y: 0, width: 300, height: 300), isOnScreen: true),
        ServerWindowRecord(id: 11, pid: safari, frame: windowFrame, isOnScreen: false),
        ServerWindowRecord(id: 14, pid: safari, frame: display.bounds, isOnScreen: false),
        ServerWindowRecord(id: 20, pid: notes, frame: CGRect(x: 300, y: 200, width: 800, height: 600), isOnScreen: false),
        ServerWindowRecord(id: 21, pid: notes, frame: CGRect(x: 320, y: 220, width: 800, height: 600), isOnScreen: false),
        // macOS 27's per-app menu-bar windows and hidden helpers.
        ServerWindowRecord(id: 12, pid: safari, frame: CGRect(x: 0, y: 0, width: 1512, height: 33), isOnScreen: false),
        ServerWindowRecord(id: 13, pid: safari, frame: CGRect(x: 0, y: 0, width: 500, height: 500), isOnScreen: false),
        ServerWindowRecord(id: 30, pid: agent, frame: CGRect(x: 0, y: 0, width: 500, height: 500), isOnScreen: false),
    ]

    static let spaces = SpaceSnapshot(
        displays: [SpaceSnapshot.Display(displayID: display.id, currentSpaceID: 1, spaceIDs: [1, 2, 3], fullScreenSpaceIDs: [3])],
        windowSpaces: [10: [1], 11: [2], 12: [], 13: [], 14: [3], 15: [1], 16: [1], 20: [1], 21: [], 30: [], 50: [1]]
    )

    static let accessibility: [Int32: AXWindowsResult] = [
        safari: .windows([
            AXWindowRecord(windowID: 10, title: "Apple", frame: windowFrame),
            AXWindowRecord(windowID: 15, title: "Palette", subrole: "AXFloatingWindow"),
            AXWindowRecord(windowID: 16, title: "Utility"),
        ]),
        notes: .windows([
            AXWindowRecord(windowID: 20, title: "Shopping"),
            AXWindowRecord(windowID: 21, title: "Recipes", isMinimized: true),
        ]),
        agent: .windows([]),
        menuAgent: .windows([AXWindowRecord(windowID: 28, title: "", subrole: "AXDialog")]),
        fusion: .windows([AXWindowRecord(windowID: 50, title: "Windows 11")]),
    ]

    /// Other-Space windows as cached elements or remote tokens reach them, plus a helper that is not a window.
    static let reachable = [
        AXWindowRecord(windowID: 11, title: "GitHub"),
        AXWindowRecord(windowID: 14, title: "Video", isFullScreen: true),
        AXWindowRecord(windowID: 13, title: "", subrole: "AXUnknown"),
    ]

    static func source(
        capabilities: SourceCapabilities = SourceCapabilities(),
        spaces: SpaceSnapshot? = Fixture.spaces
    ) async -> FakeWindowSource {
        let source = FakeWindowSource(capabilities: capabilities)
        await source.set(apps: apps)
        for (pid, result) in accessibility {
            await source.set(accessibility: result, for: pid)
        }
        await source.set(reachable: reachable)
        await source.set(server: server)
        await source.set(spaces: spaces)
        await source.set(displays: [display])
        await source.set(focused: 10, for: safari)
        return source
    }

    static func store(
        capabilities: SourceCapabilities = SourceCapabilities(),
        spaces: SpaceSnapshot? = Fixture.spaces,
        rules: EligibilityRules = EligibilityRules()
    ) async -> (WindowStore, FakeWindowSource) {
        let source = await source(capabilities: capabilities, spaces: spaces)
        let store = WindowStore(source: source, rules: rules)
        await store.bootstrap()
        return (store, source)
    }

    /// A plain window for pure tests.
    static func entry(
        _ id: UInt32,
        pid: Int32 = 1,
        app: String = "App",
        title: String = "Window",
        frame: CGRect = CGRect(x: 0, y: 0, width: 800, height: 600),
        minimized: Bool = false,
        hidden: Bool = false,
        fullScreen: Bool = false,
        currentSpace: Bool = true,
        space: Int? = nil,
        display: UInt32? = nil
    ) -> WindowEntry {
        WindowEntry(info: WindowInfo(
            id: id, pid: pid, appName: app, bundleID: "com.example.\(app.lowercased())", title: title, frame: frame,
            isMinimized: minimized, isHidden: hidden, isFullScreen: fullScreen, isOnCurrentSpace: currentSpace,
            spaceIndex: space, displayID: display
        ))
    }
}
