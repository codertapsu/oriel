/// When the Dock's icons are read again (PLAN §7.1.12), as a pure value the controller sleeps on. The Dock reports no
/// moves, so each read waits for them to end: asking again while a read is pending keeps the later of the two times, so
/// the pointer leaving the Dock (0.4 s) never cuts the icons' settling (0.7 s) short, and a read under way when another
/// is asked for is not stored, so it cannot end a settle that began after it.
nonisolated struct DockLayoutSchedule: Sendable, Equatable {
    /// When the pending read is due; nil when none is.
    private(set) var due: ContinuousClock.Instant?
    /// Counts the reads asked for: a read is stored only when none was asked for after it began.
    private var generation = 0

    /// Asks for a read `delay` after `now`, or at the pending read's time when that is later; returns when it is due.
    mutating func schedule(after delay: Duration, now: ContinuousClock.Instant) -> ContinuousClock.Instant {
        let due = max(now + delay, due ?? now)
        self.due = due
        generation += 1
        return due
    }

    /// The pending read begins; `isCurrent` tells from the token it returns whether another was asked for meanwhile.
    mutating func begin() -> Int {
        due = nil
        return generation
    }

    /// Whether the read that began with `token` is the latest asked for, and so the one to store.
    func isCurrent(_ token: Int) -> Bool {
        token == generation
    }
}
