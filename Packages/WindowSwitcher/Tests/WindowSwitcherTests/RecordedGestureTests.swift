import Testing
@testable import WindowSwitcher

/// The recognizer on sequences recorded from a real trackpad (checklist, Phase 1): three-finger swipes open the
/// switcher in their direction and end when the fingers lift; four-finger, two-finger and vertical swipes never open
/// it. The fixtures come from `GestureRecorderTests` (`ORIEL_RECORD_GESTURES=1`); until they are recorded, this is
/// skipped and the synthetic sequences of `GestureRecognizerTests` stand in.
struct RecordedGestureTests {
    private static let fixtures = GestureFixture.all()

    @Test(.enabled(if: !fixtures.isEmpty, "no recorded gestures in Tests/Fixtures/gestures yet"), arguments: fixtures)
    func aRecordedSequenceIsRecognizedAsRecorded(_ fixture: GestureFixture) {
        var recognizer = GestureRecognizer()
        let events = fixture.samples.flatMap { recognizer.feed($0) }
        switch fixture.expected {
        case .forward, .backward:
            let direction: SelectionDirection = fixture.expected == .forward ? .forward : .backward
            #expect(events.first == .began(direction), "\(fixture.name): \(events)")
            #expect(events.last == .ended, "\(fixture.name): \(events)")
            #expect(!events.contains(.cancelled), "\(fixture.name): \(events)")
        case .none:
            #expect(events.isEmpty, "\(fixture.name): \(events)")
        }
    }
}
