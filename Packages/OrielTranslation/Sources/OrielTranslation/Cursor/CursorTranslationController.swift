import CoreGraphics
import Foundation
import OrielCore

/// Runs Translate Under Cursor (PLAN §17): hands the pointer's movements to `CursorRestMachine` and carries out what it
/// decides. Reading means capturing about 600 × 120 points around the pointer, OCR by lines, and taking the line or
/// paragraph under the pointer; text that runs past the area is read again from a larger one, once. A read is reused
/// for three seconds while the pointer stays in it and nothing scrolled, was clicked or typed. While the pointer
/// rests, nothing runs at all.
@MainActor
final class CursorTranslationController {
    /// Everything the controller needs from outside, so tests can stand in for the screen, OCR, the provider and time.
    struct Environment {
        /// Captures part of the screen, in global points (`TranslationCoordinator.screenCapture`).
        var capture: @MainActor (CGRect) async throws -> CGImage
        /// OCR by lines.
        var recognize: @Sendable (CGImage) async throws -> [OCRBlock]
        /// Translates a piece of text with the provider, languages and glossary Settings choose.
        var translate: @MainActor (String) async throws -> CursorTranslation
        /// The provider, target and glossary as one string: a cached translation holds only in its own context.
        var context: @MainActor () -> String
        var unit: @MainActor () -> CursorTextUnit
        /// The frame of the screen showing a point, in global points.
        var screen: @MainActor (CGPoint) -> CGRect?
        var hasScreenRecording: @MainActor () -> Bool
        var now: @MainActor () -> ContinuousClock.Instant
        var sleep: @Sendable (ContinuousClock.Instant) async throws -> Void
    }

    /// How long a read is reused while the pointer stays in it.
    static let reuseInterval: Duration = .seconds(3)

    private var machine: CursorRestMachine
    private let environment: Environment
    private let tooltip: any CursorTooltipPresenting
    private var wakeTask: Task<Void, Never>?
    private var readTask: Task<Void, Never>?
    private var readID = 0
    private var translations: [String: Task<Void, Never>] = [:]
    private var lastRead: (rect: CGRect, lines: [TextLine], when: ContinuousClock.Instant)?
    private(set) var isRunning = false
    /// Called when the controller stops by itself, with the reason (Screen Recording was taken away).
    var onStop: (@MainActor (String) -> Void)?

    init(environment: Environment, tooltip: any CursorTooltipPresenting, configuration: CursorRestMachine.Configuration = .init()) {
        self.environment = environment
        self.tooltip = tooltip
        machine = CursorRestMachine(configuration: configuration)
    }

    /// Starts watching from `point`, so text already under the pointer is translated once it rests.
    func start(at point: CGPoint) {
        guard !isRunning else { return }
        isRunning = true
        apply(machine.pointerMoved(to: point, at: environment.now()))
    }

    func stop() {
        isRunning = false
        wakeTask?.cancel()
        wakeTask = nil
        readTask?.cancel()
        readTask = nil
        for task in translations.values {
            task.cancel()
        }
        translations = [:]
        lastRead = nil
        tooltip.hide()
    }

    func pointerMoved(to point: CGPoint) {
        guard isRunning else { return }
        apply(machine.pointerMoved(to: point, at: environment.now()))
    }

    /// A scroll: what is under the pointer moved.
    func contentChanged() {
        guard isRunning else { return }
        lastRead = nil
        apply(machine.contentChanged(at: environment.now()))
    }

    /// A click or a key press: the tooltip goes until the pointer moves on.
    func dismiss() {
        guard isRunning else { return }
        lastRead = nil
        apply(machine.dismissed())
    }

    /// Waits until reads and translations in progress are done, for tests.
    func settle() async {
        for _ in 0 ..< 20 {
            let read = readTask
            let pending = Array(translations.values)
            guard read != nil || !pending.isEmpty else { return }
            await read?.value
            for task in pending {
                await task.value
            }
        }
    }

    // MARK: - Effects

