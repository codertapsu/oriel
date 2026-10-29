@testable import Capture
import CoreGraphics
import Foundation
import ImageIO
import PDFKit
import SharedUI
import Testing

/// Step Capture's exports (PLAN §17): one tall PNG, a PDF with a page per step, Markdown with an images folder and a
/// self-contained HTML file. Everything is written to a temporary directory.
struct StepExportTests {
    private static let accent = CGColor(srgbRed: 0.04, green: 0.52, blue: 1, alpha: 1)

    /// Three steps on disk: two 2× area captures (one with a click) and a wide 1× one.
    private func items(in directory: URL) throws -> [StepExportItem] {
        let images = try [
            TestImages.quadrants(width: 800, height: 500),
            TestImages.solid(width: 400, height: 700, red: 0.2, green: 0.6, blue: 0.3),
            TestImages.solid(width: 1800, height: 600, red: 0.9, green: 0.9, blue: 0.9),
        ]
        let titles = ["Open Settings", "", "Choose <Capture> & “Save”"]
        let notes = ["It is in the menu bar.\nClick the bay window.", "", "Done."]
        let scales: [CGFloat] = [2, 2, 1]
        return try images.enumerated().map { index, image in
            let url = directory.appending(path: "image-\(index).png")
            try ImageFile.write(image, to: url, format: .png, scale: scales[index])
            let step = Step(
                id: UUID(),
                imageURL: url,
                pixelWidth: image.width,
                pixelHeight: image.height,
                scale: scales[index],
                title: titles[index],
                note: notes[index],
                click: index == 0 ? CGPoint(x: 600, y: 125) : nil,
                kind: .area,
                date: Date()
            )
            return StepExportItem(step: step, number: index + 1)
        }
    }

    private func pixelSize(of url: URL) throws -> CGSize {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        return CGSize(width: image.width, height: image.height)
    }

    @Test func untitledStepsAreCalledByTheirNumber() throws {
        let directory = try TestImages.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let items = try items(in: directory)
        #expect(items.map(\.heading) == ["Open Settings", "Step 2", "Choose <Capture> & “Save”"])
        #expect(items[0].pointSize == CGSize(width: 400, height: 250))
        #expect(items[1].note.isEmpty)
    }

    @Test func theTallPNGHasEveryStepAtTheStepsScale() throws {
        let directory = try TestImages.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let items = try items(in: directory)
        let url = directory.appending(path: "Steps.png")
        let size = try StepSheetExporter.export(items, title: "Steps", subtitle: "3 steps", accent: Self.accent, to: url)
        let written = try pixelSize(of: url)
        #expect(written == size)
        // The widest image is 1800 points, so the sheet is at its widest, 1600 points, at 2×.
        #expect(written.width == 3200)
        #expect(written.height > CGFloat(250 + 350 + 533) * 2)
        let image = try #require(ImageFile.load(url))
        #expect(try TestImages.hex(image, x: 4, y: 4) == "#FFFFFF")
    }

