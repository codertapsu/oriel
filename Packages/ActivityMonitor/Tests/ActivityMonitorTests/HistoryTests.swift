@testable import ActivityMonitor
import Testing

struct HistoryTests {
    @Test func aRingBufferKeepsTheNewestInOrder() {
        var buffer = RingBuffer<Int>(capacity: 3)
        #expect(buffer.isEmpty)
        #expect(buffer.last == nil)
        for value in 1 ... 5 {
            buffer.append(value)
        }
        #expect(buffer.elements == [3, 4, 5])
        #expect(buffer.count == 3)
        #expect(buffer.last == 5)
        buffer.resize(to: 2)
        #expect(buffer.elements == [4, 5])
        buffer.append(6)
        #expect(buffer.elements == [5, 6])
        buffer.resize(to: 4)
        buffer.append(7)
        #expect(buffer.elements == [5, 6, 7])
        buffer.removeAll()
        #expect(buffer.elements.isEmpty)
        #expect(RingBuffer<Int>(capacity: 0).capacity == 1)
    }

    @Test func historyRecordsSeriesWithGapsForUnknowns() {
        var history = ActivityHistory(capacity: 3)
        history.record(SystemMetrics(), processes: [])
        var metrics = SystemMetrics()
        metrics.cpu = CPULoad(user: 0.25, system: 0.1)
        metrics.pressure = MemoryPressure(level: .warning, percent: 61)
        history.record(metrics, processes: [])
        let user = history.values(.cpuUser)
        #expect(user.count == 2)
        #expect(user[0].isNaN)
        #expect(user[1] == 25)
        #expect(history.snapshot.pressureLevels == [.normal, .warning])
        #expect(history.values(.memoryPressure).last == 61)
        #expect(history.values(.gpu).last?.isNaN == true)
    }

    @Test func processHistoriesFollowTheProcessesAndForgetEndedOnes() throws {
        var history = ActivityHistory(capacity: 400)
        #expect(history.processCapacity == ActivityHistory.processCapacityLimit)
        let first = Fixtures.process(1, cpu: 10, memory: 1000)
        let second = Fixtures.process(2, cpu: nil, realMemory: 500)
        history.record(SystemMetrics(), processes: [first, second])
        history.record(SystemMetrics(), processes: [first])
        let kept = try #require(history.process(first.id))
        #expect(kept.cpu == [10, 10])
        #expect(kept.memory == [1000, 1000])
        #expect(history.process(second.id) == nil)
        history.resize(to: 1)
        #expect(history.capacity == 2)
        #expect(history.process(first.id)?.cpu.count == 2)
    }

    @Test func processHistoryTakesRealMemoryWhenThatIsAllThereIs() {
        var history = ActivityHistory(capacity: 5)
        let other = Fixtures.process(9, uid: 0, cpu: nil, realMemory: 4096)
        history.record(SystemMetrics(), processes: [other])
        #expect(history.process(other.id)?.memory == [4096])
        #expect(history.process(other.id)?.cpu.first?.isNaN == true)
    }
}
