/// The last nettop run: when it ran and what it listed for each process. A process it did not list had no traffic then.
nonisolated struct NetworkBaseline: Sendable, Equatable {
    let time: UInt64
    let processes: [ProcessIdentity: ProcessNetwork]

    init(time: UInt64, processes: [ProcessIdentity: ProcessNetwork]) {
        self.time = time
        self.processes = processes
    }

    /// From a sample in which nettop ran.
    init(_ sample: RawSample) {
        var processes: [ProcessIdentity: ProcessNetwork] = [:]
        for reading in sample.processes {
            if let network = reading.network {
                processes[reading.basics.identity] = network
            }
        }
        self.init(time: sample.time, processes: processes)
    }
}
