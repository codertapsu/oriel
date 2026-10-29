@testable import ActivityMonitor
import Foundation
import Testing

struct TopReportTests {
    private var processes: [ProcessMetrics] {
        var writer = Fixtures.process(3, name: "writer", cpu: 1, memory: 10)
        writer.diskWrittenPerSecond = 9_000_000
        var downloader = Fixtures.process(4, name: "downloader", cpu: 2, memory: 20)
        downloader.network = TrafficRate(received: 5_000_000, sent: 100)
        return [
            Fixtures.process(1, name: "idle", cpu: 0, memory: 5),
            Fixtures.process(2, name: "WindowServer", uid: 88, cpu: 40, realMemory: 900_000_000),
            writer,
            downloader,
            Fixtures.process(5, name: "kernel_task", parent: 0, uid: 0),
        ]
    }

    private var system: SystemMetrics {
        var system = SystemMetrics()
        system.processCount = 5
        system.cpu = CPULoad(user: 0.123, system: 0.045)
        system.memory = MemoryBreakdown(physical: 1000, app: 100, wired: 50, compressed: 50, cached: 300, swapUsed: 0, swapTotal: 0)
        system.pressure = MemoryPressure(level: .normal, percent: 40)
        return system
    }

    @Test func eachSortRanksItsOwnMetric() {
        func top(_ sort: TopSort) -> [Int32] {
            TopReport(processes: processes, system: system, sort: sort, limit: 2, seconds: 1).processes.map(\.pid)
        }
        #expect(top(.cpu) == [2, 4])
        #expect(top(.memory) == [2, 4])
        #expect(top(.disk) == [3, 2])
        #expect(top(.network) == [4, 2])
        #expect(TopReport(processes: processes, system: system, sort: .cpu, limit: 0, seconds: 1).processes.count == 1)
    }

    @Test func theTableHasAHeaderAndARowPerProcess() {
        let report = TopReport(processes: processes, system: system, sort: .cpu, limit: 3, seconds: 1.02)
        let lines = report.text.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines[0].contains("5 processes"))
        #expect(lines[0].contains("12.3 % user"))
        #expect(lines[2].hasPrefix("   PID"))
        #expect(lines[2].hasSuffix("NAME"))
        #expect(lines.count == 6)
        #expect(lines[3].hasSuffix("WindowServer"))
        #expect(lines[3].contains("40.0"))
        let disk = TopReport(processes: processes, system: system, sort: .disk, limit: 1, seconds: 1).text
        #expect(disk.contains("only for your own processes"))
    }

    @Test func jsonLeavesOutWhatMacOSDoesNotShare() throws {
        let report = TopReport(processes: processes, system: system, sort: .cpu, limit: 5, seconds: 1.0049)
        let document = try JSONDecoder().decode(TopReport.Document.self, from: Data(report.json().utf8))
        #expect(document == report.document)
        #expect(document.sort == "cpu")
        #expect(document.seconds == 1)
        #expect(document.system.cpuUser == 12.3)
        #expect(document.processes.first?.name == "WindowServer")
        #expect(document.processes.first?.memory == nil)
        #expect(document.processes.first?.realMemory == 900_000_000)
        let json = try report.json()
        #expect(!json.contains("null"))
    }
}
