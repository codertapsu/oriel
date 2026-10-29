import CoreGraphics
import OrielCore
@testable import OrielTranslation
import Testing

/// Translate Under Cursor end to end, with a pretend screen, OCR that reads it, a fake provider and a clock the test
/// moves: what is captured, what is translated, what the tooltip shows. Nothing reads the real screen.
@MainActor
struct CursorTranslationControllerTests {
    /// Records the texts sent for translation; `failing` makes the provider fail.
    private final class Provider {
        var texts: [String] = []
        var failure: TranslationFailure?

        func translate(_ text: String) throws -> CursorTranslation {
            texts.append(text)
            if let failure {
                throw failure
            }
            return CursorTranslation(
                text: text,
                translation: "ja:\(text)",
                sourceLanguage: "en",
                targetLanguage: "ja",
                providerName: "Fake"
            )
        }
    }

    private let display = CGRect(x: 0, y: 0, width: 1440, height: 900)

    /// A paragraph of two lines, another paragraph well below it, and a long line cut off by the first capture.
    private func screen() -> FakeScreen {
        FakeScreen([
            TextLine(text: "Resting the pointer on a line translates", box: CGRect(x: 200, y: 300, width: 280, height: 16)),
            TextLine(text: "the whole paragraph it belongs to.", box: CGRect(x: 200, y: 320, width: 240, height: 16)),
            TextLine(text: "A second paragraph.", box: CGRect(x: 200, y: 380, width: 140, height: 16)),
        ])
    }

    private func controller(
        _ screen: FakeScreen,
        provider: Provider,
        clock: ManualClock,
        tooltip: RecordingTooltip,
        unit: CursorTextUnit = .paragraph,
        hasScreenRecording: @escaping @MainActor () -> Bool = { true }
    ) -> CursorTranslationController {
        let environment = CursorTranslationController.Environment(
            capture: { rect in try screen.capture(rect) },
            recognize: { _ in await screen.blocks() },
            translate: { text in try provider.translate(text) },
            context: { "fake|ja||" },
            unit: { unit },
            screen: { [display] _ in display },
            hasScreenRecording: hasScreenRecording,
            now: { clock.now },
            sleep: { deadline in try await clock.sleep(until: deadline) }
        )
        return CursorTranslationController(environment: environment, tooltip: tooltip)
    }

    @Test func translatesTheParagraphUnderTheRestingPointerOnce() async {
        let screen = screen()
        let provider = Provider()
        let clock = ManualClock()
        let tooltip = RecordingTooltip()
        let controller = controller(screen, provider: provider, clock: clock, tooltip: tooltip)
        defer {
            controller.stop()
            clock.cancelAll()
        }
        controller.start(at: CGPoint(x: 260, y: 308))
        await clock.advance(by: .milliseconds(399))
        #expect(screen.captures.isEmpty)
        await clock.advance(by: .milliseconds(1))
        await controller.settle()
        // 600 × 120 points around the pointer, moved to stay on the display.
        #expect(screen.captures == [CGRect(x: 0, y: 248, width: 600, height: 120)])
        let paragraph = "Resting the pointer on a line translates the whole paragraph it belongs to."
        #expect(provider.texts == [paragraph])
        #expect(tooltip.events == [.pending, .shown("ja:\(paragraph)")])

        // Moving along the paragraph keeps the tooltip and reads nothing.
        controller.pointerMoved(to: CGPoint(x: 400, y: 324))
        await clock.advance(by: .seconds(1))
        await controller.settle()
        #expect(screen.captures.count == 1 && tooltip.last == .shown("ja:\(paragraph)"))

        // Away to empty space and back: the cache answers, and the provider sees the paragraph once.
        controller.pointerMoved(to: CGPoint(x: 900, y: 700))
        #expect(tooltip.last == .hidden)
        await clock.advance(by: .milliseconds(400))
        await controller.settle()
        controller.pointerMoved(to: CGPoint(x: 250, y: 326))
        await clock.advance(by: .milliseconds(400))
        await controller.settle()
        #expect(provider.texts == [paragraph])
        #expect(tooltip.last == .shown("ja:\(paragraph)"))
    }

