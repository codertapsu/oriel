import CoreGraphics
@testable import Editor
import Foundation
import Testing

/// Simplify and Smart Move (PLAN §17) on synthetic screenshots: a light panel with dark "text" bars and a red object.
/// OCR is faked; the pixel work and the document changes are real.
@MainActor
struct SmartMoveTests {
    private let panel = RGBA8(red: 236, green: 238, blue: 242)
    private let ink = RGBA8(red: 30, green: 30, blue: 40)
    private let red = RGBA8(red: 220, green: 40, blue: 40)

    /// 200×120 pt at 1×: text-like strokes at (20…120, 20…32) and (20…90, 40…52), a red square at (150…180, 70…100).
    private func screenshot() throws -> EditorDocument {
        let image = try #require(TestImages.make(width: 200, height: 120) { x, y in
            let inFirstLine = (20 ..< 120).contains(x) && (22 ..< 30).contains(y) && x % 4 != 0
            let inSecondLine = (20 ..< 90).contains(x) && (42 ..< 50).contains(y) && x % 4 != 0
            if inFirstLine || inSecondLine {
                return ink
            }
            if (150 ..< 180).contains(x), (70 ..< 100).contains(y) {
                return red
            }
            return panel
        })
        return EditorDocument(base: ImageRef(image: image, scale: 1))
    }

    private func recognizer() -> FakeRecognizer {
        FakeRecognizer(lines: [
            ("First line of text", CGRect(x: 20, y: 20, width: 100, height: 12)),
            ("Second line", CGRect(x: 20, y: 40, width: 70, height: 12)),
        ], scale: 1)
    }

    @Test func liftingAnObjectKeepsItsPixelsAndFillsItsHoleWithTheBackground() throws {
        let document = try screenshot()
        let object = try #require(ObjectLifter.lift(CGRect(x: 148, y: 68, width: 34, height: 34), from: document.base, source: .object))
        #expect(object.layer.rect == object.patch.rect)
        #expect(object.layer.rect == CGRect(x: 147, y: 67, width: 36, height: 36))
        let layer = try PixelBuffer(object.layer.asset.image)
        #expect(layer.pixel(18, 18) == red)
        let patch = try PixelBuffer(object.patch.asset.image)
        #expect(patch.allPixels.allSatisfy { $0.distance(to: panel) <= 1 })
    }

    @Test func plainBackgroundIsNotWorthLifting() throws {
        let document = try screenshot()
        let empty = try #require(ObjectLifter.lift(CGRect(x: 130, y: 5, width: 60, height: 40), from: document.base, source: .region))
        #expect(!ObjectLifter.hasContent(empty))
        let square = try #require(ObjectLifter.lift(CGRect(x: 140, y: 60, width: 50, height: 50), from: document.base, source: .region))
        #expect(ObjectLifter.hasContent(square))
    }

    @Test func aMaskCutsOnlyTheObjectOut() throws {
        let document = try screenshot()
        // A 20×12 grid over the 200×120 image covering the red square's cells (150…180 × 70…100 → cells 15…17 × 7…9).
        var values = [Float](repeating: 0, count: 20 * 12)
        for y in 7 ... 9 {
            for x in 15 ... 17 {
                values[y * 20 + x] = 1
            }
        }
        let mask = MaskGrid(width: 20, height: 12, values: values)
        let box = try #require(mask.boundingBox(in: CGSize(width: 200, height: 120)))
        #expect(box == PixelRect(x: 150, y: 70, width: 30, height: 30))
        let object = try #require(ObjectLifter.lift(
            CGRect(x: 120, y: 40, width: 75, height: 75), mask: mask, from: document.base, source: .object
        ))
        // The hole starts at (119, 39); the square's middle (165, 85) is at (46, 46) in it.
        #expect(object.layer.rect.origin == CGPoint(x: 119, y: 39))
        let layer = try PixelBuffer(object.layer.asset.image)
        // Inside the mask the object is opaque; well outside it, transparent.
        #expect(layer.pixel(46, 46) == red)
        #expect(layer.pixel(0, 0).alpha == 0)
        let patch = try PixelBuffer(object.patch.asset.image)
        #expect(patch.pixel(0, 0).alpha == 0)
        #expect(patch.pixel(46, 46).alpha == 255 && patch.pixel(46, 46).distance(to: panel) <= 1)
    }

    @Test func simplifyTurnsLinesIntoBarsInTheirInkOnTheirBackground() async throws {
        let session = try EditorSession(document: screenshot())
        let tools = SmartTools(session: session, analyzer: SmartAnalyzer(recognizer: recognizer()))
        let before = session.document
        tools.findSimplification()
        try await waitUntil { tools.simplifyPhase == .ready }
        #expect(tools.simplifyPlan.bars.count == 2 && tools.simplifyPlan.patches.count == 2)
        let bar = try #require(tools.simplifyPlan.bars.first)
        #expect(bar.rect == SimplifyGeometry.bar(for: CGRect(x: 20, y: 20, width: 100, height: 12)))
        #expect(abs(bar.color.red - 30.0 / 255) < 0.03 && abs(bar.color.blue - 40.0 / 255) < 0.03)
        #expect(session.smartPreview.count == 2)
        tools.tonesDown = true
        tools.toneAmount = 0.5
        tools.applySimplification()
        #expect(session.document.items.map(\.kind) == [.patch, .patch, .bar, .bar])
        #expect(session.document.tone == 0.5)
        #expect(session.undoManager.undoActionName == "Simplify")
        // Above the bar, where a stroke was, the text is gone; the bar itself is dark.
        let rendered = try PixelBuffer(#require(EditorRenderer.makeImage(session.document, scale: 1)))
        #expect(rendered.pixel(41, 21).red > 200)
        #expect(rendered.pixel(60, Int(bar.rect.midY)).red < 80)
        // Patches belong to the image: clicks pass through them, and Select All leaves them out.
        session.selectTool(.select)
        #expect(session.item(at: CGPoint(x: 100, y: 21), tolerance: 0) == nil)
        session.selectAll()
        #expect(session.selection.count == 2)
        session.undo()
        #expect(session.document == before)
    }

    @Test func smartMoveLiftsTextBlocksAndObjectsThatCanThenBeMovedAndDeleted() async throws {
        let session = try EditorSession(document: screenshot())
        session.selectTool(.arrow)
        let tools = SmartTools(session: session, analyzer: SmartAnalyzer(recognizer: recognizer()))
        tools.findMovableObjects()
        try await waitUntil(timeout: .seconds(60)) { tools.movePhase == .ready }
        // The two lines are one block of text.
        #expect(tools.count(of: .text) == 1)
        tools.moveSources = [.text]
        #expect(session.smartPreview.count { $0.isIncluded } == 1)
        let before = session.document
        tools.applySmartMove()
        #expect(session.tool == .select)
        #expect(session.document.items.map(\.kind) == [.patch, .image])
        #expect(session.undoManager.undoActionName == "Smart Move")
        guard case let .image(layer) = session.document.items.last else {
            Issue.record("no layer")
            return
        }
        // Drag the block down by 50 points: its old place shows the panel, the new one the text.
        session.drag(from: CGPoint(x: layer.rect.midX, y: layer.rect.midY), to: CGPoint(x: layer.rect.midX, y: layer.rect.midY + 50))
        let moved = try PixelBuffer(#require(EditorRenderer.makeImage(session.document, scale: 1)))
        #expect(moved.pixel(41, 25).distance(to: panel) <= 2)
        #expect(moved.pixel(41, 75).distance(to: ink) <= 2)
        // Deleting the block leaves the filled hole, not the original text.
        session.deleteSelection()
        let deleted = try PixelBuffer(#require(EditorRenderer.makeImage(session.document, scale: 1)))
        #expect(deleted.pixel(41, 25).distance(to: panel) <= 2)
        #expect(session.document.items.map(\.kind) == [.patch])
        session.undo()
        session.undo()
        session.undo()
        #expect(session.document == before)
    }

    @Test func smartMoveWithoutTextRecognitionStillLooksForObjects() async throws {
        let session = try EditorSession(document: screenshot())
        let tools = SmartTools(session: session, analyzer: SmartAnalyzer(recognizer: nil))
        tools.findMovableObjects()
        try await waitUntil(timeout: .seconds(60)) { tools.movePhase != .working }
        #expect(tools.movePhase == .ready)
        #expect(tools.count(of: .text) == 0)
    }

    /// A region that takes in part of a block of text is left out: lifting both would leave a copy of the text behind.
    @Test func liftedObjectsNeverOverlap() {
        let text = CGRect(x: 0, y: 0, width: 100, height: 20)
        #expect(SmartAnalyzer.overlapsAny(CGRect(x: 50, y: 0, width: 200, height: 200), [text]))
        #expect(SmartAnalyzer.overlapsAny(CGRect(x: 10, y: 5, width: 20, height: 10), [text]))
        #expect(!SmartAnalyzer.overlapsAny(CGRect(x: 99, y: 19, width: 50, height: 50), [text]))
        #expect(!SmartAnalyzer.overlapsAny(CGRect(x: 200, y: 0, width: 10, height: 10), [text]))
        #expect(!SmartAnalyzer.overlapsAny(text, []))
    }

    @Test func visionDetectionRunsOnDeviceWithoutFailing() throws {
        let image = try #require(TestImages.make(width: 320, height: 240) { x, y in
            hypot(Double(x - 160), Double(y - 120)) < 60 ? RGBA8(red: 250, green: 120, blue: 0) : RGBA8(red: 30, green: 60, blue: 90)
        })
        let detections = ObjectDetector.detect(in: image)
        for grid in detections.objects {
            #expect(grid.width > 0 && grid.height > 0)
        }
        for region in detections.regions {
            #expect(CGRect(x: 0, y: 0, width: 320, height: 240).insetBy(dx: -1, dy: -1).contains(region))
        }
    }
}
