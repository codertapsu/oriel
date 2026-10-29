import CoreGraphics
import Testing
@testable import WindowTiling

/// Cycling, Next and Previous Display, the size steps and Restore, as plans.
struct TilingPlannerTests {
    private static let window = CGRect(x: 200, y: 150, width: 900, height: 600)

    private func plan(
        _ action: TilingAction,
        window: CGRect = Self.window,
        record: TileRecord? = nil,
        restoreFrame: CGRect? = nil,
        displays: [DisplayGeometry] = [Displays.laptop],
        options: TilingOptions = TilingOptions()
    ) -> TilingPlan {
        TilingPlanner.plan(action, window: window, record: record, restoreFrame: restoreFrame, displays: displays, options: options)
    }

    /// A `.place` plan, spelled out.
    private struct Placed {
        let frame: CGRect
        let display: Int
        let action: TilingAction
        let step: Int
    }

    private func placed(_ plan: TilingPlan) -> Placed? {
        guard case let .place(placement, display, action, step) = plan else { return nil }
        return Placed(frame: placement.frame, display: display, action: action, step: step)
    }

    /// The record a window has right after `action` placed it at `frame`.
    private func record(_ action: TilingAction, step: Int = 0, at frame: CGRect) -> TileRecord {
        TileRecord(restoreFrame: Self.window, action: action, step: step, target: frame, result: frame)
    }

    // MARK: Cycling

    @Test func pressingAHalfAgainCyclesHalfTwoThirdsAndAThird() throws {
        let first = try #require(placed(plan(.leftHalf)))
        #expect(first.frame.width == 756 && first.step == 0)
        let second = try #require(placed(plan(.leftHalf, window: first.frame, record: record(.leftHalf, at: first.frame))))
        #expect(second.frame == CGRect(x: 0, y: 33, width: 1008, height: 879) && second.step == 1)
        let third = try #require(placed(plan(.leftHalf, window: second.frame, record: record(.leftHalf, step: 1, at: second.frame))))
        #expect(third.frame.width == 504 && third.step == 2)
        let fourth = try #require(placed(plan(.leftHalf, window: third.frame, record: record(.leftHalf, step: 2, at: third.frame))))
        #expect(fourth.frame.width == 756 && fourth.step == 0)
    }

    @Test(arguments: [TilingAction.rightHalf, .topHalf, .bottomHalf])
    func everyHalfCycles(_ action: TilingAction) throws {
        let first = try #require(placed(plan(action)))
        let second = try #require(placed(plan(action, window: first.frame, record: record(action, at: first.frame))))
        #expect(second.step == 1)
        #expect(second.frame.width * second.frame.height > first.frame.width * first.frame.height)
    }

    @Test func withCyclingOffAHalfStaysAHalf() throws {
        let options = TilingOptions(cyclesSizes: false)
        let first = try #require(placed(plan(.leftHalf, options: options)))
        let again = try #require(placed(plan(.leftHalf, window: first.frame, record: record(.leftHalf, at: first.frame), options: options)))
        #expect(again.frame == first.frame && again.step == 0)
    }

    @Test func anotherActionStartsAgainAtAHalf() throws {
        let left = try #require(placed(plan(.leftHalf)))
        let right = try #require(placed(plan(.rightHalf, window: left.frame, record: record(.leftHalf, step: 1, at: left.frame))))
        #expect(right.step == 0 && right.frame.width == 756)
    }

    @Test func aWindowAlreadyAtTheHalfGoesStraightToTwoThirds() throws {
        // No record (arranged before Oriel started, or by hand), but exactly the ½ layout.
        let half = CGRect(x: 0, y: 33, width: 756, height: 879)
        let next = try #require(placed(plan(.leftHalf, window: half)))
        #expect(next.step == 1 && next.frame.width == 1008)
    }

    @Test func quartersThirdsAndMaximizeDoNotCycle() throws {
        for action in [TilingAction.topLeft, .firstThird, .firstTwoThirds, .maximize] {
            let first = try #require(placed(plan(action)))
            let again = try #require(placed(plan(action, window: first.frame, record: record(action, at: first.frame))))
            #expect(again.frame == first.frame && again.step == 0, "\(action)")
        }
    }

    // MARK: Displays

