import CoreGraphics
@testable import Editor
import Foundation
import OrielCore
import Testing

/// Every tool creates, edits and deletes items through `EditorSession`, the API the canvas view drives, and
/// undo/redo restores exact documents (PLAN §13.4).
@MainActor
struct EditorDocumentTests {
    static let defaults = EditorDefaults(color: .blue, strokeWidth: 6, exportFormat: .png, backgroundPreset: .none)

    /// A 200×150 pt document at 2×, blue at width 6.
    static func makeSession() throws -> EditorSession {
        try EditorSession(document: TestImages.document(width: 400, height: 300, scale: 2), defaults: defaults)
    }

    private func makeSession() throws -> EditorSession {
        try Self.makeSession()
    }

    // MARK: - Creating

    @Test(arguments: [EditorTool.arrow, .line, .rectangle, .ellipse, .pen, .highlighter, .blur, .pixelate, .spotlight])
    func everyDrawingToolCreatesOneItemInOneUndoStep(_ tool: EditorTool) throws {
        let session = try makeSession()
        session.selectTool(tool)
        let empty = session.document
        session.drag(from: CGPoint(x: 20, y: 20), to: CGPoint(x: 120, y: 80))

        let item = try #require(session.document.items.first)
        #expect(session.document.items.count == 1)
        #expect(item.kind == tool.drawsKind)
        #expect(session.selection == [item.id])
        if let color = item.color {
            #expect(color == .blue)
        }
        #expect(session.hasUnsavedChanges)

        session.undo()
        #expect(session.document == empty)
        #expect(session.selection.isEmpty)
        session.redo()
        #expect(session.document.items == [item])
    }

    @Test func shapesSpanTheDragAndUseTheToolStyle() throws {
        let session = try makeSession()
        session.selectTool(.arrow)
        session.drag(from: CGPoint(x: 10, y: 20), to: CGPoint(x: 110, y: 70))
        session.selectTool(.rectangle)
        session.drag(from: CGPoint(x: 150, y: 90), to: CGPoint(x: 50, y: 40))
        session.selectTool(.highlighter)
        session.drag(from: CGPoint(x: 10, y: 200), to: CGPoint(x: 190, y: 200))
        session.selectTool(.blur)
        session.drag(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 30, y: 30))

