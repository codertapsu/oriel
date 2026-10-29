@testable import ActivityMonitor
import Foundation
import Testing

struct SystemCountersTests {
    @Test func coreLoadComesFromTickDeltas() throws {
        let before = CPUTicks(user: 100, system: 50, idle: 800, nice: 50)
        let after = CPUTicks(user: 160, system: 70, idle: 900, nice: 60)
        let load = try #require(after.load(since: before))
        // 70 user (nice included), 20 system, 100 idle.
        #expect(abs(load.user - 70.0 / 190) < 1e-9)
        #expect(abs(load.system - 20.0 / 190) < 1e-9)
        #expect(abs(load.idle - 100.0 / 190) < 1e-9)
    }

    @Test func thirtyTwoBitTickCountersWrap() throws {
        // 20 user ticks across the wrap, and 40 idle ones.
        let before = CPUTicks(user: UInt32.max - 9, system: 0, idle: UInt32.max - 29, nice: 0)
        let after = CPUTicks(user: 10, system: 0, idle: 10, nice: 0)
        let load = try #require(after.load(since: before))
        #expect(abs(load.user - 20.0 / 60) < 1e-9)
        #expect(abs(load.idle - 40.0 / 60) < 1e-9)
    }

    @Test func noTicksOrAMissingCoreGiveNoLoad() {
        let ticks = CPUTicks(user: 1, system: 1, idle: 1, nice: 0)
        #expect(ticks.load(since: ticks) == nil)
        #expect(CPUTicks.load(since: [ticks], now: [ticks, ticks]) == nil)
        #expect(CPUTicks.load(since: [], now: []) == nil)
    }

    @Test func coresCountTogetherByTheirTicks() throws {
        let busy = (CPUTicks(user: 0, system: 0, idle: 0, nice: 0), CPUTicks(user: 100, system: 0, idle: 0, nice: 0))
        let idle = (CPUTicks(user: 0, system: 0, idle: 0, nice: 0), CPUTicks(user: 0, system: 0, idle: 100, nice: 0))
        let load = try #require(CPUTicks.load(since: [busy.0, idle.0], now: [busy.1, idle.1]))
        #expect(abs(load.busy - 0.5) < 1e-9)
    }

    /// vm_stat on this Mac: 16 KB pages, 24 GB.
    @Test func memoryBreaksDownAsActivityMonitorDoes() {
        let counts = VMCounts(
            free: 125_629,
            active: 396_961,
            inactive: 389_903,
            speculative: 6283,
            wired: 199_668,
            purgeable: 14961,
            external: 365_207,
            internal: 427_940,
            compressor: 419_517
        )
        let memory = MemoryBreakdown(counts: counts, pageSize: 16384, physical: 25_769_803_776, swapUsed: 0, swapTotal: 0)
        #expect(memory.app == (427_940 - 14961) * 16384)
        #expect(memory.wired == 199_668 * 16384)
        #expect(memory.compressed == 419_517 * 16384)
        #expect(memory.cached == (365_207 + 14961) * 16384)
        #expect(memory.used == memory.app + memory.wired + memory.compressed)
        #expect(memory.used + memory.cached + memory.free == memory.physical)
    }

    @Test func memoryNeverGoesNegativeOrPastThePhysical() {
        let counts = VMCounts(wired: 2000, purgeable: 50, internal: 10, compressor: 2000)
        let memory = MemoryBreakdown(counts: counts, pageSize: 1, physical: 1000, swapUsed: 7, swapTotal: 8)
        #expect(memory.app == 0)
        #expect(memory.used == 1000)
        #expect(memory.free == 0)
    }

    @Test func pressureLevelsAndPercent() {
        #expect(MemoryPressure(levelValue: 1, availablePercent: 57) == MemoryPressure(level: .normal, percent: 43))
        #expect(MemoryPressure(levelValue: 2, availablePercent: nil).level == .warning)
        #expect(MemoryPressure(levelValue: 4, availablePercent: 3).percent == 97)
        #expect(MemoryPressure(levelValue: 0, availablePercent: 150).percent == 0)
    }

