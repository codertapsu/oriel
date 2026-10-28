@testable import Recording
import Testing

struct GIFFramePlanTests {
    @Test(arguments: [(2.0, 10, 20), (2.05, 10, 21), (1.5, 12, 18), (1.0, 15, 15), (0.0, 10, 1), (0.04, 15, 1)])
    func samplesOneFramePerIntervalStartedBeforeTheEnd(duration: Double, frameRate: Int, frames: Int) {
        let plan = GIFFramePlan(duration: duration, frameRate: frameRate, sourceWidth: 1280, sourceHeight: 720, maxWidth: 800)
        #expect(plan.times.count == frames)
        #expect(plan.delays.count == frames)
        #expect(plan.times.first == 0)
    }

    @Test func delaysAreWholeCentisecondsThatAddUpToTheDuration() {
        let plan = GIFFramePlan(duration: 3.0, frameRate: 12, sourceWidth: 1280, sourceHeight: 720, maxWidth: 800)
        for delay in plan.delays {
            #expect(abs(delay * 100 - (delay * 100).rounded()) < 0.0001)
        }
        #expect(Set(plan.delays) == [0.08, 0.09])
        #expect(abs(plan.delays.reduce(0, +) - 3.0) < 0.0001)
    }

    @Test func theLastFrameLastsUntilTheEnd() {
        let plan = GIFFramePlan(duration: 2.05, frameRate: 10, sourceWidth: 640, sourceHeight: 480, maxWidth: 800)
        #expect(plan.delays.last == 0.05)
        #expect(abs(plan.delays.reduce(0, +) - 2.05) < 0.0001)
    }

    @Test func scalesDownToTheMaximumWidthKeepingTheAspectRatio() {
        let wide = GIFFramePlan(duration: 1, frameRate: 10, sourceWidth: 3024, sourceHeight: 1964, maxWidth: 800)
        #expect(wide.width == 800)
        #expect(wide.height == 520)
        let narrow = GIFFramePlan(duration: 1, frameRate: 10, sourceWidth: 400, sourceHeight: 300, maxWidth: 800)
        #expect(narrow.width == 400)
        #expect(narrow.height == 300)
    }

    @Test func capsVeryLongMovies() {
        let plan = GIFFramePlan(duration: 3600, frameRate: 10, sourceWidth: 1280, sourceHeight: 720, maxWidth: 800)
        #expect(plan.times.count == GIFFramePlan.maximumFrameCount)
        #expect(plan.delays.last == 0.1)
    }
}
