import AppKit
import SharedUI

/// The real feedback: `NSSound.beep()`, `Toast`, VoiceOver announcements and `PermissionNotice`.
final class SystemTilingFeedback: TilingFeedback {
    private let notice = PermissionNotice()

    func respond(_ response: TilingResponse) {
        switch response {
        case let .announcement(text):
            NSAccessibility.post(element: NSApplication.shared, notification: .announcementRequested, userInfo: [
                .announcement: text,
                .priority: NSAccessibilityPriorityLevel.medium.rawValue,
            ])
        case .beep:
            NSSound.beep()
        case let .toast(message, symbol):
            Toast.show(message, symbol: symbol)
        }
    }

    func askForAccessibility(paneName: String, openSettings: @escaping @MainActor () -> Void) {
        notice.show(paneName: paneName, openSettings: openSettings)
    }

    func dismiss() {
        notice.close()
    }
}
