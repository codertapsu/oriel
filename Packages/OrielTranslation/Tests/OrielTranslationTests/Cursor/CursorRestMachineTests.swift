import CoreGraphics
@testable import OrielTranslation
import Testing

/// Translate Under Cursor's debounce and dedupe, on a clock the test sets: instants are passed in, so nothing waits.
struct CursorRestMachineTests {
    private let start = ContinuousClock.now
    private let point = CGPoint(x: 100, y: 100)
    private let region = CGRect(x: 80, y: 90, width: 300, height: 40)

    private func at(_ milliseconds: Int) -> ContinuousClock.Instant {
        start + .milliseconds(milliseconds)
    }

    private func result(_ text: String) -> CursorTranslation {
        CursorTranslation(text: text, translation: "ja:\(text)", sourceLanguage: "en", targetLanguage: "ja", providerName: "Fake")
    }

    /// Moves to `point`, rests, and reads `text` there; returns the job that read it.
    private func rest(
        _ machine: inout CursorRestMachine,
        on text: String,
        at time: Int,
        point: CGPoint? = nil
    ) -> [CursorRestMachine.Effect] {
        _ = machine.pointerMoved(to: point ?? self.point, at: at(time))
        let read = machine.wake(at: at(time + 400))
        guard case let .read(job, _)? = read.last else { return read }
        return machine.recognized(CursorRecognition(text: text, region: region), job: job, context: "ctx")
    }

    @Test func readsOnlyOnceThePointerHasRestedForTheDelay() {
        var machine = CursorRestMachine()
        #expect(machine.pointerMoved(to: point, at: at(0)) == [.scheduleWake(at: at(400))])
        // Moving again does not ask for another wake-up; the one asked for is moved on when it comes.
        #expect(machine.pointerMoved(to: CGPoint(x: 140, y: 100), at: at(300)).isEmpty)
        #expect(machine.wake(at: at(400)) == [.scheduleWake(at: at(700))])
        #expect(machine.pointerMoved(to: CGPoint(x: 180, y: 100), at: at(650)).isEmpty)
        #expect(machine.wake(at: at(700)) == [.scheduleWake(at: at(1050))])
        #expect(machine.wake(at: at(1050)) == [.read(job: 1, point: CGPoint(x: 180, y: 100))])
        // At rest nothing more happens.
        #expect(machine.wake(at: at(2000)).isEmpty)
    }

    @Test func trembleOfAFewPointsIsNotAMovement() {
        var machine = CursorRestMachine()
        _ = machine.pointerMoved(to: point, at: at(0))
        _ = machine.wake(at: at(400))
        _ = machine.recognized(nil, job: 1, context: "ctx")
        #expect(machine.pointerMoved(to: CGPoint(x: 101.5, y: 101), at: at(500)).isEmpty)
        #expect(machine.pointerMoved(to: CGPoint(x: 110, y: 100), at: at(600)) == [.scheduleWake(at: at(1000))])
    }

    @Test func translatesNewTextAndShowsItWhenItArrives() {
        var machine = CursorRestMachine()
        let key = CursorRestMachine.key("Hello", context: "ctx")
        let effects = rest(&machine, on: "Hello", at: 0)
        #expect(effects == [.showPending(region: region, point: point), .translate(key: key, text: "Hello")])
        #expect(machine.translated(result("Hello"), key: key) == [.show(result("Hello"), region: region, point: point)])
    }

    @Test func theSameTextIsNeverTranslatedTwice() {
        var machine = CursorRestMachine()
        let key = CursorRestMachine.key("Hello", context: "ctx")
        _ = rest(&machine, on: "Hello", at: 0)
        _ = machine.translated(result("Hello"), key: key)
        // Away and back: the cache answers.
        _ = machine.pointerMoved(to: CGPoint(x: 600, y: 600), at: at(1000))
        let again = rest(&machine, on: "Hello", at: 2000)
        #expect(again == [.show(result("Hello"), region: region, point: point)])
        // In another context (a different provider, say) it is translated again.
        _ = machine.pointerMoved(to: CGPoint(x: 600, y: 600), at: at(3000))
        _ = machine.wake(at: at(3400))
        _ = machine.pointerMoved(to: point, at: at(3500))
        let read = machine.wake(at: at(3900))
        guard case let .read(job, _)? = read.last else {
            Issue.record("expected a read")
            return
        }
        let other = machine.recognized(CursorRecognition(text: "Hello", region: region), job: job, context: "other")
        #expect(other.contains(.translate(key: CursorRestMachine.key("Hello", context: "other"), text: "Hello")))
    }

