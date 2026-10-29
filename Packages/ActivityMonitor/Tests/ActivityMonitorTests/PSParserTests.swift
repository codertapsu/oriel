@testable import ActivityMonitor
import Testing

struct PSParserTests {
    @Test(arguments: [
        ("0:32.15", 32_150_000_000),
        ("125:03.27", 7_503_270_000_000),
        ("2:01:09.80", 7_269_800_000_000),
        ("1-02:03:04.50", 93_784_500_000_000),
        ("0:00,07", 70_000_000),
        ("7", 7_000_000_000),
        ("0:01.5", 1_500_000_000),
    ] as [(String, UInt64)])
    func cpuTimesInEveryFormatPSUses(_ text: String, _ nanoseconds: UInt64) {
        #expect(PSParser.cpuTime(Substring(text)) == nanoseconds)
    }

    @Test(arguments: ["", "-", "1:2:3:4.00", "x:10.00", "1:10.x5", "1-", ":"])
    func malformedTimesAreRejected(_ text: String) {
        #expect(PSParser.cpuTime(Substring(text)) == nil)
    }

    @Test func linesBecomeRecordsByPID() {
        let output = """
            1   0:32.15  20720 Ss
          328   0:32.02  36112 R+
        88123 125:03.27 1048576 U
          999   0:00.00      0 Z
        """
        let records = PSParser.parse(output)
        #expect(records.count == 4)
        #expect(records[1] == PSParser.Record(cpuTime: 32_150_000_000, residentSize: 20720 * 1024, status: .sleeping))
        #expect(records[328]?.status == .running)
        #expect(records[88123]?.residentSize == 1_073_741_824)
        #expect(records[88123]?.status == .waiting)
        #expect(records[999]?.status == .zombie)
    }

    @Test func junkAndPartialLinesAreSkipped() {
        let output = """
          PID      TIME    RSS STAT
            0   0:01.00    100 S
           12   0:01.00
           13   bogus    100 S
           14   0:01.00    100
        """
        let records = PSParser.parse(output)
        #expect(records.keys.sorted() == [14])
        #expect(records[14]?.status == nil)
    }

    @Test func statesMapToStatuses() {
        #expect(ProcessStatus(psState: "Ss") == .sleeping)
        #expect(ProcessStatus(psState: "I") == .sleeping)
        #expect(ProcessStatus(psState: "R+") == .running)
        #expect(ProcessStatus(psState: "T") == .stopped)
        #expect(ProcessStatus(psState: "?") == nil)
        #expect(ProcessStatus(kernelState: 2, runningThreads: 1) == .running)
        #expect(ProcessStatus(kernelState: 2, runningThreads: 0) == .sleeping)
        #expect(ProcessStatus(kernelState: 4, runningThreads: 3) == .stopped)
        #expect(ProcessStatus(kernelState: 5, runningThreads: nil) == .zombie)
    }
}
