@testable import ActivityMonitor
import Testing

struct SnapshotBuilderTests {
    let builder = SnapshotBuilder(myUID: Fixtures.me, onAppleSilicon: true, coreCount: 12)

    private func metrics(_ previous: RawSample?, _ current: RawSample) -> [Int32: ProcessMetrics] {
        let list = builder.processes(previous: previous, current: current, apps: [:]) { $0 == 0 ? "root" : "me" }
        return Dictionary(uniqueKeysWithValues: list.map { ($0.pid, $0) })
    }

    @Test func cpuPercentIsCPUTimeOverWallTime() throws {
        let first = RawSample(time: Fixtures.time(10), processes: [Fixtures.reading(42, cpuTime: 1_000_000_000)])
        // 1.5 s of CPU in 2 s: 75 % of one core.
        let second = RawSample(time: Fixtures.time(12), processes: [Fixtures.reading(42, cpuTime: 2_500_000_000)])
        let process = try #require(metrics(first, second)[42])
        #expect(abs((process.cpuPercent ?? 0) - 75) < 1e-9)
        #expect(process.cpuTime == 2_500_000_000)
        #expect(metrics(nil, first)[42]?.cpuPercent == nil)
    }

    @Test func aProcessUsingSeveralCoresGoesPast100ButNotPastEveryCore() {
        let first = RawSample(time: Fixtures.time(0), processes: [Fixtures.reading(7, cpuTime: 0)])
        let busy = RawSample(time: Fixtures.time(1), processes: [Fixtures.reading(7, cpuTime: 3_000_000_000)])
        #expect(metrics(first, busy)[7]?.cpuPercent == 300)
        let impossible = RawSample(time: Fixtures.time(1), processes: [Fixtures.reading(7, cpuTime: 50_000_000_000)])
        #expect(metrics(first, impossible)[7]?.cpuPercent == 1200)
    }

    @Test func aReusedPIDIsANewProcess() {
        let first = RawSample(time: Fixtures.time(0), processes: [Fixtures.reading(42, start: 100, cpuTime: 5_000_000_000)])
        let second = RawSample(time: Fixtures.time(2), processes: [Fixtures.reading(42, start: 200, cpuTime: 1_000_000)])
        #expect(metrics(first, second)[42]?.cpuPercent == nil)
    }

    @Test func countersFromDifferentReadersAreNotCompared() {
        let first = RawSample(time: Fixtures.time(0), processes: [Fixtures.reading(42, source: .ps, cpuTime: 1_000_000_000)])
        let second = RawSample(time: Fixtures.time(2), processes: [Fixtures.reading(42, source: .usage, cpuTime: 1_400_000_000)])
        #expect(metrics(first, second)[42]?.cpuPercent == nil)
        let third = RawSample(time: Fixtures.time(4), processes: [Fixtures.reading(42, source: .usage, cpuTime: 1_600_000_000)])
        #expect(metrics(second, third)[42]?.cpuPercent == 10)
    }

    @Test func aCounterThatWentDownGivesNoRate() {
        let first = RawSample(time: Fixtures.time(0), processes: [Fixtures.reading(42, cpuTime: 9_000_000_000, diskRead: 500)])
        let second = RawSample(time: Fixtures.time(2), processes: [Fixtures.reading(42, cpuTime: 1_000_000_000, diskRead: 100)])
        let process = metrics(first, second)[42]
        #expect(process?.cpuPercent == nil)
        #expect(process?.diskReadPerSecond == nil)
    }