    @Test func textStillOnItsWayIsNotSentAgain() {
        var machine = CursorRestMachine()
        let key = CursorRestMachine.key("Hello", context: "ctx")
        _ = rest(&machine, on: "Hello", at: 0)
        // The pointer leaves before the translation arrives, and comes back.
        #expect(machine.pointerMoved(to: CGPoint(x: 600, y: 600), at: at(500)) == [.hideTooltip, .cancelRead, .scheduleWake(at: at(900))])
        _ = machine.wake(at: at(900))
        let back = rest(&machine, on: "Hello", at: 1000)
        #expect(back == [.showPending(region: region, point: point)])
        #expect(machine.translated(result("Hello"), key: key) == [.show(result("Hello"), region: region, point: point)])
    }

    @Test func theTooltipStaysWhileThePointerIsOnItsText() {
        var machine = CursorRestMachine()
        let key = CursorRestMachine.key("Hello", context: "ctx")
        _ = rest(&machine, on: "Hello", at: 0)
        _ = machine.translated(result("Hello"), key: key)
        #expect(machine.pointerMoved(to: CGPoint(x: 300, y: 120), at: at(600)).isEmpty)
        #expect(machine.pointerMoved(to: CGPoint(x: 385, y: 135), at: at(700)).isEmpty) // within the margin
        #expect(machine.pointerMoved(to: CGPoint(x: 300, y: 200), at: at(800)) == [.hideTooltip, .scheduleWake(at: at(1200))])
    }

    @Test func scrollingReadsTheSameSpotAgain() {
        var machine = CursorRestMachine()
        let key = CursorRestMachine.key("Hello", context: "ctx")
        _ = rest(&machine, on: "Hello", at: 0)
        _ = machine.translated(result("Hello"), key: key)
        #expect(machine.contentChanged(at: at(1000)) == [.hideTooltip, .scheduleWake(at: at(1400))])
        #expect(machine.wake(at: at(1400)) == [.read(job: 2, point: point)])
    }

    @Test func clicksAndKeysDismissWithoutReadingAgain() {
        var machine = CursorRestMachine()
        let key = CursorRestMachine.key("Hello", context: "ctx")
        _ = rest(&machine, on: "Hello", at: 0)
        _ = machine.translated(result("Hello"), key: key)
        #expect(machine.dismissed() == [.hideTooltip])
        // Typing on: nothing to hide, nothing read, however long the pause.
        #expect(machine.dismissed().isEmpty)
        #expect(machine.wake(at: at(5000)).isEmpty)
        // A tremble is still not a movement; moving on reads again.
        #expect(machine.pointerMoved(to: CGPoint(x: 101, y: 101), at: at(5100)).isEmpty)
        #expect(machine.pointerMoved(to: CGPoint(x: 160, y: 100), at: at(5200)) == [.scheduleWake(at: at(5600))])
    }

    @Test func aClickDuringAReadAbandonsIt() {
        var machine = CursorRestMachine()
        _ = machine.pointerMoved(to: point, at: at(0))
        _ = machine.wake(at: at(400))
        #expect(machine.dismissed() == [.hideTooltip, .cancelRead])
        #expect(machine.recognized(CursorRecognition(text: "Late", region: region), job: 1, context: "ctx").isEmpty)
    }

    @Test func resultsOfAnAbandonedReadAreIgnored() {
        var machine = CursorRestMachine()
        _ = machine.pointerMoved(to: point, at: at(0))
        _ = machine.wake(at: at(400))
        _ = machine.pointerMoved(to: CGPoint(x: 600, y: 600), at: at(450))
        #expect(machine.recognized(CursorRecognition(text: "Late", region: region), job: 1, context: "ctx").isEmpty)
        #expect(machine.readFailed("No screen", job: 1).isEmpty)
    }

    @Test func nothingUnderThePointerHidesTheTooltip() {
        var machine = CursorRestMachine()
        _ = machine.pointerMoved(to: point, at: at(0))
        _ = machine.wake(at: at(400))
        #expect(machine.recognized(nil, job: 1, context: "ctx") == [.hideTooltip])
    }

    @Test func failuresAreShownWhereTheTextIs() {
        var machine = CursorRestMachine()
        let key = CursorRestMachine.key("Hello", context: "ctx")
        _ = rest(&machine, on: "Hello", at: 0)
        #expect(machine.translationFailed("Add an API key.", key: key) == [.showFailure("Add an API key.", region: region, point: point)])
        // A failure is not cached: resting there again tries again.
        _ = machine.pointerMoved(to: CGPoint(x: 600, y: 600), at: at(1000))
        #expect(rest(&machine, on: "Hello", at: 2000).contains(.translate(key: key, text: "Hello")))
    }

    @Test func theCacheKeepsTheMostRecentlyUsed() {
        var cache = CursorCache(limit: 2)
        cache["a"] = result("a")
        cache["b"] = result("b")
        _ = cache.use("a")
        cache["c"] = result("c")
        #expect(cache["a"] != nil && cache["b"] == nil && cache["c"] != nil && cache.count == 2)
    }
}