        guard case let .arrow(arrow) = session.document.items[0],
              case let .rect(box) = session.document.items[1],
              case let .highlighter(stroke) = session.document.items[2],
              case let .blur(region) = session.document.items[3]
        else {
            Issue.record("unexpected kinds: \(session.document.items.map(\.kind))")
            return
        }
        #expect(arrow.start == CGPoint(x: 10, y: 20) && arrow.end == CGPoint(x: 110, y: 70))
        #expect(arrow.width == 6)
        #expect(box.rect == CGRect(x: 50, y: 40, width: 100, height: 50))
        #expect(stroke.width == ToolStyle.highlighterWidth(6))
        #expect(stroke.points.first == CGPoint(x: 10, y: 200) && stroke.points.last == CGPoint(x: 190, y: 200))
        #expect(region.amount == ToolStyle.effectAmount(6))
    }

    @Test func shiftMakesSquaresAndSnapsLinesTo45Degrees() throws {
        let session = try makeSession()
        session.selectTool(.ellipse)
        session.drag(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 70, y: 30), modifiers: .shift)
        session.selectTool(.line)
        session.drag(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 150, y: 110), modifiers: .shift)

        guard case let .ellipse(box) = session.document.items[0], case let .line(line) = session.document.items[1] else {
            Issue.record("unexpected kinds")
            return
        }
        #expect(box.rect.width == 60 && box.rect.height == 60)
        #expect(abs(line.end.y - line.start.y) < 0.0001)
        #expect(abs(line.end.x - line.start.x - hypot(50, 10)) < 0.0001)
    }

    @Test(arguments: [EditorTool.arrow, .line, .rectangle, .ellipse, .blur, .pixelate, .spotlight])
    func aClickWithoutADragLeavesNothingAndNoUndoStep(_ tool: EditorTool) throws {
        let session = try makeSession()
        session.selectTool(tool)
        session.click(at: CGPoint(x: 50, y: 50))
        #expect(session.document.items.isEmpty)
        #expect(!session.canUndo)
        #expect(!session.hasUnsavedChanges)
    }

    @Test func aPenClickLeavesADot() throws {
        let session = try makeSession()
        session.selectTool(.pen)
        session.click(at: CGPoint(x: 50, y: 50))
        guard case let .freehand(path) = session.document.items.first else {
            Issue.record("no pen stroke")
            return
        }
        #expect(path.points == [CGPoint(x: 50, y: 50)])
    }

    // MARK: - Text

    @Test func textToolCreatesEditsAndRemovesEmptyLabels() throws {
        let session = try makeSession()
        let empty = session.document
        session.selectTool(.text)
        session.click(at: CGPoint(x: 40, y: 60))
        let id = try #require(session.editingTextID)
        #expect(session.renderOptions.hiddenItems == [id])
        session.updateEditingText("Hello")
        session.updateEditingText("Hello, world")
        session.endEditingText()

        guard case let .text(box) = session.document.item(withID: id) else {
            Issue.record("no label")
            return
        }
        #expect(box.text == "Hello, world")
        #expect(box.fontSize == ToolStyle.fontSize(6))
        #expect(box.color == .blue)
        #expect(session.editingTextID == nil)
        // Typing is one undo step, which removes the new label.
        session.undo()
        #expect(session.document == empty)
        session.redo()
        #expect(session.document.item(withID: id) == .text(box))

        // Clicking the label edits it again; emptying it deletes it.
        session.click(at: CGPoint(x: box.frame.midX, y: box.frame.midY))
        #expect(session.editingTextID == id)
        session.updateEditingText("   ")
        session.endEditingText()
        #expect(session.document.items.isEmpty)
        session.undo()
        #expect(session.document.item(withID: id) == .text(box))
    }

    @Test func anAbandonedNewLabelLeavesNoTrace() throws {
        let session = try makeSession()
        session.selectTool(.text)
        session.click(at: CGPoint(x: 40, y: 60))
        session.selectTool(.select)
        #expect(session.document.items.isEmpty)
        #expect(!session.canUndo)
    }

    @Test func doubleClickingALabelWithTheSelectToolEditsIt() throws {
        let session = try makeSession()
        session.selectTool(.text)
        session.click(at: CGPoint(x: 40, y: 60))
        session.updateEditingText("Note")
        session.selectTool(.select)
        let id = try #require(session.document.items.first?.id)
        let frame = try #require(session.document.items.first?.frame)
        session.click(at: CGPoint(x: frame.midX, y: frame.midY), clickCount: 2)
        #expect(session.editingTextID == id)
    }

    // MARK: - Steps

    @Test func stepsNumberThemselvesAndCloseGapsWhenOneIsDeleted() throws {
        let session = try makeSession()
        session.selectTool(.counter)
        for x in [40, 100, 160, 220] {
            session.click(at: CGPoint(x: x, y: 50))
        }
        func numbers() -> [Int] {
            session.document.items.compactMap { item in
                if case let .counter(counter) = item {
                    return counter.number
                }
                return nil
            }
        }
        #expect(numbers() == [1, 2, 3, 4])
        #expect(session.undoManager.undoActionName == "Step")

        session.selectTool(.select)
        session.click(at: CGPoint(x: 100, y: 50))
        session.deleteSelection()
        #expect(numbers() == [1, 2, 3])
        session.undo()
        #expect(numbers() == [1, 2, 3, 4])

        // Dragging an existing step with the step tool moves it instead of adding one.
        session.selectTool(.counter)
        session.drag(from: CGPoint(x: 40, y: 50), to: CGPoint(x: 40, y: 150))
        #expect(numbers() == [1, 2, 3, 4])
        #expect(session.undoManager.undoActionName == "Move")
        guard case let .counter(first) = session.document.items[0] else {
            Issue.record("not a step")
            return
        }
        #expect(first.center == CGPoint(x: 40, y: 150))
    }

    // MARK: - Selecting and editing

    @Test func selectMovesResizesAndDeletesItems() throws {
        let session = try makeSession()
        session.selectTool(.rectangle)
        session.drag(from: CGPoint(x: 20, y: 20), to: CGPoint(x: 120, y: 80))
        let id = try #require(session.document.items.first?.id)
        session.selectTool(.select)
        session.selection = []

        // Click the outline to select, drag to move.
        session.drag(from: CGPoint(x: 20, y: 50), to: CGPoint(x: 30, y: 60))
        #expect(session.selection == [id])
        #expect(session.document.items.first?.frame == CGRect(x: 30, y: 30, width: 100, height: 60))
        #expect(session.undoManager.undoActionName == "Move")

        // Drag the bottom-right handle.
        session.drag(from: CGPoint(x: 130, y: 90), to: CGPoint(x: 180, y: 140))
        #expect(session.document.items.first?.frame == CGRect(x: 30, y: 30, width: 150, height: 110))
        #expect(session.undoManager.undoActionName == "Resize")

        session.deleteSelection()
        #expect(session.document.items.isEmpty)
        session.undo()
        #expect(session.document.items.first?.frame == CGRect(x: 30, y: 30, width: 150, height: 110))
    }

    @Test func lineEndsHaveHandles() throws {
        let session = try makeSession()
        session.selectTool(.arrow)
        session.drag(from: CGPoint(x: 20, y: 20), to: CGPoint(x: 120, y: 20))
        // Still in the arrow tool, the selected arrow's end handle adjusts it instead of drawing a new arrow.
        session.drag(from: CGPoint(x: 120, y: 20), to: CGPoint(x: 120, y: 90))
        #expect(session.document.items.count == 1)
        guard case let .arrow(arrow) = session.document.items.first else {
            Issue.record("no arrow")
            return
        }
        #expect(arrow.start == CGPoint(x: 20, y: 20) && arrow.end == CGPoint(x: 120, y: 90))
    }

    @Test func marqueeSelectsWhatItTouchesAndShiftAddsToTheSelection() throws {
        let session = try makeSession()
        session.selectTool(.rectangle)
        session.drag(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 40, y: 40))
        session.drag(from: CGPoint(x: 100, y: 10), to: CGPoint(x: 140, y: 40))
        session.drag(from: CGPoint(x: 10, y: 150), to: CGPoint(x: 40, y: 190))
        let ids = session.document.items.map(\.id)
        session.selectTool(.select)
        session.selection = []

        session.drag(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 160, y: 60))
        #expect(session.selection == [ids[0], ids[1]])
        #expect(session.marquee == nil)
        session.click(at: CGPoint(x: 10, y: 170), modifiers: .shift)
        #expect(session.selection == Set(ids))
        session.click(at: CGPoint(x: 10, y: 25), modifiers: .shift)
        #expect(session.selection == [ids[1], ids[2]])
        session.click(at: CGPoint(x: 300, y: 250))
        #expect(session.selection.isEmpty)
        #expect(!session.document.items.isEmpty)
    }

    @Test func styleChangesOnDifferentSelectionsAreSeparateUndoSteps() throws {
        let session = try makeSession()
        session.selectTool(.line)
        session.drag(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 100, y: 10))
        session.drag(from: CGPoint(x: 10, y: 50), to: CGPoint(x: 100, y: 50))
        let ids = session.document.items.map(\.id)
        session.selection = [ids[0]]
        session.setStrokeWidth(10)
        session.selection = [ids[1]]
        session.setStrokeWidth(12)
        func widths() -> [CGFloat] {
            session.document.items.compactMap { item in
                if case let .line(line) = item {
                    return line.width
                }
                return nil
            }
        }
        #expect(widths() == [10, 12])
        session.undo()
        #expect(widths() == [10, 6])
        session.undo()
        #expect(widths() == [6, 6])
    }

    @Test func styleChangesApplyToTheSelectionAsOneUndoStep() throws {
        let session = try makeSession()
        session.selectTool(.line)
        session.drag(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 100, y: 10))
        let drawn = session.document
        // A colour-panel drag sends many changes; they coalesce.
        for color in [RGBAColor.red, .orange, .yellow, .green] {
            session.setColor(color)
        }
        session.setStrokeWidth(12)
        guard case let .line(line) = session.document.items.first else {
            Issue.record("no line")
            return
        }
        #expect(line.color == .green && line.width == 12)
        session.undo()
        guard case let .line(recoloured) = session.document.items.first else {
            Issue.record("no line")
            return
        }
        #expect(recoloured.color == .green && recoloured.width == 6)
        session.undo()
        #expect(session.document == drawn)
    }

    @Test func nudgesMoveTheSelectionAndCoalesce() throws {
        let session = try makeSession()
        session.selectTool(.counter)
        session.click(at: CGPoint(x: 50, y: 50))
        let placed = session.document
        for _ in 0 ..< 5 {
            session.nudgeSelection(dx: 1, dy: 0)
        }
        session.nudgeSelection(dx: 0, dy: 10)
        guard case let .counter(counter) = session.document.items.first else {
            Issue.record("no step")
            return
        }
        #expect(counter.center == CGPoint(x: 55, y: 60))
        session.undo()
        #expect(session.document == placed)
    }

    @Test func escapeCancelsADragAndPutsTheItemBack() throws {
        let session = try makeSession()
        session.selectTool(.rectangle)
        session.drag(from: CGPoint(x: 20, y: 20), to: CGPoint(x: 120, y: 80))
        let drawn = session.document
        session.selectTool(.select)
        session.beginGesture(at: CGPoint(x: 20, y: 50))
        session.continueGesture(to: CGPoint(x: 200, y: 200))
        session.cancel()
        #expect(session.document == drawn)
        #expect(session.undoManager.undoActionName == "Rectangle")
    }

    @Test func selectAllAndEscape() throws {
        let session = try makeSession()
        session.selectTool(.counter)
        session.click(at: CGPoint(x: 50, y: 50))
        session.click(at: CGPoint(x: 150, y: 50))
        session.selectAll()
        #expect(session.selection.count == 2)
        session.cancel()
        #expect(session.selection.isEmpty)
    }

    // MARK: - Undo history

    @Test func undoAndRedoWalkThroughExactSnapshots() throws {
        let session = try makeSession()
        var history = [session.document]
        func record() {
            history.append(session.document)
        }
        session.selectTool(.arrow)
        session.drag(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 90, y: 40))
        record()
        session.selectTool(.text)
        session.click(at: CGPoint(x: 30, y: 120))
        session.updateEditingText("Step one")
        session.endEditingText()
        record()
        session.selectTool(.counter)
        session.click(at: CGPoint(x: 150, y: 30))
        record()
        session.selectTool(.pixelate)
        session.drag(from: CGPoint(x: 100, y: 100), to: CGPoint(x: 180, y: 140))
        record()
        session.setStrokeWidth(10)
        record()
        session.selectTool(.select)
        session.selectAll()
        session.nudgeSelection(dx: 3, dy: 0)
        record()
        session.applyBackground(.mint)
        record()
        session.selectTool(.crop)
        session.drag(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 190, y: 145))
        session.selectTool(.select)
        record()
        #expect(session.document.crop == CGRect(x: 10, y: 10, width: 180, height: 135))

        #expect(Set(history.indices.dropFirst().map { history[$0] != history[$0 - 1] }) == [true])
        for index in history.indices.reversed().dropFirst() {
            session.undo()
            #expect(session.document == history[index], "undo to step \(index)")
        }
        #expect(!session.canUndo)
        for index in history.indices.dropFirst() {
            session.redo()
            #expect(session.document == history[index], "redo to step \(index)")
        }
        #expect(!session.canRedo)
    }

    @Test func aDragIsOneUndoStepHoweverManyEventsItHas() throws {
        let session = try makeSession()
        session.selectTool(.pen)
        session.drag(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 199, y: 149), steps: 300)
        guard case let .freehand(path) = session.document.items.first else {
            Issue.record("no stroke")
            return
        }
        #expect(path.points.count > 100)
        session.undo()
        #expect(session.document.items.isEmpty)
        #expect(!session.canUndo)
    }

    @Test func undoInTheMiddleOfADragCancelsTheDragFirst() throws {
        let session = try makeSession()
        session.selectTool(.rectangle)
        session.drag(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 50, y: 50))
        let first = session.document
        session.beginGesture(at: CGPoint(x: 100, y: 100))
        session.continueGesture(to: CGPoint(x: 150, y: 150))
        session.undo()
        #expect(session.document.items.isEmpty)
        #expect(session.gesture == nil)
        session.redo()
        #expect(session.document == first)
    }

    @Test func deliveringTheImageClearsTheUnsavedFlag() throws {
        let session = try makeSession()
        session.selectTool(.line)
        session.drag(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 90, y: 10))
        #expect(session.hasUnsavedChanges)
        #expect(session.flattenedImage() != nil)
        session.markDelivered()
        #expect(!session.hasUnsavedChanges)
    }
}
