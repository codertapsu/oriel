import CoreGraphics
@testable import Editor
import Foundation
import OrielCore
import SharedUI
import Testing

/// The editable `.oriel` bundle: JSON plus the original PNG and the pixels of image layers, written and read back
/// exactly; documents saved by earlier versions still open.
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

    /// One item of every kind, styled steps, a crop, padding, a picture background with every option, and a tone.
    private func fullDocument() throws -> EditorDocument {
        var document = try EditorDocument(base: ImageRef(image: #require(TestImages.noise(width: 120, height: 80)), scale: 2))
        let object = try ImageAsset(image: #require(TestImages.halves(width: 20, height: 10)))
        let fill = try ImageAsset(image: #require(TestImages.solid(width: 20, height: 10)))
        let picture = try ImageAsset(image: #require(TestImages.noise(width: 32, height: 24)))
        document.crop = CGRect(x: 2, y: 3, width: 50.5, height: 30)
        document.canvasPadding = Padding(top: 10, left: 12, bottom: 14, right: 16)
        document.background = BackgroundStyle(
            fill: .image,
            colors: [.blue, .purple],
            angle: 30,
            image: BackgroundImage(asset: picture, source: .file, blur: 6),
            shadow: true,
            shadowStyle: ShadowStyle(radius: 18, opacity: 0.5, offset: CGSize(width: 2, height: 9)),
            cornerRadius: 9,
            inset: 7,
            aspect: .pixels(width: 1200, height: 675),
            alignment: .topTrailing,
            windowFrame: .dark
        )
        document.tone = 0.4
        document.items = [
            .arrow(Arrow(start: CGPoint(x: 1, y: 2), end: CGPoint(x: 30.25, y: 20.5), color: .red, width: 3)),
            .line(Line(start: CGPoint(x: 5, y: 5), end: CGPoint(x: 40, y: 5), color: .orange, width: 2)),
            .rect(Box(rect: CGRect(x: 10, y: 10, width: 20, height: 10), color: .yellow, width: 4)),
            .ellipse(Box(rect: CGRect(x: 12, y: 12, width: 8, height: 8), color: .green, width: 1)),
            .freehand(FreehandPath(points: [CGPoint(x: 1, y: 1), CGPoint(x: 2, y: 3), CGPoint(x: 5, y: 8)], color: .blue, width: 2)),
            .highlighter(FreehandPath(points: [CGPoint(x: 3, y: 30), CGPoint(x: 50, y: 30)], color: .yellow, width: 16)),
            .text(TextBox(origin: CGPoint(x: 4, y: 22), text: "Ünïcödé ✓\nsecond line", color: .white, fontSize: 14)),
            .counter(Counter(center: CGPoint(x: 45, y: 25), number: 3, color: .purple, radius: 12)),
            .counter(Counter(
                center: CGPoint(x: 20, y: 25), number: 2, color: .green, radius: 10, shape: .square, label: .roman,
                pointer: CGPoint(x: 5, y: 35), sequence: 1
            )),
            .blur(Region(rect: CGRect(x: 0, y: 0, width: 15, height: 15), amount: 8)),
            .pixelate(Region(rect: CGRect(x: 20, y: 0, width: 15, height: 15), amount: 6)),
            .spotlight(Region(rect: CGRect(x: 30, y: 20, width: 10, height: 10), amount: 0)),
            .patch(ImageLayer(asset: fill, rect: CGRect(x: 30, y: 30, width: 10, height: 5), source: .object)),
            .image(ImageLayer(asset: object, rect: CGRect(x: 35, y: 32, width: 10, height: 5), source: .object)),
            .bar(Bar(rect: CGRect(x: 4, y: 40, width: 30, height: 4), color: .black)),
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
        let images = try FileManager.default.contentsOfDirectory(atPath: url.appending(path: ImageAsset.folderName).path)
        #expect(images.count == 3)
        let reopened = try OrielBundle.read(from: url)
        #expect(reopened == document)
        #expect(reopened.items == document.items)
        #expect(reopened.background == document.background)
        #expect(reopened.tone == 0.4)
        #expect(try PixelBuffer(reopened.base.image).isIdentical(to: PixelBuffer(document.base.image)))
        for (before, after) in zip(document.assets, reopened.assets) {
            #expect(try PixelBuffer(after.image).isIdentical(to: PixelBuffer(before.image)))
        }
        // Reopened documents render the same as the originals. A picture decoded from PNG has straight alpha where
        // the original was premultiplied, and Core Image's resampling and blur of the two can round a level or two
        // apart here and there.
        let before = try PixelBuffer(#require(EditorRenderer.makeImage(document, scale: 2)))
        let after = try PixelBuffer(#require(EditorRenderer.makeImage(reopened, scale: 2)))
        #expect(before.width == after.width && before.height == after.height)
        #expect(zip(before.allPixels, after.allPixels).allSatisfy { $0.distance(to: $1) <= 2 })
    }

    @Test func theJSONIsVersionedAndReadable() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "Readable.oriel")
        try OrielBundle.write(fullDocument(), to: url)
        let json = try String(contentsOf: url.appending(path: OrielBundle.documentFileName), encoding: .utf8)
        #expect(json.contains("\"version\" : 2"))
        #expect(json.contains("\"type\" : \"arrow\""))
        #expect(json.contains("\"type\" : \"patch\""))
        #expect(json.contains("\"type\" : \"image\""))
        #expect(json.contains("\"type\" : \"bar\""))
        #expect(json.contains("\"file\" : \"original.png\""))
        #expect(json.contains("\"file\" : \"images/"))
        #expect(json.contains("\"windowFrame\" : \"dark\""))
        #expect(!json.contains("_0"))
    }

    /// A document exactly as version 1 (Oriel 0.1.0) wrote it: no step styles, no new background fields, no tone.
    @Test func documentsFromVersionOneStillOpenAndLookTheSame() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "Old.oriel", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let base = try #require(TestImages.halves(width: 40, height: 20))
        try #require(ImageFile.data(for: base, format: .png, scale: 2)).write(to: url.appending(path: ImageRef.defaultFileName))
        let json = """
        {
          "document" : {
            "background" : { "angle" : 45, "colors" : [ { "alpha" : 1, "blue" : 1, "green" : 0.478, "red" : 0 } ],
                             "cornerRadius" : 12, "fill" : "solid", "shadow" : true },
            "base" : { "file" : "original.png", "id" : "8A9E2A54-8F0B-4C5E-9F3A-7C1D2E3F4A5B",
                       "pixelHeight" : 20, "pixelWidth" : 40, "scale" : 2 },
            "canvasPadding" : { "bottom" : 24, "left" : 24, "right" : 24, "top" : 24 },
            "items" : [
              { "type" : "counter", "id" : "1B2C3D4E-5F60-4718-8293-A4B5C6D7E8F9", "center" : [ 10, 5 ],
                "number" : 1, "radius" : 8, "color" : { "alpha" : 1, "blue" : 0.188, "green" : 0.231, "red" : 1 } },
              { "type" : "blur", "id" : "2C3D4E5F-6071-4829-93A4-B5C6D7E8F901", "rect" : [ [ 0, 0 ], [ 10, 5 ] ], "amount" : 6 }
            ]
          },
          "version" : 1
        }
        """
        try Data(json.utf8).write(to: url.appending(path: OrielBundle.documentFileName))
        let document = try OrielBundle.read(from: url)
        let background = try #require(document.background)
        #expect(background.fill == .solid && background.cornerRadius == 12 && background.shadow)
        #expect(background.shadowStyle == nil && background.inset == 0 && background.aspect == .auto)
        #expect(background.alignment == .center && background.windowFrame == .none && background.image == nil)
        #expect(document.tone == nil)
        guard case let .counter(counter) = document.items.first else {
            Issue.record("the step did not decode")
            return
        }
        #expect(counter.shape == .circle && counter.label == .numbers && counter.pointer == nil && counter.sequence == 0)
        #expect(counter.text == "1")
        // The layout is the version 1 layout: the image plus its padding.
        #expect(CanvasLayout(document: document).canvasSize == CGSize(width: 20 + 48, height: 10 + 48))
        #expect(EditorRenderer.makeImage(document, scale: 2) != nil)
    }

    @Test func aMissingImageLayerFileIsAnError() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "Damaged.oriel")
        try OrielBundle.write(fullDocument(), to: url)
        let images = url.appending(path: ImageAsset.folderName)
        let first = try #require(FileManager.default.contentsOfDirectory(atPath: images.path).first)
        try FileManager.default.removeItem(at: images.appending(path: first))
        #expect(throws: (any Error).self) { try OrielBundle.read(from: url) }
    }

    @Test func savingAgainReplacesTheBundle() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "Replace.oriel")
        var document = try fullDocument()
        try OrielBundle.write(document, to: url)
        document.items.removeAll()
        document.crop = nil
        document.background = nil
        try OrielBundle.write(document, to: url)
        let reopened = try OrielBundle.read(from: url)
        #expect(reopened.items.isEmpty && reopened.crop == nil)
        // No layers or pictures left: no images folder either.
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
        let json = try String(contentsOf: jsonURL, encoding: .utf8).replacingOccurrences(of: "\"version\" : 2", with: "\"version\" : 99")
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
