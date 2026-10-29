@testable import Oriel
import Testing

@MainActor
struct SelfTestTests {
    @Test func selfTestNamesEveryPackage() {
        #expect(SelfTest.packageNames == [
            "OrielCore", "PrivateAPIs", "Permissions", "Hotkeys", "SharedUI", "IPC", "WindowSwitcher",
            "Capture", "Recording", "Editor", "OCR", "OrielTranslation", "Upload", "ClipboardHistory", "DiskAnalyzer",
            "ActivityMonitor", "ColorPicker", "ScreenRuler", "WindowTiling",
        ])
        #expect(SelfTest.report().contains("packages: OrielCore, PrivateAPIs"))
    }
}
