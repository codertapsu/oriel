import Darwin
import OrielCore

/// The kernel's process table and libproc. What works for every user's processes (the table, paths) and what macOS
/// answers only for the user's own (usage, threads, arguments) are kept apart, so nothing asks for what it cannot get.
nonisolated enum ProcessTable {
    /// Apple silicon leaves `ri_pkg_idle_wkups` at zero and counts wake-ups in `ri_interrupt_wkups`.
    private static let onAppleSilicon = HardwareInfo.isAppleSiliconHardware

    /// Every process, from one `sysctl(KERN_PROC_ALL)` call: about 0.2 ms for 800 processes.
    static func all() -> [ProcessBasics] {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL]
        let stride = MemoryLayout<kinfo_proc>.stride
        // Processes start between sizing the buffer and filling it; a few tries with room to spare cover that.
        for _ in 0 ..< 4 {
            var size = 0
            guard sysctl(&mib, 3, nil, &size, nil, 0) == 0 else { return [] }
            var buffer = [kinfo_proc](repeating: kinfo_proc(), count: size / stride + 64)
            var length = buffer.count * stride
            let result = buffer.withUnsafeMutableBytes { sysctl(&mib, 3, $0.baseAddress, &length, nil, 0) }
            if result == 0 {
                return buffer.prefix(length / stride).map(basics)
            }
            guard errno == ENOMEM else { return [] }
        }
        return []
    }

    /// One process's table entry, or nil once it has ended.
    static func basics(of pid: Int32) -> ProcessBasics? {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else { return nil }
        return basics(info)
    }

    /// The executable's path; works for every user's processes, not the kernel's.
    static func path(of pid: Int32) -> String? {
        var buffer = [UInt8](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let length = buffer.withUnsafeMutableBytes { proc_pidpath(pid, $0.baseAddress, UInt32($0.count)) }
        guard length > 0 else { return nil }
        return ByteText.string(buffer.prefix(Int(length)))
    }

    /// CPU time, memory, disk, energy, wake-ups and threads of one of the user's own processes; nil for anyone else's.
    static func counters(of pid: Int32, kernelState: Int8) -> ProcessCounters? {
        var usage = rusage_info_v6()
        let result = withUnsafeMutablePointer(to: &usage) { pointer in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V6, $0) }
        }
        guard result == 0 else { return nil }
        var task = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.size)
        let hasTask = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &task, size) == size
        return ProcessCounters(
            source: .usage,
            cpuTime: MachTicks.nanoseconds(usage.ri_user_time &+ usage.ri_system_time),
            footprint: usage.ri_phys_footprint,
            residentSize: usage.ri_resident_size,
            diskRead: usage.ri_diskio_bytesread,
            diskWritten: usage.ri_diskio_byteswritten,
            energy: usage.ri_energy_nj > 0 ? usage.ri_energy_nj : nil,
            idleWakeups: onAppleSilicon ? usage.ri_interrupt_wkups : usage.ri_pkg_idle_wkups,
            threads: hasTask ? Int(task.pti_threadnum) : nil,
            status: ProcessStatus(kernelState: kernelState, runningThreads: hasTask ? Int(task.pti_numrunning) : nil)
        )
    }

    /// The command line of one of the user's own processes, without its environment.
    static func commandLine(of pid: Int32) -> ProcessCommandLine? {
        var argumentsMax: Int32 = 0
        var argumentsMaxSize = MemoryLayout<Int32>.size
        guard sysctlbyname("kern.argmax", &argumentsMax, &argumentsMaxSize, nil, 0) == 0, argumentsMax > 0 else { return nil }
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var buffer = [UInt8](repeating: 0, count: Int(argumentsMax))
        var size = buffer.count
        guard sysctl(&mib, 3, &buffer, &size, nil, 0) == 0 else { return nil }
        return ProcessCommandLine(procargs: Array(buffer.prefix(size)))
    }

    private static func basics(_ info: kinfo_proc) -> ProcessBasics {
        let start = info.kp_proc.p_starttime
        let command = ByteText.cString(of: info.kp_proc.p_comm)
        return ProcessBasics(
            pid: info.kp_proc.p_pid,
            parentPID: info.kp_eproc.e_ppid,
            uid: info.kp_eproc.e_ucred.cr_uid,
            startTime: UInt64(max(0, start.tv_sec)) * 1_000_000 + UInt64(max(0, start.tv_usec)),
            command: command,
            kernelState: Int8(bitPattern: UInt8(bitPattern: info.kp_proc.p_stat)),
            isTranslated: info.kp_proc.p_flag & P_TRANSLATED != 0
        )
    }
}
