import Foundation
import OrielCore

/// Everything the user can trigger from the status menu, a global shortcut or an `oriel://` URL. One table,
/// so the three never disagree (PLAN §10.1, §6.5).
enum AppAction: String, CaseIterable, Identifiable {
    case captureArea, captureWindow, captureScreen, captureScrolling, capturePreviousArea, captureWithTimer, captureAllDisplays
    case recordArea, recordWindow, recordScreen, stopRecording
    case translateArea
    case showCaptureHistory, showTranslationHistory, openImage
    case showSettings, showOnboarding, quit

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .captureArea: "Capture Area"
        case .captureWindow: "Capture Window"
        case .captureScreen: "Capture Screen"
        case .captureScrolling: "Scrolling Capture"
        case .capturePreviousArea: "Capture Previous Area"
        case .captureWithTimer: "Capture with Timer"
        case .captureAllDisplays: "Capture All Displays"
        case .recordArea: "Record Area"
        case .recordWindow: "Record Window"
        case .recordScreen: "Record Screen"
        case .stopRecording: "Stop Recording"
        case .translateArea: "Translate Area"
        case .showCaptureHistory: "Capture History"
        case .showTranslationHistory: "Translation History"
        case .openImage: "Open Image in Editor…"
        case .showSettings: "Settings…"
        case .showOnboarding: "Permissions…"
        case .quit: "Quit Oriel"
        }
    }

    var symbol: String {
        switch self {
        case .captureArea: "rectangle.dashed"
        case .captureWindow: "macwindow"
        case .captureScreen: "display"
        case .captureScrolling: "arrow.up.and.down.text.horizontal"
        case .capturePreviousArea: "arrow.uturn.backward.square"
        case .captureWithTimer: "timer"
        case .captureAllDisplays: "rectangle.on.rectangle"
        case .recordArea: "record.circle"
        case .recordWindow: "inset.filled.rectangle.badge.record"
        case .recordScreen: "menubar.dock.rectangle.badge.record"
        case .stopRecording: "stop.circle"
        case .translateArea: "character.bubble"
        case .showCaptureHistory: "clock.arrow.circlepath"
        case .showTranslationHistory: "text.bubble"
        case .openImage: "photo"
        case .showSettings: "gearshape"
        case .showOnboarding: "lock.shield"
        case .quit: "power"
        }
    }

    /// The default global shortcut, ⌃⇧ plus a key (PLAN §7.2, §10.5), for the actions that have one.
    var defaultShortcut: KeyCombo? {
        let controlShift: KeyCombo.Modifiers = [.control, .shift]
        return switch self {
        case .captureArea: KeyCombo(keyCode: KeyCode.ansi4, modifiers: controlShift)
        case .captureWindow: KeyCombo(keyCode: KeyCode.ansi5, modifiers: controlShift)
        case .captureScreen: KeyCombo(keyCode: KeyCode.ansi3, modifiers: controlShift)
        case .captureScrolling: KeyCombo(keyCode: KeyCode.ansi6, modifiers: controlShift)
        case .recordArea: KeyCombo(keyCode: KeyCode.ansiR, modifiers: controlShift)
        case .translateArea: KeyCombo(keyCode: KeyCode.ansiT, modifiers: controlShift)
        default: nil
        }
    }

    /// Actions that can have a global shortcut, in Settings order.
    static let shortcutActions: [AppAction] = [
        .captureArea, .captureWindow, .captureScreen, .captureScrolling, .capturePreviousArea, .captureWithTimer,
        .captureAllDisplays, .recordArea, .recordWindow, .recordScreen, .translateArea, .showCaptureHistory,
    ]

    var shortcutKey: SettingKey<KeyCombo?> {
        SettingKey("shortcuts.\(rawValue)", default: defaultShortcut)
    }

    /// `oriel://capture/area` and friends.
    init?(url: URL) {
        guard url.scheme == "oriel" else { return nil }
        let path = ([url.host] + url.pathComponents.filter { $0 != "/" }).compactMap(\.self).joined(separator: "/")
        let routes: [String: AppAction] = [
            "capture/area": .captureArea, "capture/window": .captureWindow, "capture/screen": .captureScreen,
            "capture/scrolling": .captureScrolling, "capture/previous": .capturePreviousArea, "capture/timer": .captureWithTimer,
            "capture/all": .captureAllDisplays, "record/area": .recordArea, "record/window": .recordWindow,
            "record/screen": .recordScreen, "record/stop": .stopRecording,
            "translate/area": .translateArea, "history": .showCaptureHistory, "settings": .showSettings,
        ]
        guard let action = routes[path] else { return nil }
        self = action
    }
}
