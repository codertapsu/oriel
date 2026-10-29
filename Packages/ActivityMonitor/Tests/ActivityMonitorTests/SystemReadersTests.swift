@testable import ActivityMonitor
import Darwin
import Foundation
import Testing

/// The readers against this Mac: the test process's own entry through libproc, and the Mac-wide counters. Nothing
/// here needs a permission or touches another process.
struct SystemReadersTests {
    @Test func theProcessTableListsThisProcessWithItsParentAndOwner() throws {
        let all = ProcessTable.all()
        #expect(all.count > 10)
        let me = try #require(all.first { $0.pid == getpid() })
        #expect(me.parentPID == getppid())
        #expect(me.uid == geteuid())
        #expect(me.startTime > 1_700_000_000_000_000)
        #expect(ProcessTable.basics(of: getpid()) == me)
        #expect(all.contains { $0.pid == 0 && $0.command == "kernel_task" })
        #expect(ProcessTable.path(of: getpid())?.isEmpty == false)
    }

    @Test func ownCountersComeFromRusage() throws {
        // Burn a little CPU so the counters have something to show.
        var value = 0.0
        for index in 0 ..< 200_000 {
            value += sin(Double(index))
        }
        #expect(value.isFinite)
        let me = try #require(ProcessTable.basics(of: getpid()))
        let counters = try #require(ProcessTable.counters(of: getpid(), kernelState: me.kernelState))
        #expect(counters.source == .usage)
        #expect((counters.cpuTime ?? 0) > 1_000_000)
        #expect((counters.footprint ?? 0) > 1_000_000)
        #expect((counters.residentSize ?? 0) > 1_000_000)
        #expect((counters.threads ?? 0) >= 1)
        #expect(counters.status == .running || counters.status == .sleeping)
    }

    @Test func machTicksBecomeNanoseconds() {
        #expect(MachTicks.frequency > 0)
        #expect(MachTicks.nanoseconds(MachTicks.frequency) == 1_000_000_000)
        #expect(MachTicks.nanoseconds(0) == 0)
        #expect(MachTicks.nanoseconds(.max) == .max || MachTicks.frequency >= 1_000_000_000)
    }

    @Test func ownCommandLineAndOpenFiles() throws {
        let commandLine = try #require(ProcessTable.commandLine(of: getpid()))
        #expect(!commandLine.executable.isEmpty)
        #expect(!commandLine.arguments.isEmpty)
        let files = try #require(OpenFileReader.openFiles(of: getpid()))
        #expect(files.contains { $0.descriptor <= 2 })
    }

    @Test func otherUsersDetailsAreNotRead() {
        // launchd is root's: macOS refuses its usage, arguments and descriptors to this user.
        #expect(ProcessTable.counters(of: 1, kernelState: 2) == nil)
        #expect(ProcessTable.commandLine(of: 1) == nil)
        #expect(OpenFileReader.openFiles(of: 1) == nil)
    }

    @Test func systemCountersAreReadable() throws {
        let cores = SystemStats.cores()
        #expect(cores.count == SystemStats.coreCount)
        let memory = try #require(SystemStats.memory())
        #expect(memory.pageSize == 4096 || memory.pageSize == 16384)
        #expect(SystemStats.physicalMemory > 1_000_000_000)
        #expect(SystemStats.pressure() != nil)
        #expect(SystemStats.loadAverage() != nil)
        let breakdown = MemoryBreakdown(
            counts: memory.counts,
            pageSize: memory.pageSize,
            physical: SystemStats.physicalMemory,
            swapUsed: 0,
            swapTotal: 0
        )
        #expect(breakdown.used > 0)
        #expect(breakdown.used <= breakdown.physical)
    }

    @Test func devicesAreReadable() {
        #expect(NetworkInterfaces.counters().contains { $0.name == "lo0" })
        #expect(!IORegistryReader.disks().isEmpty)
        if let types = IORegistryReader.coreTypes() {
            #expect(types.count == SystemStats.coreCount)
        }
        _ = IORegistryReader.gpus()
        _ = PowerReader.battery()
        _ = PowerReader.sleepAssertions()
        #expect(PowerReader.preventsSleep("PreventUserIdleSystemSleep"))
        #expect(!PowerReader.preventsSleep("UserIsActive"))
    }

    @Test func signaturesOfSystemBinaries() {
        let ls = CodeSignatureReader.signature(atPath: "/bin/ls")
        #expect(ls.authority == .apple)
        #expect(ls.identifier == "com.apple.ls")
        #expect(CodeSignatureReader.signature(atPath: "/nonexistent/binary").authority == .invalid)
    }

    @Test func userNames() {
        #expect(UserDirectory.name(of: 0) == "root")
        #expect(!UserDirectory.name(of: geteuid()).isEmpty)
        #expect(UserDirectory.name(of: 4_000_000_000) == "4000000000")
    }

    @Test func sampleReportsAreNamedForFinder() {
        let date = Date(timeIntervalSince1970: 1_793_300_000)
        let name = SampleReport.fileName(for: "a/b:c", pid: 42, at: date)
        #expect(name.hasPrefix("a-b-c-42-"))
        #expect(name.hasSuffix(".txt"))
        #expect(SampleReport.arguments(pid: 42, file: URL(fileURLWithPath: "/tmp/x.txt")) == ["42", "3", "-file", "/tmp/x.txt"])
    }
}
