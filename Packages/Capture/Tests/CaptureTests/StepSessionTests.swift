@testable import Capture
import CoreGraphics
import Foundation
import OrielCore
import Testing

/// Step Capture's state machine, the sequence's edits and the click marker (PLAN §17).
struct StepSessionTests {
    static func step(_ title: String = "", kind: CaptureKind = .area, width: Int = 400, height: Int = 300) -> Step {
        Step(
            id: UUID(),
            imageURL: URL(filePath: "/tmp/\(UUID().uuidString).png"),
            pixelWidth: width,
            pixelHeight: height,
            scale: 2,
            title: title,
            kind: kind,
            date: Date(timeIntervalSince1970: 1_793_000_000)
        )
    }

    @Test func aSessionCollectsStepsUntilFinished() throws {
        var session = StepSession()
        #expect(session.phase == .idle && session.commandTitle == "Start Step Capture")
        let early = session.append(Self.step())
        #expect(early == nil)
        let started = session.start(title: "Steps")
        let again = session.start(title: "Again")
        #expect(started && !again)
        #expect(session.commandTitle == "Finish Step Capture")
        #expect(!session.cancelNeedsConfirmation)
        let first = session.append(Self.step("Open Settings"))
        let second = session.append(Self.step("Click Capture"))
        #expect(first == 1 && second == 2)
        #expect(session.cancelNeedsConfirmation)
        let result = session.finish()
        let finished = try #require(result)
        #expect(finished.title == "Steps")
        #expect(finished.steps.map(\.title) == ["Open Settings", "Click Capture"])
        #expect(session.phase == .idle && session.sequence.isEmpty)
        let afterwards = session.finish()
        #expect(afterwards == nil)
    }

    @Test func finishingWithoutStepsGivesNothingAndCancelDiscards() {
        var session = StepSession()
        session.start(title: "Steps")
        let empty = session.finish()
        #expect(empty == nil)
        #expect(!session.isCapturing)

        session.start(title: "Steps")
        session.append(Self.step("One"))
        let discarded = session.cancel()
        #expect(discarded.map(\.title) == ["One"])
        #expect(!session.isCapturing && session.sequence.isEmpty)
    }

    @Test func aClickMarksOneStepOnlyWhileMarkingClicks() {
        var session = StepSession(marksClicks: true)
        session.recordClick(at: CGPoint(x: 5, y: 5))
        #expect(session.lastClick == nil) // not capturing yet
        session.start(title: "Steps")
        session.recordClick(at: CGPoint(x: 10, y: 20))
        session.recordClick(at: CGPoint(x: 30, y: 40))
        let taken = session.takeClick()
        let again = session.takeClick()
        #expect(taken == CGPoint(x: 30, y: 40))
        #expect(again == nil)
        session.marksClicks = false
        session.recordClick(at: CGPoint(x: 1, y: 1))
        let unmarked = session.takeClick()
        #expect(unmarked == nil)
    }

    @Test func stepsMoveLikeRowsDraggedInAList() {
        let steps = (1 ... 5).map { Self.step("\($0)") }
        var sequence = StepSequence(title: "Steps", steps: steps)
        sequence.move(fromOffsets: [0], toOffset: 3)
        #expect(sequence.steps.map(\.title) == ["2", "3", "1", "4", "5"])
        sequence.move(fromOffsets: [4], toOffset: 0)
        #expect(sequence.steps.map(\.title) == ["5", "2", "3", "1", "4"])
        sequence.move(fromOffsets: [0, 2], toOffset: 5)
        #expect(sequence.steps.map(\.title) == ["2", "1", "4", "5", "3"])
        sequence.move(fromOffsets: [1, 3], toOffset: 1)
        #expect(sequence.steps.map(\.title) == ["2", "1", "5", "4", "3"])
        sequence.move(fromOffsets: [9], toOffset: 0)
        #expect(sequence.steps.map(\.title) == ["2", "1", "5", "4", "3"])
    }

    @Test func editsNumberingAndHeadings() throws {
        let first = Self.step()
        let second = Self.step("Pick a folder")
        var sequence = StepSequence(title: "Steps", steps: [first, second])
        #expect(sequence.number(of: second.id) == 2)
        #expect(try #require(sequence.step(first.id)).heading(number: 1) == "Step 1")
        sequence.update(first.id) {
            $0.title = "  Open the menu "
            $0.note = "It is in the menu bar."
        }
        #expect(sequence.step(first.id)?.heading(number: 1) == "Open the menu")
        sequence.remove([first.id])
        #expect(sequence.number(of: second.id) == 1)
        #expect(sequence.number(of: first.id) == nil)
        sequence.update(first.id) { $0.title = "gone" }
        #expect(sequence.count == 1)
    }

    @Test func retakesUseTheModeTheStepCameFrom() {
        #expect(Self.step(kind: .window).retakeMode == .window)
        #expect(Self.step(kind: .scrolling).retakeMode == .scrolling)
        #expect(Self.step(kind: .imported).retakeMode == .area)
        #expect(Self.step(width: 400, height: 300).pointSize == CGSize(width: 200, height: 150))
    }

    @Test func theDefaultTitleIsLikeAScreenshotsName() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let date = try #require(ISO8601DateFormatter().date(from: "2026-10-29T14:02:30Z"))
        #expect(StepSequence.defaultTitle(at: date, calendar: calendar) == "Steps 2026-10-29 at 14.02")
    }

    @Test func clicksMapIntoTheImageWhenItShowsTheAreaOneToOne() {
        let area = CGRect(x: -100, y: 50, width: 400, height: 300)
        let size = CGSize(width: 800, height: 600)
        #expect(ClickMarker.pixelPoint(of: CGPoint(x: 0, y: 100), in: area, scale: 2, imageSize: size) == CGPoint(x: 200, y: 100))
        #expect(ClickMarker.pixelPoint(of: CGPoint(x: 400, y: 100), in: area, scale: 2, imageSize: size) == nil)
        // A window with its shadow is larger than its frame: no marker.
        #expect(ClickMarker.pixelPoint(of: CGPoint(x: 0, y: 100), in: area, scale: 2, imageSize: CGSize(width: 920, height: 720)) == nil)
        // A scrolling capture is taller than its area; its top is the area as it was.
        let tall = CGSize(width: 800, height: 6000)
        #expect(ClickMarker.pixelPoint(of: CGPoint(x: 299, y: 349), in: area, scale: 2, imageSize: tall) == CGPoint(x: 798, y: 598))
        #expect(ClickMarker.pixelPoint(of: .zero, in: .zero, scale: 2, imageSize: size) == nil)
    }
}