    private func apply(_ effects: [CursorRestMachine.Effect]) {
        for effect in effects {
            switch effect {
            case let .scheduleWake(deadline):
                scheduleWake(at: deadline)
            case .hideTooltip:
                tooltip.hide()
            case .cancelRead:
                readTask?.cancel()
                readTask = nil
            case let .read(job, point):
                read(job: job, at: point)
            case let .translate(key, text):
                translate(text, key: key)
            case let .showPending(region, point):
                tooltip.showPending(region: region, pointer: point)
            case let .show(result, region, point):
                if result.isSameLanguage {
                    tooltip.hide()
                } else {
                    tooltip.show(result, region: region, pointer: point)
                }
            case let .showFailure(message, region, point):
                tooltip.showFailure(message, region: region, pointer: point)
            }
        }
    }

    /// One wake-up at the moment the machine asked for.
    private func scheduleWake(at deadline: ContinuousClock.Instant) {
        wakeTask?.cancel()
        let sleep = environment.sleep
        wakeTask = Task { [weak self] in
            do {
                try await sleep(deadline)
            } catch {
                return
            }
            guard let self, isRunning, !Task.isCancelled else { return }
            apply(machine.wake(at: environment.now()))
        }
    }

    private func read(job: Int, at point: CGPoint) {
        readTask?.cancel()
        readID &+= 1
        let id = readID
        readTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if readID == id {
                    readTask = nil
                }
            }
            do {
                let recognition = try await recognize(at: point)
                guard isRunning, !Task.isCancelled else { return }
                apply(machine.recognized(recognition, job: job, context: environment.context()))
            } catch {
                guard isRunning, !Task.isCancelled, !(error is CancellationError) else { return }
                guard environment.hasScreenRecording() else {
                    stop()
                    onStop?("Translate Under Cursor stopped: Oriel no longer has Screen & System Audio Recording.")
                    return
                }
                apply(machine.readFailed("Couldn't read the screen: \(error.localizedDescription)", job: job))
            }
        }
    }

    private func translate(_ text: String, key: String) {
        let translate = environment.translate
        translations[key] = Task { [weak self] in
            let outcome: Result<CursorTranslation, TranslationFailure>
            do {
                outcome = try await .success(translate(text))
            } catch is CancellationError {
                return
            } catch {
                outcome = .failure(TranslationFailure.from(error))
            }
            guard let self else { return }
            translations[key] = nil
            guard isRunning else { return }
            switch outcome {
            case let .success(result): apply(machine.translated(result, key: key))
            case let .failure(failure): apply(machine.translationFailed(failure.localizedDescription, key: key))
            }
        }
    }

    // MARK: - Reading the screen

    /// The text under `point`: the line or paragraph, read again from a larger area when it runs past the first.
    private func recognize(at point: CGPoint) async throws -> CursorRecognition? {
        guard let screen = environment.screen(point) else { return nil }
        let unit = environment.unit()
        let (rect, read) = try await linesAround(point, on: screen)
        guard var pick = CursorTextPicker.pick(at: point, in: read, unit: unit) else { return nil }
        if let grown = CursorTextPicker.grownRect(for: pick, capture: rect, screen: screen, unit: unit) {
            let more = try await lines(in: grown)
            lastRead = (grown, more, environment.now())
            pick = CursorTextPicker.pick(at: point, in: more, unit: unit) ?? pick
        }
        return CursorRecognition(text: pick.text, region: pick.region)
    }

    private func linesAround(_ point: CGPoint, on screen: CGRect) async throws -> (CGRect, [TextLine]) {
        if let lastRead, lastRead.rect.insetBy(dx: 24, dy: 8).contains(point), environment.now() - lastRead.when < Self.reuseInterval {
            return (lastRead.rect, lastRead.lines)
        }
        let rect = CursorGeometry.captureRect(around: point, on: screen)
        let read = try await lines(in: rect)
        lastRead = (rect, read, environment.now())
        return (rect, read)
    }

    private func lines(in rect: CGRect) async throws -> [TextLine] {
        let image = try await environment.capture(rect)
        try Task.checkCancellation()
        let blocks = try await environment.recognize(image)
        try Task.checkCancellation()
        return CursorTextPicker.lines(from: blocks, imageWidth: image.width, captureRect: rect)
    }
}
