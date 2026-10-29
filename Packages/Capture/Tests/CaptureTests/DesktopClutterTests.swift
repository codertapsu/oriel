@testable import Capture
import CoreGraphics
import Testing

/// Which windows "Hide desktop icons and widgets" leaves out (PLAN §17), with the owners and layers macOS 27.0.1
/// reports for the desktop.
struct DesktopClutterTests {
    private let desktop = Int(CGWindowLevelForKey(.desktopWindow))
    private let icons = Int(CGWindowLevelForKey(.desktopIconWindow))

    @Test func finderIconsAndWidgetsAreLeftOut() {
        #expect(icons == -2_147_483_603)
        #expect(DesktopClutter.isIconOrWidget(bundleID: "com.apple.finder", ownerName: "Finder", layer: icons))
        #expect(DesktopClutter.isIconOrWidget(
            bundleID: "com.apple.notificationcenterui",
            ownerName: "Notification Center",
            layer: icons + 2
        ))
    }

    @Test func theWallpaperStays() {
        // The Window Server's and WindowManager's full-display windows below the desktop level.
        #expect(!DesktopClutter.isIconOrWidget(bundleID: nil, ownerName: "Window Server", layer: desktop - 3))
        #expect(!DesktopClutter.isIconOrWidget(bundleID: "com.apple.WindowManager", ownerName: "WindowManager", layer: desktop - 1))
        #expect(!DesktopClutter.isIconOrWidget(bundleID: "com.apple.dock", ownerName: "Dock", layer: desktop))
        #expect(!DesktopClutter.isIconOrWidget(bundleID: nil, ownerName: "Window Server", layer: icons + 1))
    }

    @Test func windowsAboveTheDesktopStay() {
        // Finder's own windows, Notification Center's banners and every app's windows.
        #expect(!DesktopClutter.isIconOrWidget(bundleID: "com.apple.finder", ownerName: "Finder", layer: 0))
        #expect(!DesktopClutter.isIconOrWidget(bundleID: "com.apple.notificationcenterui", ownerName: "Notification Center", layer: 23))
        #expect(!DesktopClutter.isIconOrWidget(bundleID: "com.apple.Safari", ownerName: "Safari", layer: 0))
        #expect(!DesktopClutter.isIconOrWidget(bundleID: "com.apple.Safari", ownerName: "Safari", layer: icons))
    }

    @Test func aMissingBundleIDFallsBackToTheOwnerName() {
        #expect(DesktopClutter.isIconOrWidget(bundleID: nil, ownerName: "Finder", layer: icons))
        #expect(DesktopClutter.isIconOrWidget(bundleID: "", ownerName: "Notification Center", layer: icons + 2))
        #expect(!DesktopClutter.isIconOrWidget(bundleID: nil, ownerName: "Finder", layer: 0))
        #expect(!DesktopClutter.isIconOrWidget(bundleID: nil, ownerName: nil, layer: icons))
    }

    @Test func itIsOffUnlessTurnedOn() {
        #expect(!CaptureSettings.hidesDesktopIcons.defaultValue)
    }
}
