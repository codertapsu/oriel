import AppKit
import CoreGraphics
@testable import Editor
import Foundation
import OrielCore
import SwiftUI
import Testing

/// The editor settings feed every new window, and the settings pane builds.
@MainActor
struct SettingsTests {
    private let suiteName = "com.codertapsu.oriel.tests.\(UUID().uuidString)"

    private func capture() throws -> CaptureResult {
        try CaptureResult(
            image: #require(TestImages.halves(width: 300, height: 200)),
            kind: .area,
            rect: CGRect(x: 0, y: 0, width: 150, height: 100),
            scale: 2,
            date: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }

    @Test func newWindowsStartFromTheEditorSettings() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = SettingsStore(defaults: defaults)
        settings[EditorSettings.defaultColor] = .green
        settings[EditorSettings.strokeWidth] = 9
        settings[EditorSettings.exportFormat] = .heic
        settings[EditorSettings.backgroundPreset] = .mint

        let session = try EditorLauncher(settings: settings).makeSession(for: capture())
        #expect(session.color == .green)
        #expect(session.strokeWidth == 9)
        #expect(session.defaults.exportFormat == .heic)
        #expect(session.document.background == BackgroundPreset.mint.style)
        #expect(session.document.canvasPadding == Padding(all: BackgroundPreset.defaultPadding(for: CGSize(width: 150, height: 100))))
        #expect(session.document.base.scale == 2)
        #expect(session.title.hasPrefix("Screenshot "))
        #expect(!session.hasUnsavedChanges && !session.canUndo)
    }

    @Test func withNothingSetWindowsStartRedAtFourPointsWithoutBackground() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let session = try EditorLauncher(settings: SettingsStore(defaults: defaults)).makeSession(for: capture())
        #expect(session.color == .red)
        #expect(session.strokeWidth == 4)
        #expect(session.defaults.exportFormat == .png)
        #expect(session.document.background == nil && session.document.canvasPadding == nil)
    }

    @Test func widthsOutsideTheRangeAreClamped() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = SettingsStore(defaults: defaults)
        settings[EditorSettings.strokeWidth] = 99
        #expect(EditorDefaults(settings: settings).strokeWidth == 20)
        settings[EditorSettings.strokeWidth] = -3
        #expect(EditorDefaults(settings: settings).strokeWidth == 1)
    }

    @Test func screenshotTitlesFollowTheMacOSPattern() throws {
        let date = try #require(DateComponents(calendar: Calendar.current, year: 2026, month: 10, day: 29, hour: 9, minute: 5, second: 7)
            .date)
        #expect(EditorLauncher.title(for: date) == "Screenshot 2026-10-29 at 09.05.07")
    }

    @Test func theSettingsPaneBuildsWithoutAWindow() throws {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let host = NSHostingView(rootView: EditorSettingsView(settings: SettingsStore(defaults: defaults)))
        host.frame = CGRect(x: 0, y: 0, width: 480, height: 320)
        host.layoutSubtreeIfNeeded()
        #expect(host.fittingSize.width > 0)
    }
}
