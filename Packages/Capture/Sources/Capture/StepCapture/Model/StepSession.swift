import CoreGraphics
import Foundation

/// The Step Capture state machine (PLAN §17). Starting a session turns every capture into the next numbered step
/// instead of opening Quick Access; Finish hands the steps to the sequence window, and Cancel discards them, after
/// asking when there are any. With Mark Clicks on, the last click before a capture marks that step, once: a click marks
/// at most one step.
nonisolated struct StepSession: Sendable, Equatable {
    enum Phase: Sendable, Equatable {
        case idle
        case capturing
    }

    private(set) var phase = Phase.idle
    private(set) var sequence = StepSequence(title: "")
    var marksClicks: Bool
    /// The last click since the last step (global CoreGraphics points), while marking clicks.
    private(set) var lastClick: CGPoint?

    init(marksClicks: Bool = true) {
        self.marksClicks = marksClicks
    }

    var isCapturing: Bool {
        phase == .capturing
    }

    /// What the Step Capture command is called now.
    var commandTitle: String {
        Self.commandTitle(isCapturing: isCapturing)
    }

    static func commandTitle(isCapturing: Bool) -> String {
        isCapturing ? "Finish Step Capture" : "Start Step Capture"
    }

    /// Cancel asks first once a step has been captured.
    var cancelNeedsConfirmation: Bool {
        isCapturing && !sequence.isEmpty
    }

    /// Begins a sequence called `title`; false while one is running already.
    @discardableResult
    mutating func start(title: String) -> Bool {
        guard !isCapturing else { return false }
        phase = .capturing
        sequence = StepSequence(title: title)
        lastClick = nil
        return true
    }

    /// A click anywhere outside Oriel, kept only while capturing with Mark Clicks on.
    mutating func recordClick(at point: CGPoint) {
        guard isCapturing, marksClicks else { return }
        lastClick = point
    }

    /// The click to mark on the step being added, which no later step will mark again.
    mutating func takeClick() -> CGPoint? {
        defer { lastClick = nil }
        return isCapturing && marksClicks ? lastClick : nil
    }

    /// Adds the next step and returns its number; nil while no session runs.
    @discardableResult
    mutating func append(_ step: Step) -> Int? {
        guard isCapturing else { return nil }
        return sequence.append(step)
    }

    /// Ends the session and returns its steps; nil when none were captured.
    mutating func finish() -> StepSequence? {
        guard isCapturing else { return nil }
        let finished = sequence
        reset()
        return finished.isEmpty ? nil : finished
    }

    /// Ends the session and returns the steps to throw away.
    mutating func cancel() -> [Step] {
        let discarded = sequence.steps
        reset()
        return discarded
    }

    private mutating func reset() {
        phase = .idle
        sequence = StepSequence(title: "")
        lastClick = nil
    }
}
