import CoreGraphics
@testable import Editor
import Foundation
import Testing

/// Numbered steps (PLAN §17): labels, sequences that restart or continue, renumbering after a delete, styles,
/// pointers and nudging.
@MainActor
struct StepTests {
    /// A 200×150 pt document at 2×, blue at width 6.
    private func makeSession() throws -> EditorSession {
        try EditorDocumentTests.makeSession()
    }

    private func steps(_ session: EditorSession) -> [Counter] {
        session.document.items.compactMap { item in
            if case let .counter(counter) = item {
                return counter
            }
            return nil
        }
    }

    // MARK: - Labels

    @Test(arguments: [
        (1, "A"), (2, "B"), (26, "Z"), (27, "AA"), (28, "AB"), (52, "AZ"), (53, "BA"), (702, "ZZ"), (703, "AAA"),
    ])
    func lettersCountOnAfterZLikeSpreadsheetColumns(_ number: Int, _ expected: String) {
        #expect(StepLabel.uppercase.text(for: number) == expected)
        #expect(StepLabel.lowercase.text(for: number) == expected.lowercased())
    }

    @Test(arguments: [
        (1, "I"), (4, "IV"), (9, "IX"), (14, "XIV"), (40, "XL"), (90, "XC"), (400, "CD"), (1994, "MCMXCIV"), (3999, "MMMCMXCIX"),
    ])
    func romanNumerals(_ number: Int, _ expected: String) {
        #expect(StepLabel.roman.text(for: number) == expected)
    }

    @Test func numbersWithoutALetterOrRomanFormAreWrittenAsDigits() {
        #expect(StepLabel.roman.text(for: 4000) == "4000")
        #expect(StepLabel.roman.text(for: 0) == "0")
        #expect(StepLabel.uppercase.text(for: 0) == "0")
        #expect(StepLabel.numbers.text(for: 42) == "42")
        #expect(StepLabel.allCases.map(\.title) == ["1 2 3", "A B C", "a b c", "I II III"])
    }

    // MARK: - Numbering

    @Test func restartingStartsANewSequenceAndDeletingRenumbersOnlyItsOwn() throws {
        let session = try makeSession()
        session.selectTool(.counter)
        for x in [20, 50, 80] {
            session.click(at: CGPoint(x: x, y: 20))
        }
        session.restartStepNumbering()
        #expect(session.nextStepLabel == "1")
        for x in [20, 50] {
            session.click(at: CGPoint(x: x, y: 100))
        }
        #expect(steps(session).map(\.number) == [1, 2, 3, 1, 2])
        #expect(steps(session).map(\.sequence) == [0, 0, 0, 1, 1])
        #expect(session.pendingStepStart == nil)
        #expect(session.nextStepLabel == "3")

        // Deleting the first sequence's second step renumbers that sequence only.
        session.selectTool(.select)
        session.click(at: CGPoint(x: 50, y: 20))
        session.deleteSelection()
        #expect(steps(session).map(\.number) == [1, 2, 1, 2])
        session.undo()
        #expect(steps(session).map(\.number) == [1, 2, 3, 1, 2])
    }

    @Test func aSequenceCanStartAtAnyNumberAndKeepsItsStartWhenItsFirstStepGoes() throws {
        let session = try makeSession()
        session.selectTool(.counter)
        session.restartStepNumbering(at: 5)
        #expect(session.nextStepLabel == "5")
        for x in [20, 50, 80] {
            session.click(at: CGPoint(x: x, y: 40))
        }
        #expect(steps(session).map(\.number) == [5, 6, 7])
        session.selectTool(.select)
        session.click(at: CGPoint(x: 20, y: 40))
        session.deleteSelection()
        #expect(steps(session).map(\.number) == [5, 6])
    }

    @Test func continuingDropsARestartNotUsedYet() throws {
        let session = try makeSession()
        session.selectTool(.counter)
        session.click(at: CGPoint(x: 20, y: 20))
        session.restartStepNumbering()
        session.continueStepNumbering()
        session.click(at: CGPoint(x: 60, y: 20))
        #expect(steps(session).map(\.number) == [1, 2])
        #expect(steps(session).map(\.sequence) == [0, 0])
    }

    @Test func theLabelStyleShowsInTheNextLabelAndOnNewSteps() throws {
        let session = try makeSession()
        session.selectTool(.counter)
        session.setStepLabel(.uppercase)
        for x in [20, 60, 100] {
            session.click(at: CGPoint(x: x, y: 20))
        }
        #expect(steps(session).map(\.text) == ["A", "B", "C"])
        #expect(session.nextStepLabel == "D")
    }

    // MARK: - Styles

    @Test func stylesApplyToTheSelectedStepsAsOneUndoStep() throws {
        let session = try makeSession()
        session.selectTool(.counter)
        session.click(at: CGPoint(x: 40, y: 40))
        session.click(at: CGPoint(x: 100, y: 40))
        session.selectAll()
        let before = session.document
        session.setStepShape(.square)
        session.setStepLabel(.roman)
        #expect(steps(session).allSatisfy { $0.shape == .square && $0.label == .roman })
        #expect(steps(session).map(\.text) == ["I", "II"])
        #expect(session.undoManager.undoActionName == "Step Style")
        session.undo()
        session.undo()
        #expect(session.document == before)
        // Nothing selected: only the next step changes.
        session.selection = []
        session.setStepShape(.circle)
        #expect(session.document == before)
        #expect(session.stepStyle.shape == .circle)
    }

