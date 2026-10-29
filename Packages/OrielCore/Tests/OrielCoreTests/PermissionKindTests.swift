import OrielCore
import Testing

struct PermissionKindTests {
    @Test func macOS27CallsTheAccessibilityPaneDeviceControlAndDataAccess() {
        #expect(PermissionKind.accessibility.settingsPaneName(macOSMajorVersion: 26) == "Accessibility")
        #expect(PermissionKind.accessibility.settingsPaneName(macOSMajorVersion: 27) == "Device Control and Data Access")
        #expect(PermissionKind.screenRecording.settingsPaneName(macOSMajorVersion: 27) == "Screen & System Audio Recording")
    }

    @Test func theAccessibilityHintNamesThePaneAndTheRemoveAndAddAgainFix() {
        let hint = PermissionKind.accessibility.grantHint(macOSMajorVersion: 27)
        #expect(hint.contains("Privacy & Security → Device Control and Data Access"))
        #expect(hint.contains("remove it with −"))
        #expect(PermissionKind.accessibility.grantHint(macOSMajorVersion: 26).contains("Privacy & Security → Accessibility"))
    }

    @Test func theScreenRecordingHintMentionsQuitAndReopen() {
        #expect(PermissionKind.screenRecording.grantHint(macOSMajorVersion: 27).contains("Quit & Reopen"))
    }

    @Test func pasteFromOtherAppsIsOptionalAndExplainsWhereOrielAppears() {
        #expect(!PermissionKind.pasteboard.isRequired)
        #expect(PermissionKind.pasteboard.settingsPaneName(macOSMajorVersion: 27) == "Paste from Other Apps")
        let hint = PermissionKind.pasteboard.grantHint(macOSMajorVersion: 27)
        #expect(hint.contains("Privacy & Security → Paste from Other Apps"))
        #expect(hint.contains("after macOS has asked"))
    }
}
