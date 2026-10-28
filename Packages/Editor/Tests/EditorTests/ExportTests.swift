import AppKit
import CoreGraphics
@testable import Editor
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

/// PNG, JPEG, HEIC and PDF output: the right type, the right size, the capture's DPI (PLAN §13.4).
@MainActor
struct ExportTests {
    /// 100×60 pt at 2×, a green frame near the top-left corner, 24 pt of transparent padding: 148×108 pt.
    private func document() throws -> EditorDocument {
        var document = try TestImages.document(width: 200, height: 120, scale: 2)
        document.canvasPadding = Padding(all: 24)
        let frame = Box(rect: CGRect(x: 2, y: 2, width: 20, height: 10), color: RGBAColor(red: 0, green: 1, blue: 0), width: 4)
        document.items = [.rect(frame)]
        return document
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(
            path: "oriel-editor-tests-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test(arguments: [EditorExportFormat.png, .jpeg, .heic])
    func bitmapFormatsHaveTheirTypeSizeAndDPI(_ format: EditorExportFormat) throws {
        let data = try #require(EditorExporter.data(for: document(), format: format))
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        #expect(CGImageSourceGetType(source) as String? == format.contentType.identifier)
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect((properties[kCGImagePropertyDPIWidth] as? NSNumber)?.doubleValue == 144)
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 296 && image.height == 216)
    }

    @Test func jpegFlattensTransparentPaddingOntoWhite() throws {
        let data = try #require(EditorExporter.data(for: document(), format: .jpeg))
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let pixels = try PixelBuffer(#require(CGImageSourceCreateImageAtIndex(source, 0, nil)))
        #expect(pixels.pixel(4, 4).distance(to: RGBA8(red: 255, green: 255, blue: 255)) <= 3)
        let png = try #require(EditorExporter.data(for: document(), format: .png))
        let pngSource = try #require(CGImageSourceCreateWithData(png as CFData, nil))
        #expect(try PixelBuffer(#require(CGImageSourceCreateImageAtIndex(pngSource, 0, nil))).pixel(4, 4).alpha == 0)
    }

    @Test func pdfIsOneUprightPageTheSizeOfTheCanvas() throws {
        let document = try document()
        let data = try #require(EditorExporter.data(for: document, format: .pdf))
        #expect(data.starts(with: Data("%PDF".utf8)))
        let provider = try #require(CGDataProvider(data: data as CFData))
        let pdf = try #require(CGPDFDocument(provider))
        #expect(pdf.numberOfPages == 1)
        let page = try #require(pdf.page(at: 1))
        let box = page.getBoxRect(.mediaBox)
        #expect(box.size == CGSize(width: 148, height: 108))

        // Rasterise the page: the frame drawn near the image's top-left must come out at the top-left.
        let context = try #require(EditorRenderer.makeBitmapContext(width: 296, height: 216, preferring: nil))
        context.scaleBy(x: 2, y: 2)
        context.drawPDFPage(page)
        let pixels = try PixelBuffer(#require(context.makeImage()))
        #expect(pixels.pixel(at: CGPoint(x: 24 + 2, y: 24 + 7), scale: 2).distance(to: RGBA8(red: 0, green: 255, blue: 0)) <= 8)
        #expect(pixels.pixel(at: CGPoint(x: 24 + 25, y: 24 + 40), scale: 2).distance(to: RGBA8(red: 60, green: 90, blue: 140)) <= 8)
        #expect(pixels.pixel(at: CGPoint(x: 24 + 75, y: 24 + 40), scale: 2).distance(to: RGBA8(red: 220, green: 200, blue: 160)) <= 8)
    }

    @Test(arguments: EditorExportFormat.allCases)
    func writtenFilesHaveTheFormatsType(_ format: EditorExportFormat) throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: EditorExporter.fileName(for: "Export test", fileExtension: format.fileExtension))
        try EditorExporter.write(document(), format: format, to: url)
        let type = try #require(url.resourceValues(forKeys: [.contentTypeKey]).contentType)
        #expect(type.conforms(to: format.contentType))
        #expect(url.lastPathComponent == "Export test.\(format.fileExtension)")
    }

    @Test func fileNamesLoseCharactersFinderRejects() {
        #expect(EditorExporter.fileName(for: "Screenshot 10:15/a", fileExtension: "png") == "Screenshot 10.15-a.png")
        #expect(EditorExporter.fileName(for: "  ", fileExtension: "pdf") == "Screenshot.pdf")
    }

    @Test func theFlattenedImageIsTheExportAtFullResolution() throws {
        let session = try EditorSession(document: document())
        let image = try #require(session.flattenedImage())
        #expect(image.width == 296 && image.height == 216)
    }

    @Test func dragOutPromisesTheFileAndOffersThePNG() throws {
        let png = try #require(EditorExporter.data(for: document(), format: .png))
        let writer = FilePromiseWriter(data: png, fileName: "Drag.png")
        let provider = ImageFilePromiseProvider(fileType: UTType.png.identifier, delegate: writer, imageData: png)
        #expect(provider.fileType == UTType.png.identifier)
        // A private pasteboard: the user's clipboard is never touched.
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let types = provider.writableTypes(for: pasteboard)
        #expect(types.contains(.png))
        #expect(provider.pasteboardPropertyList(forType: .png) as? Data == png)
        #expect(writer.filePromiseProvider(provider, fileNameForType: UTType.png.identifier) == "Drag.png")

        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let destination = directory.appending(path: "Drag.png")
        var failure: (any Error)?
        writer.filePromiseProvider(provider, writePromiseTo: destination) { failure = $0 }
        #expect(failure == nil)
        #expect(try Data(contentsOf: destination) == png)
        #expect(DragOutView.previewSize(for: CGSize(width: 800, height: 400)) == CGSize(width: 160, height: 80))
    }
}
