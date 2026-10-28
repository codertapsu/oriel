@testable import Capture
import CoreGraphics
import Foundation
import ImageIO
import OrielCore
import Permissions
import Testing

/// The coordinator's logic that needs no screen: where and how files are saved, how frozen displays are cropped,
/// which Quick Access actions appear. Everything it writes goes to a temporary directory.
@MainActor
struct CaptureCoordinatorTests {
    private let suiteName = "com.codertapsu.oriel.capture-tests.\(UUID().uuidString)"

    private func makeCoordinator(
        directory: URL,
        recognizer: (any TextRecognizing)? = nil
    ) throws -> (CaptureCoordinator, SettingsStore) {
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let settings = SettingsStore(defaults: defaults)
        settings[CaptureSettings.saveFolder] = directory.path
        let coordinator = CaptureCoordinator(
            settings: settings,
            permissions: PermissionCenter(),
            textRecognizer: recognizer,
            historyDirectory: directory.appending(path: "History", directoryHint: .isDirectory)
        )
        return (coordinator, settings)
    }

    private func result(kind: CaptureKind = .area) throws -> CaptureResult {
        let date = try #require(ISO8601DateFormatter().date(from: "2026-10-29T10:15:30Z"))
        return try CaptureResult(image: TestImages.quadrants(width: 40, height: 30), kind: kind, rect: .zero, scale: 2, date: date)
    }

    /// Removes the temporary directory and the settings domain the test used.
    private func cleanUp(_ directory: URL) {
        try? FileManager.default.removeItem(at: directory)
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    private func dpi(of url: URL) throws -> Double? {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        return properties?[kCGImagePropertyDPIWidth] as? Double
    }

    @Test func savingWithoutAURLUsesTheFolderAndTemplateAndNeverOverwrites() throws {
        let directory = try TestImages.temporaryDirectory()
        defer { cleanUp(directory) }
        let (coordinator, settings) = try makeCoordinator(directory: directory)
        settings[CaptureSettings.filenameTemplate] = "Shot {kind} {width}x{height}"
        let capture = try result()
        let first = try coordinator.save(capture, to: nil)
        let second = try coordinator.save(capture, to: nil)
        #expect(first.lastPathComponent == "Shot Area 40x30.png")
        #expect(second.lastPathComponent == "Shot Area 40x30 2.png")
        #expect(first.deletingLastPathComponent().standardizedFileURL == directory.standardizedFileURL)
        #expect(try dpi(of: first) == 144)
    }

    @Test func fileURLsChooseTheFormatAndDirectoriesGetTemplateNames() throws {
        let directory = try TestImages.temporaryDirectory()
        defer { cleanUp(directory) }
        let (coordinator, settings) = try makeCoordinator(directory: directory)
        let capture = try result()

        let jpeg = try coordinator.save(capture, to: directory.appending(path: "a.jpeg"))
        #expect(jpeg.lastPathComponent == "a.jpeg")
        let source = try #require(CGImageSourceCreateWithURL(jpeg as CFURL, nil))
        #expect((CGImageSourceGetType(source) as String?) == "public.jpeg")

        settings[CaptureSettings.format] = .heic
        let bare = try coordinator.save(capture, to: directory.appending(path: "b"))
        #expect(bare.lastPathComponent == "b.heic")

        let subfolder = directory.appending(path: "Sub", directoryHint: .isDirectory)
        let named = try coordinator.save(capture, to: subfolder)
        #expect(named.deletingLastPathComponent().lastPathComponent == "Sub")
        #expect(named.pathExtension == "heic")

        #expect(throws: OrielError.self) {
            try coordinator.save(capture, to: directory.appending(path: "c.gif"))
        }
    }

    @Test func areasAreCroppedFromTheFrozenDisplayInPixels() throws {
        let directory = try TestImages.temporaryDirectory()
        defer { cleanUp(directory) }
        let (coordinator, _) = try makeCoordinator(directory: directory)
        // A 2× display at a negative origin: 20 × 15 points, 40 × 30 pixels.
        let display = try FrozenDisplay(
            display: DisplayFrame(id: 7, frame: CGRect(x: -20, y: -15, width: 20, height: 15), scale: 2),
            image: TestImages.quadrants(width: 40, height: 30),
            hdrImage: nil
        )
        let window = WindowTarget(id: 3, frame: CGRect(x: -30, y: -20, width: 40, height: 40), title: "Doc", appName: "Pages", processID: 9)
        let captured = try coordinator.crop(
            CGRect(x: -10, y: -15, width: 10, height: 5),
            from: display,
            windows: [window],
            kind: .area,
            intent: .copy
        )
        #expect(captured.result.image.width == 20 && captured.result.image.height == 10)
        #expect(try TestImages.hex(captured.result.image, x: 5, y: 5) == "#0000FF")
        #expect(captured.result.scale == 2)
        #expect(captured.result.appName == "Pages")
        #expect(captured.intent == .copy)
        #expect(throws: CaptureError.emptyArea) {
            try coordinator.crop(CGRect(x: 500, y: 500, width: 5, height: 5), from: display, windows: [], kind: .area, intent: .capture)
        }
    }

    @Test func quickAccessOffersOnlyWhatTheAppCanDo() throws {
        let directory = try TestImages.temporaryDirectory()
        defer { cleanUp(directory) }
        let (bare, _) = try makeCoordinator(directory: directory)
        #expect(bare.quickAccessActions == [.copy, .save, .pin, .close])

        let (full, settings) = try makeCoordinator(directory: directory, recognizer: FixedTextRecognizer(text: "Hello"))
        let actions = RecordingActions()
        full.actions = actions
        #expect(full.quickAccessActions == QuickAccessAction.allCases)
        settings[CaptureSettings.timerSeconds] = 10
        #expect(full.timerDelay == .seconds(10))

        let capture = try result()
        full.perform(QuickAccessAction.annotate, on: capture)
        full.perform(QuickAccessAction.translate, on: capture)
        full.perform(QuickAccessAction.upload, on: capture)
        #expect(actions.annotated == [capture.id] && actions.translated == [capture.id] && actions.uploaded == [capture.id])
    }
}