    @Test func diskStatisticsDictionaries() throws {
        let statistics: [String: Any] = [
            "Bytes (Read)": NSNumber(value: 37_088_198_656 as UInt64),
            "Bytes (Write)": NSNumber(value: 16_651_067_392 as UInt64),
            "Operations (Read)": NSNumber(value: 1_336_703),
            "Operations (Write)": NSNumber(value: 658_894),
            "Latency Time (Read)": NSNumber(value: 1),
        ]
        let counters = try #require(DiskCounters(statistics: statistics))
        #expect(counters == DiskCounters(bytesRead: 37_088_198_656, bytesWritten: 16_651_067_392, reads: 1_336_703, writes: 658_894))
        #expect(DiskCounters(statistics: ["Operations (Read)": NSNumber(value: 1)]) == nil)
        let later = DiskCounters(bytesRead: 37_088_198_656 + 4096, bytesWritten: 16_651_067_392, reads: 1_336_704, writes: 658_894)
        #expect(later.added(since: counters) == DiskCounters(bytesRead: 4096, reads: 1))
        // An ejected and reattached disk starts again from zero.
        #expect(DiskCounters(bytesRead: 10).added(since: counters) == DiskCounters())
    }

    @Test func onlyPhysicalInterfacesCount() {
        let traffic = TrafficBytes(received: 100, sent: 10)
        let interfaces = [
            InterfaceCounters(name: "lo0", type: 0x18, flags: 0x8049, bytes: traffic, packets: traffic),
            InterfaceCounters(name: "en0", type: 0x06, flags: 0x8863, bytes: traffic, packets: traffic),
            InterfaceCounters(name: "utun5", type: 0x01, flags: 0x8051, bytes: traffic, packets: traffic),
            InterfaceCounters(name: "bridge0", type: 0xD1, flags: 0x8863, bytes: traffic, packets: traffic),
            InterfaceCounters(name: "pdp_ip0", type: 0xFF, flags: 0x8051, bytes: traffic, packets: traffic),
        ]
        #expect(interfaces.filter(\.countsTowardTotals).map(\.name) == ["en0", "pdp_ip0"])
        #expect(InterfaceCounters.totals(interfaces).bytes == TrafficBytes(received: 200, sent: 20))
    }

    @Test func interfacesAddPerInterfaceAndIgnoreResets() {
        func en(_ name: String, _ received: UInt64) -> InterfaceCounters {
            let bytes = TrafficBytes(received: received, sent: 0)
            return InterfaceCounters(name: name, type: 6, flags: 0, bytes: bytes, packets: bytes)
        }
        let added = InterfaceCounters.added(since: [en("en0", 1000), en("en1", 500)], now: [en("en0", 1600), en("en1", 20), en("en7", 900)])
        #expect(added.bytes.received == 600)
    }

    @Test func gpuAndBatteryDescriptions() throws {
        let gpu = try #require(GPUReading(name: "Apple M4 Pro", performanceStatistics: ["Device Utilization %": NSNumber(value: 22)]))
        #expect(gpu.utilization == 22)
        #expect(GPUReading(name: "x", performanceStatistics: ["Tiler Utilization %": NSNumber(value: 1)]) == nil)

        let charged: [String: Any] = [
            "Type": "InternalBattery", "Is Present": true, "Current Capacity": NSNumber(value: 100), "Max Capacity": NSNumber(value: 100),
            "Is Charging": false, "Is Charged": true, "Power Source State": "AC Power", "Time to Empty": NSNumber(value: 0),
        ]
        let battery = try #require(BatteryReading(description: charged))
        #expect(battery == BatteryReading(percent: 100, isCharging: false, isCharged: true, onBattery: false, minutesRemaining: nil))
        #expect(battery.stateTitle == "Charged")

        var draining = charged
        draining["Power Source State"] = "Battery Power"
        draining["Is Charged"] = false
        draining["Current Capacity"] = NSNumber(value: 62)
        draining["Time to Empty"] = NSNumber(value: 251)
        let onBattery = try #require(BatteryReading(description: draining))
        #expect(onBattery.minutesRemaining == 251)
        #expect(onBattery.stateTitle == "62 %, on battery")
        draining["Time to Empty"] = NSNumber(value: -1)
        #expect(BatteryReading(description: draining)?.minutesRemaining == nil)
        #expect(BatteryReading(description: ["Type": "UPS", "Current Capacity": NSNumber(value: 50)]) == nil)
    }

    @Test func coreTypesFallBackToEfficiencyCoresFirst() {
        let types = CoreType.fallback(levels: [("Performance", 2), ("Efficiency", 1)], total: 3)
        #expect(types == [.efficiency, .performance, .performance])
        #expect(CoreType.fallback(levels: [("Performance", 8)], total: 8) == Array(repeating: .standard, count: 8))
        #expect(CoreType.fallback(levels: [("Performance", 8), ("Efficiency", 4)], total: 10).allSatisfy { $0 == .standard })
        #expect(CoreType(clusterType: "E") == .efficiency)
    }
}
