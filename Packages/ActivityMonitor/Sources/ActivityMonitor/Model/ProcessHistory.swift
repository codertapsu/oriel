/// One process's recent CPU percentage and memory, for the graphs in its details. `Float` halves what hundreds of
/// processes' histories take.
nonisolated struct ProcessHistory: Sendable {
    var cpu: RingBuffer<Float>
    var memory: RingBuffer<Float>

    init(capacity: Int) {
        cpu = RingBuffer(capacity: capacity)
        memory = RingBuffer(capacity: capacity)
    }

    var snapshot: ProcessHistorySnapshot {
        ProcessHistorySnapshot(cpu: cpu.elements, memory: memory.elements)
    }
}
