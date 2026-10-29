/// The Mac as a whole, as the summary under the list shows it. Rates are nil until two samples exist.
nonisolated struct SystemMetrics: Sendable, Equatable {
    var cpu: CPULoad?
    var cores: [CoreLoad] = []
    var memory: MemoryBreakdown?
    var pressure: MemoryPressure?
    var disk: DiskActivity?
    var network: NetworkActivity?
    var gpus: [GPUReading] = []
    var battery: BatteryReading?
    var thermal: ThermalLevel = .nominal
    var loadAverage: Double?
    var processCount = 0
    /// Threads of the user's own processes; macOS does not count other users' for them.
    var ownThreadCount = 0
    /// Watts drawn by the user's own processes, the only ones macOS measures for them.
    var ownPower: Double?
}
