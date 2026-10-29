/// One core's tick counters from `host_processor_info(PROCESSOR_CPU_LOAD_INFO)`. They are 32-bit and wrap, after about
/// 500 days of one core's time at 100 Hz, so differences are taken modulo 2³².
nonisolated struct CPUTicks: Sendable, Equatable {
    var user: UInt32
    var system: UInt32
    var idle: UInt32
    var nice: UInt32

    /// How the core spent its time since `earlier`; nil when no tick passed in between.
    func load(since earlier: CPUTicks) -> CPULoad? {
        Self.load(since: [earlier], now: [self])
    }

    /// The load of several cores together, weighting each by the ticks it counted. Nil when the lists do not match (a
    /// core went offline) or no tick passed.
    static func load(since earlier: [CPUTicks], now: [CPUTicks]) -> CPULoad? {
        guard earlier.count == now.count, !now.isEmpty else { return nil }
        var user: UInt64 = 0
        var system: UInt64 = 0
        var total: UInt64 = 0
        for (before, after) in zip(earlier, now) {
            let userTicks = UInt64(after.user &- before.user) + UInt64(after.nice &- before.nice)
            let systemTicks = UInt64(after.system &- before.system)
            user += userTicks
            system += systemTicks
            total += userTicks + systemTicks + UInt64(after.idle &- before.idle)
        }
        guard total > 0 else { return nil }
        return CPULoad(user: Double(user) / Double(total), system: Double(system) / Double(total))
    }
}