    @Test func theSheetIsSizedByItsWidestImageWithinLimits() {
        #expect(StepSheetLayout.width(for: [CGSize(width: 300, height: 200)]) == 640)
        #expect(StepSheetLayout.width(for: [CGSize(width: 900, height: 200), CGSize(width: 500, height: 900)]) == 980)
        #expect(StepSheetLayout.width(for: [CGSize(width: 5000, height: 200)]) == 1600)
        let layout = StepSheetLayout(
            width: 640,
            titleHeight: 50,
            imageSizes: [CGSize(width: 300, height: 200), CGSize(width: 1200, height: 600)],
            textHeights: [(heading: 21, note: 0), (heading: 42, note: 34)]
        )
        #expect(layout.blocks[0].image == CGRect(x: 170, y: 160, width: 300, height: 200))
        #expect(layout.blocks[0].note == nil)
        #expect(layout.blocks[0].heading.minY == 122) // level with the badge
        #expect(layout.blocks[1].image.width == 560 && layout.blocks[1].image.height == 280)
        #expect(layout.blocks[1].note?.minY == layout.blocks[1].heading.maxY + 4)
        #expect(layout.height == layout.blocks[1].image.maxY + 40)
        #expect(layout.scale(preferred: 2) == 2)
        let long = StepSheetLayout(
            width: 1600,
            titleHeight: 50,
            imageSizes: Array(repeating: CGSize(width: 1600, height: 1000), count: 30),
            textHeights: []
        )
        #expect(long.pixelSize(scale: long.scale(preferred: 2)).height <= 30000)
        #expect(long.pixelSize(scale: long.scale(preferred: 2)).width * long.pixelSize(scale: long.scale(preferred: 2))
            .height <= 80_000_000)
    }

    @Test func thePDFHasAPagePerStepWithItsTitleAndNote() throws {
        let directory = try TestImages.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let items = try items(in: directory)
        let url = directory.appending(path: "Steps.pdf")
        try StepPDFExporter.export(items, title: "Set up Oriel", accent: Self.accent, paper: StepPDFExporter.a4, to: url)
        let document = try #require(PDFDocument(url: url))
        #expect(document.pageCount == 3)
        let first = try #require(document.page(at: 0)?.string)
        #expect(first.contains("Open Settings"))
        #expect(first.contains("It is in the menu bar."))
        #expect(first.contains("Step 1 of 3"))
        #expect(first.contains("Set up Oriel"))
        #expect(document.page(at: 2)?.string?.contains("Choose <Capture> & “Save”") == true)
        // A wide capture gets a landscape page.
        let wide = try #require(document.page(at: 2)?.bounds(for: .mediaBox))
        #expect(wide.width > wide.height)
        let tall = try #require(document.page(at: 1)?.bounds(for: .mediaBox))
        #expect(tall.size == StepPDFExporter.a4)
        #expect(document.outlineRoot?.numberOfChildren == 3)
        #expect(document.outlineRoot?.child(at: 1)?.label == "2. Step 2")
        #expect(document.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String == "Set up Oriel")
    }

    @Test func paperFollowsTheRegion() {
        #expect(StepPDFExporter.paperSize(for: Locale(identifier: "en_US")) == StepPDFExporter.letter)
        #expect(StepPDFExporter.paperSize(for: Locale(identifier: "vi_VN")) == StepPDFExporter.a4)
        #expect(StepPDFExporter.paperSize(for: Locale(identifier: "de_DE")) == StepPDFExporter.a4)
    }

    @Test func markdownLinksEveryImageInItsFolder() throws {
        let directory = try TestImages.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let items = try items(in: directory)
        let url = directory.appending(path: "My Guide (draft).md")
        let folder = directory.appending(path: "My Guide (draft) images", directoryHint: .isDirectory)
        // Left over from an earlier export of more steps; removed. Other files stay.
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data().write(to: folder.appending(path: "step-04.png"))
        try Data("keep".utf8).write(to: folder.appending(path: "notes.txt"))

        let written = try StepMarkdownExporter.export(items, title: "My Guide", subtitle: "3 steps", to: url)
        #expect(written.standardizedFileURL == folder.standardizedFileURL)
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.hasPrefix("# My Guide\n\n_3 steps_\n\n## 1. Open Settings\n"))
        #expect(text.contains("It is in the menu bar.  \nClick the bay window."))
        #expect(text.contains("## 2. Step 2"))
        let links = text.split(separator: "\n").filter { $0.hasPrefix("![") }
        #expect(links.count == 3)
        #expect(links.first == "![Open Settings](My%20Guide%20%28draft%29%20images/step-01.png)")
        for link in links {
            let open = try #require(link.firstIndex(of: "("))
            let target = String(link[link.index(after: open) ..< link.index(before: link.endIndex)])
            let path = try #require(target.removingPercentEncoding)
            #expect(FileManager.default.fileExists(atPath: directory.appending(path: path).path))
        }
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
        #expect(files == ["notes.txt", "step-01.png", "step-02.png", "step-03.png"])
        #expect(try pixelSize(of: folder.appending(path: "step-03.png")) == CGSize(width: 1800, height: 600))
        #expect(StepMarkdownExporter.fileName(for: 7, of: 120) == "step-007.png")
    }

    @Test func htmlEmbedsEveryImageAndEscapesText() throws {
        let directory = try TestImages.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let items = try items(in: directory)
        let url = directory.appending(path: "Steps.html")
        try StepHTMLExporter.export(items, title: "Fish & <Chips>", subtitle: "3 steps", accent: Self.accent, to: url)
        let html = try String(contentsOf: url, encoding: .utf8)
        #expect(html.hasPrefix("<!doctype html>"))
        #expect(html.contains("<title>Fish &amp; &lt;Chips&gt;</title>"))
        #expect(html.contains("Choose &lt;Capture&gt; &amp; “Save”"))
        #expect(html.contains("It is in the menu bar.<br>Click the bay window."))
        #expect(html.contains("--accent: #0A85FF"))
        #expect(!html.contains("src=\"file:") && !html.contains("src=\"http"))
        let marker = "data:image/png;base64,"
        #expect(html.components(separatedBy: marker).count - 1 == 3)
        // The first image is the 2× capture, shown at its point size, with its click marker drawn in.
        #expect(html.contains("width=\"400\" height=\"250\""))
        let start = try #require(html.range(of: marker)).upperBound
        let end = try #require(html[start...].firstIndex(of: "\""))
        let data = try #require(Data(base64Encoded: String(html[start ..< end])))
        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 800 && image.height == 500)
        #expect(try TestImages.hex(image, x: 600, y: 125) == "#FF3B30")
    }
}

