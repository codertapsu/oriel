import AppKit
@testable import ColorPicker
import Foundation
import OrielCore

/// Test helpers. Settings come from a suite that is only read, so no test writes a preferences file.
@MainActor
enum Fixtures {
    static func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(
            path: "ColorPickerTests-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func readOnlySettings() -> SettingsStore {
        SettingsStore(defaults: UserDefaults(suiteName: "ColorPickerTests-\(UUID().uuidString)") ?? .standard)
    }

    static func model(in directory: URL) -> ColorPickerModel {
        ColorPickerModel(store: ColorStore(directory: directory), settings: readOnlySettings())
    }

    static func context(settings: SettingsStore) -> ModuleContext {
        ModuleContext(
            services: ServiceContainer(keychain: KeychainStore(prefix: "ColorPickerTests"), permissions: FakePermissions()),
            settings: settings,
            log: Log.logger("tests")
        )
    }

    /// A key press as AppKit delivers it.
    static func key(_ characters: String, code: UInt16, modifiers: NSEvent.ModifierFlags = []) -> NSEvent {
        guard let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: characters,
            isARepeat: false,
            keyCode: code
        ) else { preconditionFailure("AppKit made no key event") }
        return event
    }
}

/// Permissions that are never granted and never prompt.
@MainActor
final class FakePermissions: PermissionChecking {
    func status(of _: PermissionKind) -> PermissionStatus {
        .notDetermined
    }

    func request(_: PermissionKind) async -> PermissionStatus {
        .notDetermined
    }

    func openSystemSettings(for _: PermissionKind) {}
}

/// A loupe that hands back colors it was given, without showing anything.
@MainActor
final class FakeSampler: ColorSampling {
    var colors: [ColorValue?]
    private(set) var samples = 0

    init(_ colors: [ColorValue?]) {
        self.colors = colors
    }

    func sample() async -> ColorValue? {
        samples += 1
        return colors.isEmpty ? nil : colors.removeFirst()
    }
}
