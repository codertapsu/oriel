import CoreGraphics
@testable import Editor
import Foundation
import OrielCore
import SharedUI
import Testing

/// The editable `.oriel` bundle: JSON plus the original PNG, written and read back exactly.
@MainActor
struct OrielBundleTests {
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(
            path: "oriel-editor-tests-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// One item of every kind, a crop, padding and a background.
    private func fullDocument() throws -> EditorDocument {
        var document = try EditorDocument(base: ImageRef(image: #require(TestImages.noise(width: 120, height: 80)), scale: 2))
        document.crop = CGRect(x: 2, y: 3, width: 50.5, height: 30)
        document.canvasPadding = Padding(top: 10, left: 12, bottom: 14, right: 16)
        document.background = BackgroundStyle(fill: .gradient, colors: [.blue, .purple], angle: 30, shadow: true, cornerRadius: 9)
        document.items = [
            .arrow(Arrow(start: CGPoint(x: 1, y: 2), end: CGPoint(x: 30.25, y: 20.5), color: .red, width: 3)),
            .line(Line(start: CGPoint(x: 5, y: 5), end: CGPoint(x: 40, y: 5), color: .orange, width: 2)),
            .rect(Box(rect: CGRect(x: 10, y: 10, width: 20, height: 10), color: .yellow, width: 4)),
            .ellipse(Box(rect: CGRect(x: 12, y: 12, width: 8, height: 8), color: .green, width: 1)),
            .freehand(FreehandPath(points: [CGPoint(x: 1, y: 1), CGPoint(x: 2, y: 3), CGPoint(x: 5, y: 8)], color: .blue, width: 2)),
            .highlighter(FreehandPath(points: [CGPoint(x: 3, y: 30), CGPoint(x: 50, y: 30)], color: .yellow, width: 16)),
            .text(TextBox(origin: CGPoint(x: 4, y: 22), text: "Ünïcödé ✓\nsecond line", color: .white, fontSize: 14)),
            .counter(Counter(center: CGPoint(x: 45, y: 25), number: 3, color: .purple, radius: 12)),
            .blur(Region(rect: CGRect(x: 0, y: 0, width: 15, height: 15), amount: 8)),
            .pixelate(Region(rect: CGRect(x: 20, y: 0, width: 15, height: 15), amount: 6)),
            .spotlight(Region(rect: CGRect(x: 30, y: 20, width: 10, height: 10), amount: 0)),
        ]
        return document
    }

    @Test func everyKindOfItemSurvivesSavingAndReopening() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let document = try fullDocument()
        #expect(Set(document.items.map(\.kind)) == Set(AnnotationKind.allCases))
        let url = directory.appending(path: "Round trip.oriel")
        try OrielBundle.write(document, to: url)

        #expect(FileManager.default.fileExists(atPath: url.appending(path: OrielBundle.documentFileName).path))
        #expect(FileManager.default.fileExists(atPath: url.appending(path: ImageRef.defaultFileName).path))
        let reopened = try OrielBundle.read(from: url)
        #expect(reopened == document)
        #expect(reopened.items == document.items)
        #expect(try PixelBuffer(reopened.base.image).isIdentical(to: PixelBuffer(document.base.image)))
        // Reopened documents render the same as the originals.
        let before = try PixelBuffer(#require(EditorRenderer.makeImage(document, scale: 2)))
        let after = try PixelBuffer(#require(EditorRenderer.makeImage(reopened, scale: 2)))
        #expect(before.isIdentical(to: after))
    }

    @Test func theJSONIsVersionedAndReadable() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "Readable.oriel")
        try OrielBundle.write(fullDocument(), to: url)
        let json = try String(contentsOf: url.appending(path: OrielBundle.documentFileName), encoding: .utf8)
        #expect(json.contains("\"version\" : 1"))
        #expect(json.contains("\"type\" : \"arrow\""))
        #expect(json.contains("\"file\" : \"original.png\""))
        #expect(!json.contains("_0"))
    }

    @Test func savingAgainReplacesTheBundle() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "Replace.oriel")
        var document = try fullDocument()
        try OrielBundle.write(document, to: url)
        document.items.removeAll()
        document.crop = nil
        try OrielBundle.write(document, to: url)
        let reopened = try OrielBundle.read(from: url)
        #expect(reopened.items.isEmpty && reopened.crop == nil)
        #expect(try FileManager.default.contentsOfDirectory(atPath: url.path).sorted() == [
            OrielBundle.documentFileName,
            ImageRef.defaultFileName,
        ].sorted())
    }

    @Test func bundlesFromANewerVersionAndOtherFoldersAreRefused() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "Future.oriel")
        try OrielBundle.write(fullDocument(), to: url)
        let jsonURL = url.appending(path: OrielBundle.documentFileName)
        let json = try String(contentsOf: jsonURL, encoding: .utf8).replacingOccurrences(of: "\"version\" : 1", with: "\"version\" : 99")
        try Data(json.utf8).write(to: jsonURL)
        #expect(throws: OrielError.self) { try OrielBundle.read(from: url) }

        let folder = directory.appending(path: "Plain.oriel", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        #expect(throws: OrielError.self) { try OrielBundle.read(from: folder) }
    }

    @Test func theLauncherOpensBundlesAndImageFilesWithTheirScale() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let suiteName = "com.codertapsu.oriel.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let launcher = EditorLauncher(settings: SettingsStore(defaults: defaults))

        let bundleURL = directory.appending(path: "Opened.oriel")
        let document = try fullDocument()
        try OrielBundle.write(document, to: bundleURL)
        let fromBundle = try launcher.makeSession(forFileAt: bundleURL)
        #expect(fromBundle.document == document)
        #expect(fromBundle.fileURL == bundleURL)
        #expect(fromBundle.title == "Opened")
        #expect(!fromBundle.hasUnsavedChanges)

        let imageURL = directory.appending(path: "Retina.png")
        try ImageFile.write(#require(TestImages.halves(width: 64, height: 32)), to: imageURL, format: .png, scale: 2)
        let fromImage = try launcher.makeSession(forFileAt: imageURL)
        #expect(fromImage.document.base.scale == 2)
        #expect(fromImage.document.base.pointSize == CGSize(width: 32, height: 16))
        #expect(fromImage.fileURL == nil)
        #expect(fromImage.sourceURL == imageURL)

        let textURL = directory.appending(path: "notes.txt")
        try Data("not an image".utf8).write(to: textURL)
        #expect(throws: OrielError.self) { try launcher.makeSession(forFileAt: textURL) }
        #expect(throws: (any Error).self) { try launcher.open(fileAt: directory.appending(path: "missing.png")) }
        #expect(launcher.openWindowCount == 0)
    }
}