/// Step Capture's images on disk and its click marker.
struct StepImageTests {
    @Test func imagesAreWrittenWithThumbnailsAndDeletedWithTheSequence() async throws {
        let directory = try TestImages.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = StepImageStore(directory: directory.appending(path: "Session", directoryHint: .isDirectory))
        let url = store.newImageURL()
        let thumbnail = try #require(try await store.write(TestImages.quadrants(width: 1200, height: 600), scale: 2, to: url))
        #expect(thumbnail.width == 480 && thumbnail.height == 240)
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(url.deletingLastPathComponent().standardizedFileURL == store.directory.standardizedFileURL)
        await store.removeAll()
        #expect(!FileManager.default.fileExists(atPath: store.directory.path))
    }

    @Test func theMarkerIsDrawnWhereTheClickWas() throws {
        let image = try TestImages.solid(width: 200, height: 100, red: 1, green: 1, blue: 1)
        let marked = try #require(StepImageRenderer.marked(image, at: CGPoint(x: 50, y: 40), scale: 1))
        #expect(marked.width == 200 && marked.height == 100)
        #expect(try TestImages.hex(marked, x: 50, y: 40) == "#FF3B30")
        #expect(try TestImages.hex(marked, x: 150, y: 80) == "#FFFFFF")
        // The ring, 16 points out.
        #expect(try TestImages.hex(marked, x: 66, y: 40) != "#FFFFFF")
    }

    @Test func undoKeepsWhatWasTypedSince() {
        let first = StepSessionTests.step("One")
        let second = StepSessionTests.step("Two")
        let before = StepSequence(title: "Steps", steps: [first, second])
        var now = before
        now.remove([first.id])
        now.update(second.id) { $0.note = "typed after the delete" }
        now.title = "Renamed"
        let restored = before.keepingText(of: now)
        #expect(restored.steps.map(\.id) == [first.id, second.id])
        #expect(restored.step(second.id)?.note == "typed after the delete")
        #expect(restored.step(first.id)?.title == "One")
        #expect(restored.title == "Renamed")
    }
}