    @Test func nextDisplayTakesATiledWindowsLayoutAlong() throws {
        let laptopHalf = CGRect(x: 0, y: 33, width: 1008, height: 879)
        let moved = try #require(placed(plan(
            .nextDisplay, window: laptopHalf, record: record(.leftHalf, step: 1, at: laptopHalf), displays: Displays.row
        )))
        // The left two thirds of the display on the right, and still "left half, step 1" for the next press.
        #expect(moved.display == 2 && moved.action == .leftHalf && moved.step == 1)
        #expect(moved.frame == CGRect(x: 1512, y: 25, width: 1707, height: 1415))
    }

    @Test func nextDisplayKeepsAnUntiledWindowsSizeAndPlace() throws {
        // 200 of the 612 free points to the left: the same share of the free space on the right display.
        let moved = try #require(placed(plan(.nextDisplay, displays: Displays.row)))
        #expect(moved.display == 2 && moved.action == .nextDisplay)
        #expect(moved.frame.size == Self.window.size)
        #expect(moved.frame.minX == (1512 + 200.0 / 612 * (2560 - 900)).rounded())
        #expect(moved.frame.minY == (25 + 117.0 / 279 * (1415 - 600)).rounded())
    }

    @Test func aWindowAgainstAnEdgeStaysAgainstIt() throws {
        let rightEdge = CGRect(x: 612, y: 33, width: 900, height: 600)
        let moved = try #require(placed(plan(.previousDisplay, window: rightEdge, displays: Displays.row)))
        // Previous of the laptop is the display on the left: still against the right edge and the top.
        #expect(moved.display == 1)
        #expect(moved.frame == CGRect(x: -900, y: -73, width: 900, height: 600))
    }

    @Test func aWindowTooLargeForTheOtherDisplayShrinksToFit() throws {
        let big = CGRect(x: 1600, y: 25, width: 2400, height: 1400)
        let moved = try #require(placed(plan(.nextDisplay, window: big, displays: Displays.row)))
        #expect(moved.display == 1)
        #expect(moved.frame.width == 1920 && moved.frame.height == 1055)
        #expect(Displays.left.visibleFrame.contains(moved.frame))
    }

    @Test func displayMovesNeedASecondDisplay() {
        #expect(plan(.nextDisplay) == .nothing)
        #expect(plan(.previousDisplay) == .nothing)
    }

    @Test func gapsCarryOverToTheOtherDisplay() throws {
        let options = TilingOptions(gap: 10)
        let laptopMax = CGRect(x: 10, y: 43, width: 1492, height: 859)
        let moved = try #require(placed(plan(
            .nextDisplay, window: laptopMax, record: record(.maximize, at: laptopMax), displays: Displays.row, options: options
        )))
        #expect(moved.frame == CGRect(x: 1522, y: 35, width: 2540, height: 1395))
    }

    // MARK: Size steps

    @Test func makeLargerGrowsAroundTheCenterInStepsOfTheScreen() throws {
        // 5 % of 1512 × 879: 76 × 44 points.
        let larger = try #require(placed(plan(.larger)))
        #expect(larger.frame == CGRect(x: 162, y: 128, width: 976, height: 644))
        let smaller = try #require(placed(plan(.smaller)))
        #expect(smaller.frame == CGRect(x: 238, y: 172, width: 824, height: 556))
    }

    @Test func anEdgeTheWindowSharesWithTheScreenStays() throws {
        let leftHalf = CGRect(x: 0, y: 33, width: 756, height: 879)
        let larger = try #require(placed(plan(.larger, window: leftHalf)))
        // Full height already: only wider, away from the left edge.
        #expect(larger.frame == CGRect(x: 0, y: 33, width: 832, height: 879))
        let rightHalf = CGRect(x: 756, y: 33, width: 756, height: 879)
        let smaller = try #require(placed(plan(.smaller, window: rightHalf)))
        // Both vertical edges are shared, so it shrinks evenly there; the right edge stays.
        #expect(smaller.frame == CGRect(x: 832, y: 55, width: 680, height: 835))
    }

    @Test func sizeStepsStopAtTheScreenAndAtAQuarterOfIt() {
        let maximized = CGRect(x: 0, y: 33, width: 1512, height: 879)
        #expect(plan(.larger, window: maximized) == .nothing)
        let tiny = CGRect(x: 600, y: 300, width: 378, height: 220)
        #expect(plan(.smaller, window: tiny) == .nothing)
        let nearlyTiny = CGRect(x: 600, y: 300, width: 400, height: 240)
        guard case let .place(placement, _, _, _) = plan(.smaller, window: nearlyTiny) else {
            Issue.record("expected a plan")
            return
        }
        #expect(placement.frame.size == CGSize(width: 378, height: 220))
    }

    // MARK: Restore

    @Test func restoreGoesBackToTheRecordedFrame() {
        let original = CGRect(x: 300, y: 200, width: 700, height: 500)
        let plan = plan(.restore, window: CGRect(x: 0, y: 33, width: 756, height: 879), restoreFrame: original)
        #expect(plan == .restore(TilePlacement(frame: original, horizontal: .start, vertical: .start), display: 0))
        #expect(self.plan(.restore) == .nothing)
    }

    @Test func restoreToAnUnpluggedDisplayLandsOnTheCurrentOne() {
        // The window was on a display at x = 4072 that is gone now.
        let gone = CGRect(x: 4500, y: 200, width: 1800, height: 1000)
        let plan = plan(.restore, window: Self.window, restoreFrame: gone)
        let expected = CGRect(x: 0, y: 33, width: 1512, height: 879)
        #expect(plan == .restore(TilePlacement(frame: expected, horizontal: .start, vertical: .start), display: 0))
    }

    @Test func restoreToAnotherDisplayThatIsStillThereGoesThere() {
        let onLeft = CGRect(x: -1500, y: 0, width: 800, height: 600)
        let plan = plan(.restore, window: Self.window, restoreFrame: onLeft, displays: Displays.row)
        #expect(plan == .restore(TilePlacement(frame: onLeft, horizontal: .start, vertical: .start), display: 1))
    }
}
