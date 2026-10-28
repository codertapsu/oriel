@testable import Capture
import Foundation
import OrielCore
import Testing

struct FilenameTemplateTests {
    private let utc = TimeZone(identifier: "UTC") ?? .current

    private func context(kind: CaptureKind = .area, app: String? = nil, title: String? = nil) throws -> FilenameTemplate.Context {
        let date = try #require(ISO8601DateFormatter().date(from: "2026-10-29T10:15:30Z"))
        return FilenameTemplate.Context(date: date, kind: kind, appName: app, windowTitle: title, pixelWidth: 800, pixelHeight: 600)
    }

    @Test func defaultTemplateNamesFilesTheWayMacOSDoes() throws {
        let name = try FilenameTemplate.render(FilenameTemplate.defaultTemplate, context: context(), timeZone: utc)
        #expect(name == "Oriel 2026-10-29 at 10.15.30")
    }

    @Test func everyTokenIsFilledAndSeparatorsAreReplaced() throws {
        let template = "{kind} {app} – {title} {width}x{height}"
        let name = try FilenameTemplate.render(
            template,
            context: context(kind: .window, app: "Safari", title: "Apple: Home/Page"),
            timeZone: utc
        )
        #expect(name == "Window Safari – Apple- Home-Page 800x600")
    }

    @Test func missingValuesLeaveNoDoubleSpacesAndUnknownTokensStay() throws {
        let name = try FilenameTemplate.render("{app} {kind}  {foo}", context: context(kind: .scrolling), timeZone: utc)
        #expect(name == "Scrolling {foo}")
    }

    @Test(arguments: [
        ("..hidden", "hidden"),
        ("two\nlines", "two lines"),
        ("   ", FilenameTemplate.fallbackName),
        ("a:b/c", "a-b-c"),
    ])
    func sanitizingMakesSafeNames(input: String, expected: String) {
        #expect(FilenameTemplate.sanitize(input) == expected)
    }

    @Test func longNamesAreCut() {
        let name = FilenameTemplate.sanitize(String(repeating: "x", count: 500))
        #expect(name.count == FilenameTemplate.maxLength)
    }

    @Test func takenNamesGetANumber() {
        let folder = URL(filePath: "/tmp/oriel-names", directoryHint: .isDirectory)
        let taken: Set = ["a.png", "a 2.png"]
        let url = FilenameTemplate.uniqueURL(in: folder, baseName: "a", fileExtension: "png") { taken.contains($0.lastPathComponent) }
        #expect(url.lastPathComponent == "a 3.png")
        let free = FilenameTemplate.uniqueURL(in: folder, baseName: "b", fileExtension: "png") { _ in false }
        #expect(free.lastPathComponent == "b.png")
    }

    @Test func formatsFollowFileExtensions() {
        #expect(CaptureImageFormat(fileExtension: "JPG") == .jpeg)
        #expect(CaptureImageFormat(fileExtension: "heif") == .heic)
        #expect(CaptureImageFormat(fileExtension: "gif") == nil)
        #expect(CaptureImageFormat.jpeg.fileExtension == "jpg")
    }
}
