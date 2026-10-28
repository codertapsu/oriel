import Foundation
@testable import Recording
import Testing

struct SegmentLedgerTests {
    private let folder = URL(filePath: "/tmp/oriel-ledger", directoryHint: .isDirectory)
    private let start = ContinuousClock.now

    private func at(_ seconds: Double) -> ContinuousClock.Instant {
        start + .milliseconds(Int(seconds * 1000))
    }

    @Test func numbersSegmentsAndNamesTheirFiles() throws {
        var ledger = SegmentLedger(directory: folder)
        let opened = ledger.beginSegment(at: at(0))
        let first = try #require(opened)
        #expect(first.index == 0)
        #expect(first.url == folder.appending(path: "segment-000.mp4"))
        #expect(first.phase == .pending)
        ledger.endSegment(at: at(1))
        let reopened = ledger.beginSegment(at: at(2))
        let second = try #require(reopened)
        #expect(second.index == 1)
        #expect(second.url.lastPathComponent == "segment-001.mp4")
        #expect(SegmentLedger.fileName(for: 12) == "segment-012.mp4")
    }

    @Test func opensOnlyOneSegmentAtATime() {
        var ledger = SegmentLedger(directory: folder)
        #expect(ledger.beginSegment(at: at(0)) != nil)
        #expect(ledger.beginSegment(at: at(1)) == nil)
        #expect(ledger.segments.count == 1)
        #expect(ledger.endSegment(at: at(2)) != nil)
        #expect(ledger.endSegment(at: at(3)) == nil)
    }

    @Test func elapsedTimeLeavesOutPauses() {
        var ledger = SegmentLedger(directory: folder)
        _ = ledger.beginSegment(at: at(0))
        #expect(ledger.elapsed(at: at(2.5)) == .milliseconds(2500))
        ledger.endSegment(at: at(3))
        // Paused from 3 s to 10 s.
        #expect(ledger.elapsed(at: at(9)) == .seconds(3))
        _ = ledger.beginSegment(at: at(10))
        #expect(ledger.elapsed(at: at(11.5)) == .milliseconds(4500))
        ledger.endSegment(at: at(12))
        #expect(ledger.elapsed(at: at(60)) == .seconds(5))
    }

    @Test func settlesOnlyWhenEveryOutputHasReportedBack() {
        var ledger = SegmentLedger(directory: folder)
        _ = ledger.beginSegment(at: at(0))
        ledger.markStarted(0)
        #expect(ledger.segments[0].phase == .recording)
        #expect(!ledger.isSettled)
        ledger.endSegment(at: at(1))
        #expect(ledger.segments[0].phase == .finalizing)
        _ = ledger.beginSegment(at: at(2))
        ledger.markFinished(0)
        #expect(!ledger.isSettled)
        ledger.endSegment(at: at(3))
        ledger.markFinished(1)
        #expect(ledger.isSettled)
        #expect(ledger.finishedURLs.map(\.lastPathComponent) == ["segment-000.mp4", "segment-001.mp4"])
    }

    @Test func failedSegmentsAreLeftOutOfTheJoin() {
        var ledger = SegmentLedger(directory: folder)
        for index in 0 ..< 3 {
            _ = ledger.beginSegment(at: at(Double(index * 2)))
            ledger.endSegment(at: at(Double(index * 2 + 1)))
        }
        ledger.markFinished(0)
        ledger.markFailed(1, reason: "disk full")
        ledger.markFinished(2)
        #expect(ledger.isSettled)
        #expect(ledger.segments[1].phase == .failed("disk full"))
        #expect(ledger.finishedURLs.map(\.lastPathComponent) == ["segment-000.mp4", "segment-002.mp4"])
    }

    @Test func aSegmentClosedBeforeItStartedStillFinishes() {
        var ledger = SegmentLedger(directory: folder)
        _ = ledger.beginSegment(at: at(0))
        ledger.endSegment(at: at(0.1))
        ledger.markStarted(0)
        #expect(ledger.segments[0].phase == .finalizing)
        ledger.markFinished(0)
        #expect(ledger.segments[0].phase == .finished)
    }

    @Test func aSettledSegmentDoesNotChangeAgain() {
        var ledger = SegmentLedger(directory: folder)
        _ = ledger.beginSegment(at: at(0))
        ledger.markFailed(0, reason: "lost")
        ledger.markFinished(0)
        ledger.markStarted(0)
        #expect(ledger.segments[0].phase == .failed("lost"))
        ledger.endSegment(at: at(1))
        #expect(ledger.segments[0].phase == .failed("lost"))
        #expect(ledger.segments[0].closedAt != nil)
    }

    @Test func aTimeoutKeepsSegmentsWhoseFilesExist() {
        var ledger = SegmentLedger(directory: folder)
        for index in 0 ..< 2 {
            _ = ledger.beginSegment(at: at(Double(index * 2)))
            ledger.endSegment(at: at(Double(index * 2 + 1)))
        }
        ledger.settleRemaining { $0.lastPathComponent == "segment-001.mp4" }
        #expect(ledger.isSettled)
        #expect(ledger.finishedURLs.map(\.lastPathComponent) == ["segment-001.mp4"])
    }

    @Test func closingBeforeOpeningCountsAsNoTime() {
        var ledger = SegmentLedger(directory: folder)
        _ = ledger.beginSegment(at: at(5))
        ledger.endSegment(at: at(4))
        #expect(ledger.elapsed(at: at(10)) == .zero)
    }

    @Test func ignoresUnknownSegments() {
        var ledger = SegmentLedger(directory: folder)
        ledger.markStarted(3)
        ledger.markFinished(-1)
        ledger.markFailed(7, reason: "")
        #expect(ledger.segments.isEmpty)
        #expect(ledger.isSettled)
        #expect(ledger.openSegment == nil)
    }
}
