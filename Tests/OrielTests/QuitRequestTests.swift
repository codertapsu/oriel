import AppKit
@testable import Oriel
import Testing

/// Quit in the Dock's menu closes Oriel's windows, and every other request to quit quits it (PLAN §10.1).
@MainActor
struct QuitRequestTests {
    @Test func theDocksQuitClosesTheWindows() {
        #expect(QuitRequest.isFromTheDock(Self.quitEvent(), senderBundleID: QuitRequest.dockBundleID))
    }

    /// Logging out, restarting or shutting down, Quit & Reopen in System Settings, a script, another app, and Quit in
    /// the menu-bar menu, which sends no event at all, quit Oriel.
    @Test func everyOtherRequestQuits() {
        #expect(!QuitRequest.isFromTheDock(Self.quitEvent(reason: kAEReallyLogOut), senderBundleID: QuitRequest.dockBundleID))
        #expect(!QuitRequest.isFromTheDock(Self.quitEvent(reason: kAEShutDown), senderBundleID: "com.apple.loginwindow"))
        #expect(!QuitRequest.isFromTheDock(Self.quitEvent(), senderBundleID: "com.apple.systempreferences"))
        #expect(!QuitRequest.isFromTheDock(Self.quitEvent(), senderBundleID: nil))
        #expect(!QuitRequest.isFromTheDock(nil))
        // A local event names no sender.
        #expect(!QuitRequest.isFromTheDock(Self.quitEvent()))
    }

    @Test func onlyAQuitEventCounts() {
        let open = NSAppleEventDescriptor.appleEvent(
            withEventClass: AEEventClass(kCoreEventClass), eventID: AEEventID(kAEReopenApplication), targetDescriptor: nil,
            returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID)
        )
        #expect(!QuitRequest.isFromTheDock(open, senderBundleID: QuitRequest.dockBundleID))
    }

    private static func quitEvent(reason: OSType? = nil) -> NSAppleEventDescriptor {
        let event = NSAppleEventDescriptor.appleEvent(
            withEventClass: AEEventClass(kCoreEventClass), eventID: AEEventID(kAEQuitApplication), targetDescriptor: nil,
            returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID)
        )
        if let reason {
            event.setParam(NSAppleEventDescriptor(enumCode: reason), forKeyword: AEKeyword(kAEQuitReason))
        }
        return event
    }
}
