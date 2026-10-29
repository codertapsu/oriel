import Darwin

/// The processor, memory and load from Mach host statistics and sysctls: public, unprivileged, and a few microseconds
/// each.
nonisolated enum SystemStats {
    /// `mach_host_self()` adds a reference to the port each time it is called, so it is called once.
    private static let host = mach_host_self()

    /// Each core's tick counters, in `host_processor_info` order.
    static func cores() -> [CPUTicks] {
        var count: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &count, &info, &infoCount) == KERN_SUCCESS, let info else { return [] }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride))
        }
        let states = Int(CPU_STATE_MAX)
        return (0 ..< Int(count)).map { core in
            func ticks(_ state: Int32) -> UInt32 {
                UInt32(bitPattern: info[core * states + Int(state)])
            }
            return CPUTicks(
                user: ticks(CPU_STATE_USER),
                system: ticks(CPU_STATE_SYSTEM),
                idle: ticks(CPU_STATE_IDLE),
                nice: ticks(CPU_STATE_NICE)
            )
        }
    }

    /// The VM page counts and the kernel's page size (16 KB on Apple silicon, also as seen from Rosetta).
    static func memory() -> (counts: VMCounts, pageSize: UInt64)? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(host, HOST_VM_INFO64, $0, &count) }
        }
        guard result == KERN_SUCCESS else { return nil }
        var pageSize: vm_size_t = 0
        if host_page_size(host, &pageSize) != KERN_SUCCESS || pageSize == 0 {
            pageSize = 16384
        }
        let counts = VMCounts(
            free: UInt64(stats.free_count),
            active: UInt64(stats.active_count),
            inactive: UInt64(stats.inactive_count),
            speculative: UInt64(stats.speculative_count),
            wired: UInt64(stats.wire_count),
            purgeable: UInt64(stats.purgeable_count),
            external: UInt64(stats.external_page_count),
            internal: UInt64(stats.internal_page_count),
            compressor: UInt64(stats.compressor_page_count)
        )
        return (counts, UInt64(pageSize))
    }

    static var physicalMemory: UInt64 {
        integer("hw.memsize", as: UInt64.self) ?? 0
    }

    static func swap() -> (used: UInt64, total: UInt64) {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &usage, &size, nil, 0) == 0 else { return (0, 0) }
        return (usage.xsu_used, usage.xsu_total)
    }

    static func pressure() -> MemoryPressure? {
        guard let level = integer("kern.memorystatus_vm_pressure_level", as: Int32.self) else { return nil }
        return MemoryPressure(levelValue: level, availablePercent: integer("kern.memorystatus_level", as: Int32.self))
    }

    /// The one-minute load average.
    static func loadAverage() -> Double? {
        var load = loadavg()
        var size = MemoryLayout<loadavg>.size
        guard sysctlbyname("vm.loadavg", &load, &size, nil, 0) == 0, load.fscale > 0 else { return nil }
        return Double(load.ldavg.0) / Double(load.fscale)
    }

    static var coreCount: Int {
        Int(integer("hw.logicalcpu", as: Int32.self) ?? 1)
    }

    /// `hw.perflevelN`, performance cores first: their names and core counts. Empty on Intel.
    static func performanceLevels() -> [(name: String, cores: Int)] {
        let levels = Int(integer("hw.nperflevels", as: Int32.self) ?? 0)
        return (0 ..< levels).compactMap { level in
            guard let cores = integer("hw.perflevel\(level).logicalcpu", as: Int32.self) else { return nil }
            var name = [UInt8](repeating: 0, count: 64)
            var size = name.count
            let named = sysctlbyname("hw.perflevel\(level).name", &name, &size, nil, 0) == 0
            return (named ? ByteText.cString(name) : "Level \(level)", Int(cores))
        }
    }

    private static func integer<Value: FixedWidthInteger>(_ name: String, as _: Value.Type) -> Value? {
        var value: Value = 0
        var size = MemoryLayout<Value>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return value
    }
}
