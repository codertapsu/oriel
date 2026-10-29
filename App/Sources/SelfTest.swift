import ActivityMonitor
import Capture
import ClipboardHistory
import ColorPicker
import DiskAnalyzer
import Editor
import Foundation
import Hotkeys
import IPC
import OCR
import OrielCore
import OrielTranslation
import Permissions
import PrivateAPIs
import Recording
import ScreenRuler
import SharedUI
import Upload
import WindowSwitcher
import WindowTiling

/// `Oriel --self-test`: shows that every package links and loads, prints the capability flags and exits 0
/// (PLAN §3.2, §13.1). It never prompts for a permission.
enum SelfTest {
    /// One name per linked package, in the order of PLAN §6.2.
    static let packageNames = [
        "OrielCore", "PrivateAPIs", "Permissions", "Hotkeys", "SharedUI", "IPC", "WindowSwitcher",
        "Capture", "Recording", "Editor", "OCR", "OrielTranslation", "Upload", "ClipboardHistory", "DiskAnalyzer",
        "ActivityMonitor", "ColorPicker", "ScreenRuler", "WindowTiling",
    ]

    /// A type from each package, so the linker keeps every module and the self-test proves it loads.
    private static let anchors: [Any.Type] = [
        Capabilities.self, PrivateAPIs.self, PermissionCenter.self, CarbonHotkeyEngine.self, FloatingPanel.self,
        IPCServer.self, WindowSwitcherModule.self, CaptureCoordinator.self, RecordingCoordinator.self,
        EditorLauncher.self, VisionTextRecognizer.self, TranslationCoordinator.self, S3Uploader.self,
        ClipboardHistoryModule.self, DiskAnalyzerModule.self, ActivityMonitorModule.self, ColorPickerModule.self,
        ScreenRulerModule.self, WindowTilingModule.self,
    ]

    static func run() -> Int32 {
        print(report())
        return 0
    }

    static func report() -> String {
        let symbols = PrivateAPIs.shared.presence
        let missing = symbols.filter { !$0.value }.map(\.key.rawValue).sorted()
        let permissions = PermissionKind.allCases
            .map { "\($0.rawValue)=\(PermissionCenter.currentStatus(of: $0).rawValue)" }
            .joined(separator: " ")
        return """
        Oriel self-test
        arch: \(HardwareInfo.architecture)
        rosetta: \(HardwareInfo.isTranslated)
        apple silicon hardware: \(HardwareInfo.isAppleSiliconHardware)
        packages: \(packageNames.joined(separator: ", ")) (\(anchors.count) loaded)
        private symbols: \(symbols.count - missing.count)/\(symbols.count)\(missing.isEmpty ? "" : " missing \(missing)")
        permissions: \(permissions)
        """
    }
}