    @Test func sizeAndColourComeFromTheToolbarAsForEveryTool() throws {
        let session = try makeSession()
        session.selectTool(.counter)
        session.setColor(.green)
        session.setStrokeWidth(10)
        session.click(at: CGPoint(x: 50, y: 50))
        let step = try #require(steps(session).first)
        #expect(step.color == .green && step.radius == ToolStyle.counterRadius(10))
    }

    // MARK: - Pointers

    @Test func withThePointerStyleADragGoesFromTheTargetToWhereTheStepSits() throws {
        let session = try makeSession()
        session.selectTool(.counter)
        session.setStepPointer(true)
        session.drag(from: CGPoint(x: 50, y: 60), to: CGPoint(x: 130, y: 30))
        let step = try #require(steps(session).first)
        #expect(step.center == CGPoint(x: 130, y: 30))
        #expect(step.pointer == CGPoint(x: 50, y: 60))
        #expect(step.showsPointer)
        #expect(session.undoManager.undoActionName == "Step")
    }

    @Test func aClickWithThePointerStylePutsTheStepBesideThePointTowardsTheMiddle() throws {
        let session = try makeSession()
        session.selectTool(.counter)
        session.setStepPointer(true)
        session.click(at: CGPoint(x: 20, y: 20))
        let step = try #require(steps(session).first)
        #expect(step.pointer == CGPoint(x: 20, y: 20))
        // Towards the middle (100, 75): right and down, a couple of radii away, inside the image.
        #expect(step.center.x > 20 && step.center.y > 20)
        let distance = hypot(step.center.x - 20, step.center.y - 20)
        #expect(abs(distance - step.radius * StepGeometry.defaultPointerDistance) < 0.001)
        #expect(session.document.base.bounds.insetBy(dx: step.radius, dy: step.radius).contains(step.center))
    }

    @Test func theTipOfASelectedStepCanBeDraggedAndTheWedgeIsHit() throws {
        let session = try makeSession()
        session.selectTool(.counter)
        session.setStepPointer(true)
        session.drag(from: CGPoint(x: 40, y: 100), to: CGPoint(x: 120, y: 100))
        var step = try #require(steps(session).first)
        let item = AnnotationItem.counter(step)
        #expect(item.handles == [.end])
        #expect(item.position(of: .end) == CGPoint(x: 40, y: 100))
        // Halfway along the wedge, beside the body.
        #expect(item.hitTest(CGPoint(x: 80, y: 100), tolerance: 1) == .precise)
        #expect(item.hitTest(CGPoint(x: 80, y: 120), tolerance: 1) == nil)
        #expect(item.bounds.contains(CGPoint(x: 40, y: 100)))
        // The step tool drags the tip of the selected step.
        session.drag(from: CGPoint(x: 40, y: 100), to: CGPoint(x: 60, y: 140))
        step = try #require(steps(session).first)
        #expect(step.pointer == CGPoint(x: 60, y: 140) && step.center == CGPoint(x: 120, y: 100))
        #expect(steps(session).count == 1)
    }

    @Test func thePointerCanBeTurnedOnAndOffForTheSelection() throws {
        let session = try makeSession()
        session.selectTool(.counter)
        session.click(at: CGPoint(x: 30, y: 30))
        #expect(steps(session).first?.pointer == nil)
        session.setStepPointer(true)
        let pointer = try #require(steps(session).first?.pointer)
        #expect(pointer.x > 30 && pointer.y > 30)
        session.setStepPointer(false)
        #expect(steps(session).first?.pointer == nil)
    }

    @Test func nudgingMovesTheStepAndItsPointerTogether() throws {
        let session = try makeSession()
        session.selectTool(.counter)
        session.setStepPointer(true)
        session.drag(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 100, y: 50))
        for _ in 0 ..< 3 {
            session.nudgeSelection(dx: 0, dy: 10)
        }
        let step = try #require(steps(session).first)
        #expect(step.center == CGPoint(x: 100, y: 80) && step.pointer == CGPoint(x: 50, y: 80))
        session.undo()
        #expect(steps(session).first?.center == CGPoint(x: 100, y: 50))
    }

    // MARK: - Drawing

    @Test func squareStepsFillTheirCornersAndPointersReachTheirTip() throws {
        let white = try #require(TestImages.make(width: 200, height: 100) { _, _ in RGBA8(red: 255, green: 255, blue: 255) })
        var document = EditorDocument(base: ImageRef(image: white, scale: 1))
        let green = RGBAColor(red: 0, green: 0.8, blue: 0)
        document.items = [
            .counter(Counter(center: CGPoint(x: 30, y: 50), number: 1, color: green, radius: 16, shape: .square)),
            .counter(Counter(center: CGPoint(x: 100, y: 50), number: 2, color: green, radius: 16)),
            .counter(Counter(center: CGPoint(x: 160, y: 30), number: 3, color: green, radius: 12, pointer: CGPoint(x: 185, y: 85))),
        ]
        let pixels = try PixelBuffer(#require(EditorRenderer.makeImage(document, scale: 1)))
        let greenPixel = RGBA8(red: 0, green: 204, blue: 0)
        // Near the square's corner: green; near the circle's corner: still white.
        #expect(pixels.pixel(17, 37).distance(to: greenPixel) <= 8)
        #expect(pixels.pixel(87, 37).distance(to: RGBA8(red: 255, green: 255, blue: 255)) <= 8)
        // Along the pointer, most of the way to its tip.
        #expect(pixels.pixel(180, 74).distance(to: greenPixel) <= 40)
    }
}