    @Test func theLineUnitTakesOneLine() async {
        let screen = screen()
        let provider = Provider()
        let clock = ManualClock()
        let tooltip = RecordingTooltip()
        let controller = controller(screen, provider: provider, clock: clock, tooltip: tooltip, unit: .line)
        defer {
            controller.stop()
            clock.cancelAll()
        }
        controller.start(at: CGPoint(x: 230, y: 326))
        await clock.advance(by: .milliseconds(400))
        await controller.settle()
        #expect(provider.texts == ["the whole paragraph it belongs to."])
    }

    @Test func aLineCutOffByTheCaptureIsReadAgainWhole() async {
        let screen = FakeScreen([
            TextLine(
                text: "A very long line that runs far past the first capture on both sides",
                box: CGRect(x: 100, y: 400, width: 1100, height: 16)
            ),
        ])
        let provider = Provider()
        let clock = ManualClock()
        let tooltip = RecordingTooltip()
        let controller = controller(screen, provider: provider, clock: clock, tooltip: tooltip)
        defer {
            controller.stop()
            clock.cancelAll()
        }
        controller.start(at: CGPoint(x: 650, y: 408))
        await clock.advance(by: .milliseconds(400))
        await controller.settle()
        #expect(screen.captures.count == 2)
        #expect(screen.captures[1].width > screen.captures[0].width && screen.captures[1].contains(CGRect(
            x: 100,
            y: 400,
            width: 1100,
            height: 16
        )))
        #expect(provider.texts.count == 1)
    }

    @Test func providerFailuresAreShownAndNotCached() async {
        let screen = screen()
        let provider = Provider()
        provider.failure = .missingAPIKey
        let clock = ManualClock()
        let tooltip = RecordingTooltip()
        let controller = controller(screen, provider: provider, clock: clock, tooltip: tooltip)
        defer {
            controller.stop()
            clock.cancelAll()
        }
        controller.start(at: CGPoint(x: 260, y: 308))
        await clock.advance(by: .milliseconds(400))
        await controller.settle()
        #expect(tooltip.last == .failed(TranslationFailure.missingAPIKey.localizedDescription))
    }

    /// Captures fail once the permission is gone, as ScreenCaptureKit's do.
    @Test func losingScreenRecordingStopsTheMode() async {
        let clock = ManualClock()
        let tooltip = RecordingTooltip()
        let reasons = Reasons()
        let controller = CursorTranslationController(
            environment: .init(
                capture: { _ in throw TranslationFailure.unavailable("The capture failed.") },
                recognize: { _ in [] },
                translate: { _ in throw TranslationFailure.cancelled },
                context: { "" },
                unit: { .paragraph },
                screen: { [display] _ in display },
                hasScreenRecording: { false },
                now: { clock.now },
                sleep: { deadline in try await clock.sleep(until: deadline) }
            ),
            tooltip: tooltip
        )
        defer { clock.cancelAll() }
        controller.onStop = { reasons.list.append($0) }
        controller.start(at: CGPoint(x: 260, y: 308))
        await clock.advance(by: .milliseconds(400))
        await controller.settle()
        #expect(!controller.isRunning && reasons.list.count == 1)
        #expect(reasons.list.first?.contains("Screen & System Audio Recording") == true)
        #expect(tooltip.last == .hidden)
    }

    private final class Reasons {
        var list: [String] = []
    }

    @Test func stoppingLeavesNothingRunning() async {
        let screen = screen()
        let clock = ManualClock()
        let tooltip = RecordingTooltip()
        let controller = controller(screen, provider: Provider(), clock: clock, tooltip: tooltip)
        controller.start(at: CGPoint(x: 260, y: 308))
        controller.stop()
        await clock.advance(by: .seconds(2))
        await controller.settle()
        #expect(screen.captures.isEmpty && !controller.isRunning && tooltip.last == .hidden)
        controller.pointerMoved(to: CGPoint(x: 10, y: 10))
        await clock.advance(by: .seconds(1))
        #expect(screen.captures.isEmpty)
        clock.cancelAll()
    }
}
