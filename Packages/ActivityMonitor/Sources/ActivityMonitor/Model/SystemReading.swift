/// The Mac-wide counters one sample read. All of them are public and cheap: sysctls, Mach host statistics and IOKit
/// registry properties.
nonisolated struct SystemReading: Sendable, Equatable {
    var cores: [CPUTicks] = []
    /// In the same order as `cores`; empty when unknown.
    var coreTypes: [CoreType] = []
    var memory: VMCounts?
    var pageSize: UInt64 = 16384
    var physicalMemory: UInt64 = 0
    var swapUsed: UInt64 = 0
    var swapTotal: UInt64 = 0
    var pressure: MemoryPressure?
    /// Keyed by the driver's registry entry ID, so a disk that comes and goes is told apart.
    var disks: [UInt64: DiskCounters] = [:]
    var interfaces: [InterfaceCounters] = []
    var gpus: [GPUReading] = []
    var battery: BatteryReading?
    var thermal: ThermalLevel = .nominal
    /// Over the last minute.
    var loadAverage: Double?
}