    @Test func powerWakeUpsAndDiskRates() throws {
        var before = Fixtures.reading(42, cpuTime: 0, energy: 1_000_000_000, diskRead: 0)
        before.counters?.idleWakeups = 10
        before.counters?.diskWritten = 1000
        var after = Fixtures.reading(42, cpuTime: 0, energy: 3_000_000_000, diskRead: 4_000_000)
        after.counters?.idleWakeups = 30
        after.counters?.diskWritten = 3000
        let process = try #require(metrics(
            RawSample(time: Fixtures.time(0), processes: [before]),
            RawSample(time: Fixtures.time(2), processes: [after])
        )[42])
        #expect(process.power == 1)
        #expect(process.idleWakeupsPerSecond == 10)
        #expect(process.diskReadPerSecond == 2_000_000)
        #expect(process.diskWrittenPerSecond == 1000)
        #expect(process.diskPerSecond == 2_001_000)
    }

    @Test func networkRatesNeedNettopInBothSamples() {
        let earlier = ProcessNetwork(
            connections: ["c": TrafficBytes(received: 1000, sent: 100)],
            total: TrafficBytes(received: 1000, sent: 100)
        )
        let later = ProcessNetwork(
            connections: ["c": TrafficBytes(received: 3000, sent: 300)],
            total: TrafficBytes(received: 3000, sent: 300)
        )
        let first = RawSample(
            time: Fixtures.time(0),
            processes: [Fixtures.reading(42, network: earlier), Fixtures.reading(43)],
            sources: .network
        )
        let second = RawSample(
            time: Fixtures.time(2),
            processes: [Fixtures.reading(42, network: later), Fixtures.reading(43)],
            sources: .network
        )
        let result = metrics(first, second)
        #expect(result[42]?.network == TrafficRate(received: 1000, sent: 100))
        // No nettop line means no traffic, once nettop ran both times.
        #expect(result[43]?.network == .zero)
        let without = RawSample(time: Fixtures.time(2), processes: [Fixtures.reading(42, network: later)])
        #expect(metrics(first, without)[42]?.network == nil)
    }

    @Test func namesKindAndOwnership() {
        var reading = Fixtures.reading(42, uid: 0)
        reading.path = "/Applications/Example.app/Contents/MacOS/Example Helper (Renderer)"
        let app = Fixtures.app("Example", bundle: "/Applications/Example.app")
        let byApp = builder.processes(previous: nil, current: RawSample(time: 0, processes: [reading]), apps: [42: app]) { _ in "root" }
        #expect(byApp.first?.name == "Example")
        let byPath = builder.processes(previous: nil, current: RawSample(time: 0, processes: [reading]), apps: [:]) { _ in "root" }
        #expect(byPath.first?.name == "Example Helper (Renderer)")
        #expect(byPath.first?.isMine == false)
        #expect(byPath.first?.user == "root")
        reading.path = nil
        reading.basics = ProcessBasics(
            pid: 0,
            parentPID: 0,
            uid: 0,
            startTime: 1,
            command: "kernel_task",
            kernelState: 2,
            isTranslated: true
        )
        let kernel = builder.processes(previous: nil, current: RawSample(time: 0, processes: [reading]), apps: [:]) { _ in "root" }
        #expect(kernel.first?.name == "kernel_task")
        #expect(kernel.first?.kind == .intel)
    }

    @Test func systemRatesNeedTwoSamplesWithDevices() throws {
        var before = SystemReading()
        before.cores = [CPUTicks(user: 0, system: 0, idle: 0, nice: 0)]
        before.disks = [1: DiskCounters(bytesRead: 1000, bytesWritten: 0, reads: 1, writes: 0)]
        let traffic = TrafficBytes(received: 100, sent: 100)
        before.interfaces = [InterfaceCounters(name: "en0", type: 6, flags: 0, bytes: traffic, packets: traffic)]
        var after = before
        after.cores = [CPUTicks(user: 30, system: 10, idle: 60, nice: 0)]
        after.disks = [1: DiskCounters(bytesRead: 5000, bytesWritten: 2000, reads: 3, writes: 2), 2: DiskCounters(bytesRead: 9999)]
        let later = TrafficBytes(received: 2100, sent: 500)
        after.interfaces = [InterfaceCounters(name: "en0", type: 6, flags: 0, bytes: later, packets: later)]
        let first = RawSample(time: Fixtures.time(0), processes: [], system: before, sources: .devices)
        let second = RawSample(time: Fixtures.time(2), processes: [], system: after, sources: .devices)
        let system = builder.system(previous: first, current: second, processes: [])
        #expect(system.cpu == CPULoad(user: 0.3, system: 0.1))
        #expect(system.cores.count == 1)
        let disk = try #require(system.disk)
        // The disk that appeared in between counts toward the totals but adds no rate.
        #expect(disk.readBytesPerSecond == 2000)
        #expect(disk.writtenBytesPerSecond == 1000)
        #expect(disk.totals.bytesRead == 5000 + 9999)
        #expect(system.network?.bytesPerSecond == TrafficRate(received: 1000, sent: 200))
        #expect(builder.system(previous: nil, current: second, processes: []).disk == nil)
        let noDevices = RawSample(time: Fixtures.time(4), processes: [], system: after)
        #expect(builder.system(previous: second, current: noDevices, processes: []).disk == nil)
    }

    @Test func ownThreadsAndPowerAddUp() {
        var mine = Fixtures.process(1)
        mine.threads = 4
        mine.power = 0.5
        var other = Fixtures.process(2, uid: 0)
        other.threads = 100
        var second = Fixtures.process(3)
        second.threads = 2
        second.power = 0.25
        let system = builder.system(previous: nil, current: RawSample(time: 0, processes: []), processes: [mine, other, second])
        #expect(system.ownThreadCount == 6)
        #expect(system.ownPower == 0.75)
    }
}
