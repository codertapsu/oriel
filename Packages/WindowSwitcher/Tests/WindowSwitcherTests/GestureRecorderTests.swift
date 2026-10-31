import Foundation
import Hotkeys
import Testing

/// Records the fixtures of `RecordedGestureTests` from the trackpad (checklist, Phase 1). Opt in with
/// `ORIEL_RECORD_GESTURES=1 swift test --package-path Packages/WindowSwitcher --filter GestureRecorderTests`, after
/// quitting Oriel (its own gesture would open the switcher), and perform each gesture once when asked. It listens the
/// way the switcher's event tap does, so the terminal needs Accessibility; nothing is consumed.
@MainActor
struct GestureRecorderTests {
    private struct Take {
        let name: String
        let prompt: String
        let expected: GestureFixture.Outcome
    }

    private static let takes = [
        Take(name: "three-finger-right", prompt: "Swipe three fingers to the right", expected: .forward),
        Take(name: "three-finger-left", prompt: "Swipe three fingers to the left", expected: .backward),
        Take(name: "three-finger-right-thumb-resting", prompt: "Rest your thumb, then swipe three fingers right", expected: .forward),
        Take(name: "four-finger-right", prompt: "Swipe four fingers to the right", expected: .none),
        Take(name: "four-finger-left", prompt: "Swipe four fingers to the left", expected: .none),
        Take(name: "two-finger-right", prompt: "Swipe two fingers to the right", expected: .none),
        Take(name: "two-finger-left", prompt: "Swipe two fingers to the left", expected: .none),
        Take(name: "three-finger-up", prompt: "Swipe three fingers up", expected: .none),
    ]

    private nonisolated static var isRecording: Bool {
        ProcessInfo.processInfo.environment["ORIEL_RECORD_GESTURES"] == "1"
    }

    @Test(.enabled(if: isRecording, "records only with ORIEL_RECORD_GESTURES=1"))
    func recordTheGestureFixtures() throws {
        let tap = try #require(GestureTap.start(), "macOS refused the event tap: give the terminal Accessibility.")
        defer { tap.stop() }
        let recorded = "\(Date.now.formatted(.iso8601.year().month().day())), \(ProcessInfo.processInfo.operatingSystemVersionString)"
        for take in Self.takes {
            print("▶ \(take.prompt), once, in the next 5 seconds…")
            tap.clear()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 5))
            let sequence = Self.firstSequence(in: tap.frames)
            try #require(!sequence.isEmpty, "Nothing was recorded for “\(take.prompt)”.")
            try GestureFixture(name: take.name, expected: take.expected, recorded: recorded, samples: sequence).write()
            print("  \(sequence.count) frames → Tests/Fixtures/gestures/\(take.name).json")
        }
    }

    /// From the first frame with a finger down to the first one after it with none, which ends the gesture.
    private static func firstSequence(in frames: [[TouchSample]]) -> [[TouchSample]] {
        let fingers = { (frame: [TouchSample]) in frame.contains { !$0.isResting } }
        guard let start = frames.firstIndex(where: fingers) else { return [] }
        let end = frames[start...].firstIndex { !fingers($0) } ?? frames.count - 1
        return Array(frames[start ... end])
    }
}
