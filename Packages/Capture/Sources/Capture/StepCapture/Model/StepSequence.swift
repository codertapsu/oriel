import Foundation

/// The steps of one Step Capture, in order, and the edits the sequence window makes: reordering, deleting, titles and
/// notes, new images. A value type, so undo keeps whole snapshots and every rule is unit-tested.
nonisolated struct StepSequence: Sendable, Equatable {
    /// What the exports are called, and the window.
    var title: String
    private(set) var steps: [Step] = []

    init(title: String, steps: [Step] = []) {
        self.title = title
        self.steps = steps
    }

    /// "Steps 2026-10-29 at 14.02", as macOS names screenshots.
    static func defaultTitle(at date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let day = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        return "Steps \(day) at \(String(format: "%02d.%02d", parts.hour ?? 0, parts.minute ?? 0))"
    }

    var isEmpty: Bool {
        steps.isEmpty
    }

    var count: Int {
        steps.count
    }

    /// 1 for the first step.
    func number(of id: UUID) -> Int? {
        steps.firstIndex { $0.id == id }.map { $0 + 1 }
    }

    func step(_ id: UUID) -> Step? {
        steps.first { $0.id == id }
    }

    /// Adds `step` at the end and returns its number.
    @discardableResult
    mutating func append(_ step: Step) -> Int {
        steps.append(step)
        return steps.count
    }

    /// Moves the steps at `offsets` so they come before the step now at `destination`, keeping their order, as a drag
    /// in a list does (`destination` may be the count, for the end).
    mutating func move(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        let valid = offsets.filter { steps.indices.contains($0) }
        guard !valid.isEmpty else { return }
        let moving = valid.map { steps[$0] }
        let before = valid.count { $0 < destination }
        for index in valid.sorted(by: >) {
            steps.remove(at: index)
        }
        let target = min(max(destination - before, 0), steps.count)
        steps.insert(contentsOf: moving, at: target)
    }

    mutating func remove(_ ids: Set<UUID>) {
        steps.removeAll { ids.contains($0.id) }
    }

    /// Changes the step `id`, if it is still there.
    mutating func update(_ id: UUID, _ change: (inout Step) -> Void) {
        guard let index = steps.firstIndex(where: { $0.id == id }) else { return }
        change(&steps[index])
    }

    /// These steps, in this order, with the title and the steps' titles and notes as `other` has them. Undo puts
    /// back the steps and images of an earlier state without losing what was typed since, which has its own undo
    /// while it is typed.
    func keepingText(of other: StepSequence) -> StepSequence {
        var merged = self
        merged.title = other.title
        for index in merged.steps.indices {
            if let typed = other.step(merged.steps[index].id) {
                merged.steps[index].title = typed.title
                merged.steps[index].note = typed.note
            }
        }
        return merged
    }
}
