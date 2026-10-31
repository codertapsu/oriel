import AppKit
import XCTest

/// An image opened with Oriel shows in the editor with its tools (PLAN §7.5, §14.3). The image is drawn for the test and
/// handed over as Finder would, through the workspace; nothing is saved.
final class EditorUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// A 640 × 400 px PNG with a few colored bars, in a temporary folder.
    @MainActor
    private func drawImage() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "oriel-ui-test-\(UUID().uuidString.prefix(8)).png")
        let bitmap = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: 640, pixelsHigh: 400, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 640, height: 400).fill()
        for (index, color) in [NSColor.systemRed, .systemGreen, .systemBlue].enumerated() {
            color.setFill()
            NSRect(x: 40 + index * 200, y: 80, width: 160, height: 240).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: url)
        return url
    }

    @MainActor
    func testAnOpenedImageShowsInTheEditorWithItsTools() throws {
        let app = OrielApp.launch(onboardingCompleted: true)
        defer { app.terminate() }
        let image = try drawImage()
        defer { try? FileManager.default.removeItem(at: image) }
        let opened = expectation(description: "the workspace handed the image to Oriel")
        NSWorkspace.shared
            .open([image], withApplicationAt: OrielApp.bundleURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                XCTAssertNil(error)
                opened.fulfill()
            }
        wait(for: [opened], timeout: 10)
        let name = image.deletingPathExtension().lastPathComponent
        let editor = app.windows.matching(NSPredicate(format: "title CONTAINS %@", name)).firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 10), "no editor window for \(name)")
        for tool in ["Select", "Arrow", "Rectangle", "Text", "Blur", "Crop"] {
            XCTAssertTrue(editor.buttons[tool].exists, "the \(tool) tool is missing")
        }
        editor.buttons["Rectangle"].click()
        editor.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(editor.waitForNonExistence(timeout: 5))
    }
}
