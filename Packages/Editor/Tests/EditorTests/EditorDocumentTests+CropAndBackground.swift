import CoreGraphics
@testable import Editor
import Foundation
import Testing

extension EditorDocumentTests {
    /// The crop tool and the background tool: non-destructive, pixel-snapped, one undo step each.
    @MainActor
    struct CropAndBackground {
        private func makeSession() throws -> EditorSession {
            try EditorDocumentTests.makeSession()
        }

        @Test func cropIsNonDestructiveSnapsToPixelsAndUndoes() throws {
            let session = try makeSession()
            session.selectTool(.arrow)
            session.drag(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 60, y: 60))
            let arrow = try #require(session.document.items.first)
            let before = session.document

            session.selectTool(.crop)
            #expect(session.cropDraft == session.document.base.bounds)
            #expect(session.layout.canvasSize == session.document.base.pointSize)
            session.drag(from: CGPoint(x: 5.2, y: 5.2), to: CGPoint(x: 150.3, y: 100.7))
            session.confirm()

            #expect(session.tool == .select)
            // 2× image: crop edges land on half points.
            #expect(session.document.crop == CGRect(x: 5, y: 5, width: 145.5, height: 95.5))
            #expect(session.layout.canvasSize == CGSize(width: 145.5, height: 95.5))
            #expect(session.document.items == [arrow])
            #expect(session.document.base == before.base)
            session.undo()
            #expect(session.document == before)
        }

        @Test func escapeLeavesTheCropToolWithoutCroppingAndDeleteResetsTheDraft() throws {
            let session = try makeSession()
            session.selectTool(.crop)
            session.drag(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 100, y: 100))
            session.cancel()
            #expect(session.tool == .select)
            #expect(session.document.crop == nil)
            #expect(!session.canUndo)

            session.selectTool(.crop)
            session.drag(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 100, y: 100))
            session.deleteSelection()
            #expect(session.cropDraft == session.document.base.bounds)
            session.selectTool(.select)
            #expect(session.document.crop == nil)
        }

        @Test func cropHandlesAndMovesStayInsideTheImage() throws {
            let session = try makeSession()
            session.selectTool(.crop)
            session.drag(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 100, y: 100))
            session.drag(from: CGPoint(x: 75, y: 75), to: CGPoint(x: 500, y: 500))
            #expect(session.cropDraft == CGRect(x: 150, y: 100, width: 50, height: 50))
            session.drag(from: CGPoint(x: 150, y: 100), to: CGPoint(x: 120, y: -40))
            #expect(session.cropDraft == CGRect(x: 120, y: 0, width: 80, height: 150))
        }

        @Test func backgroundPresetsAddPaddingAndNoneRemovesThem() throws {
            let session = try makeSession()
            session.applyBackground(.ocean)
            let padding = BackgroundPreset.defaultPadding(for: session.document.base.pointSize)
            #expect(session.document.background == BackgroundPreset.ocean.style)
            #expect(session.document.canvasPadding == Padding(all: padding))
            #expect(session.layout.canvasSize == CGSize(width: 200 + padding * 2, height: 150 + padding * 2))

            for value in stride(from: 10.0, through: 60, by: 10) {
                session.setPadding(value)
            }
            session.setCornerRadius(20)
            session.setShadow(false)
            session.applyBackground(.graphite)
            #expect(session.document.background?.colors == BackgroundPreset.graphite.style?.colors)
            #expect(session.document.background?.cornerRadius == 20)
            #expect(session.document.background?.shadow == false)
            #expect(session.document.canvasPadding == Padding(all: 60))

            session.applyBackground(.none)
            #expect(session.document.background == nil && session.document.canvasPadding == nil)
            // Background, padding (one step for the slider drag), radius, shadow, preset, none.
            for _ in 0 ..< 6 {
                session.undo()
            }
            #expect(session.document.background == nil && session.document.canvasPadding == nil)
            #expect(!session.canUndo)
        }
    }
}
