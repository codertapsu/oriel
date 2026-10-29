import Darwin

/// Converts the kernel's CPU times, which `proc_pid_rusage` and `PROC_PIDTASKINFO` give in ticks of the timebase.
///
/// The frequency comes from `hw.tbfrequency` (24 MHz on Apple silicon, 1 GHz on Intel). `mach_timebase_info` would be
/// wrong under Rosetta: it reports 1/1 there while the kernel's counters stay in native ticks.
nonisolated enum MachTicks {
    static let frequency: UInt64 = {
        var value: Int64 = 0
        var size = MemoryLayout<Int64>.size
        if sysctlbyname("hw.tbfrequency", &value, &size, nil, 0) == 0, value > 0 {
            return UInt64(value)
        }
        var timebase = mach_timebase_info()
        guard mach_timebase_info(&timebase) == KERN_SUCCESS, timebase.numer > 0 else { return 1_000_000_000 }
        return 1_000_000_000 * UInt64(timebase.denom) / UInt64(timebase.numer)
    }()

    static func nanoseconds(_ ticks: UInt64) -> UInt64 {
        let product = ticks.multipliedFullWidth(by: 1_000_000_000)
        guard product.high < frequency else { return .max }
        return frequency.dividingFullWidth(product).quotient
    }
}
