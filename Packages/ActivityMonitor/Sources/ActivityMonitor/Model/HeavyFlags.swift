/// Which of the heavy-use thresholds a process is over.
nonisolated struct HeavyFlags: OptionSet, Sendable, Hashable {
    let rawValue: Int

    static let cpu = HeavyFlags(rawValue: 1 << 0)
    static let memory = HeavyFlags(rawValue: 1 << 1)
    static let disk = HeavyFlags(rawValue: 1 << 2)
    static let network = HeavyFlags(rawValue: 1 << 3)
}
