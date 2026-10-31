@testable import Capture
import Testing

/// Stitching keeps pace with a scrolling capture (PLAN §7.3, §14.4 "stitching 20 frames"): each step already waits up to
/// about 250 ms for the page to settle, so matching and composing a frame must be a small part of that. Twenty frames
/// of a Retina window's region, 1,440 × 900 px, scrolled 300 px at a time: about 2 ms a frame optimized, as the app is
/// built, and about 220 ms in the unoptimized test build, whose vDSP loops are not inlined.
struct StitchingBudgetTests {
    #if DEBUG
        private static let perFrameBudget = Duration.milliseconds(500)
    #else
        private static let perFrameBudget = Duration.milliseconds(25)
    #endif

    @Test func twentyFramesStitchFarInsideTheirSteps() {
        let viewport = 900
        let step = 300
        let page = SyntheticPage(width: 1440, height: viewport + 19 * step, seed: 3)
        let clock = ContinuousClock()
        var stitcher = ScrollStitcher(first: page.viewport(at: 0, height: viewport))
        var frames: [Duration] = []
        for position in stride(from: step, through: 19 * step, by: step) {
            let frame = page.viewport(at: position, height: viewport)
            frames.append(clock.measure {
                #expect(stitcher.add(frame, expectedOffset: step) == .appended(offset: step))
            })
        }
        let finish = clock.measure { _ = stitcher.finish() }
        let sorted = frames.sorted()
        let average = frames.reduce(.zero, +) / frames.count
        print("stitching 20 frames of 1440×900 px: average \(average), slowest \(sorted.last ?? .zero), finish \(finish)")
        #expect(average < Self.perFrameBudget, "average \(average)")
    }
}
