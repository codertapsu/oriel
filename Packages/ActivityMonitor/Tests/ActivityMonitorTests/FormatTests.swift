@testable import ActivityMonitor
import Foundation
import Testing

/// How numbers read, and the command lines that feed the details.
struct FormatTests {
    let posix = ActivityFormat.posix

    @Test func cpuTimeReadsAsActivityMonitorWritesIt() {
        #expect(ActivityFormat.cpuTime(4_210_000_000, locale: posix) == "4.21")
        #expect(ActivityFormat.cpuTime(723_270_000_000, locale: posix) == "12:03.27")
        #expect(ActivityFormat.cpuTime(7_269_800_000_000, locale: posix) == "2:01:09.80")
        #expect(ActivityFormat.cpuTime(5_000_000, locale: posix) == "0.00")
        #expect(ActivityFormat.cpuTime(723_270_000_000, locale: Locale(identifier: "de_DE")) == "12:03,27")
        #expect(ActivityFormat.cpuTime(nil) == ActivityFormat.dash)
    }

    @Test func percentagesRatesAndPower() {
        #expect(ActivityFormat.percent(12.345, locale: posix) == "12.3")
        #expect(ActivityFormat.percent(12.345, locale: Locale(identifier: "fr_FR")) == "12,3")
        #expect(ActivityFormat.percent(1234.5, locale: posix) == "1234.5")
        #expect(ActivityFormat.percent(nil) == ActivityFormat.dash)
        #expect(ActivityFormat.percent(.nan) == ActivityFormat.dash)
        #expect(ActivityFormat.percentWithSign(5, locale: posix) == "5.0 %")
        #expect(ActivityFormat.rate(0.2) == "0")
        #expect(ActivityFormat.rate(2_000_000, locale: posix) == "2 MB/s")
        #expect(ActivityFormat.rate(nil) == ActivityFormat.dash)
        #expect(ActivityFormat.power(0.35, locale: posix) == "350 mW")
        #expect(ActivityFormat.power(1.25, locale: posix) == "1.25 W")
        #expect(ActivityFormat.power(0.0001) == "0")
        #expect(ActivityFormat.perSecond(2.25, locale: posix) == "2.2" || ActivityFormat.perSecond(2.25, locale: posix) == "2.3")
        #expect(ActivityFormat.perSecond(42.4, locale: posix) == "42")
        #expect(ActivityFormat.perSecond(0, locale: posix) == "0")
        #expect(ActivityFormat.decimal(2.134, locale: posix) == "2.13")
        #expect(ActivityFormat.count(1, "process", "processes", locale: posix) == "1 process")
        #expect(ActivityFormat.count(1200, "process", "processes", locale: posix) == "1200 processes")
        #expect(ActivityFormat.minutes(72) == "1 h 12 min")
        #expect(ActivityFormat.bytes(0, locale: posix) == "0 bytes")
        #expect(ActivityFormat.memory(0, locale: posix) == "0 bytes")
        #expect(ActivityFormat.memory(nil) == ActivityFormat.dash)
    }

    @Test func memoryUsesBinaryUnitsAndDataDecimalOnes() {
        let gib: UInt64 = 1 << 30
        #expect(ActivityFormat.memory(gib, locale: posix) == "1 GB")
        #expect(ActivityFormat.bytes(gib, locale: posix) == "1.07 GB")
    }

    /// `KERN_PROCARGS2`: argc, the path, NUL padding, the arguments, then the environment, which is never read.
    @Test func commandLinesComeFromProcargs() throws {
        var bytes: [UInt8] = []
        withUnsafeBytes(of: Int32(3).littleEndian) { bytes += $0 }
        bytes += Array("/usr/local/bin/node".utf8) + [0, 0, 0, 0]
        for argument in ["node", "server.js", "--port=8080"] {
            bytes += Array(argument.utf8) + [0]
        }
        bytes += Array("API_TOKEN=secret".utf8) + [0]
        let commandLine = try #require(ProcessCommandLine(procargs: bytes))
        #expect(commandLine.executable == "/usr/local/bin/node")
        #expect(commandLine.arguments == ["node", "server.js", "--port=8080"])
        #expect(!commandLine.arguments.joined().contains("secret"))
    }

    @Test func brokenProcargsAreRejectedOrCut() {
        #expect(ProcessCommandLine(procargs: [1, 0]) == nil)
        var negative: [UInt8] = []
        withUnsafeBytes(of: Int32(-5)) { negative += $0 }
        #expect(ProcessCommandLine(procargs: negative + [0x2F, 0]) == nil)
        var short: [UInt8] = []
        withUnsafeBytes(of: Int32(4)) { short += $0 }
        short += Array("/bin/sh".utf8) + [0] + Array("sh".utf8)
        #expect(ProcessCommandLine(procargs: short)?.arguments == ["sh"])
    }

    @Test func openFileStates() {
        #expect(OpenFile.tcpState(4) == "Established")
        #expect(OpenFile.tcpState(1) == "Listening")
        #expect(OpenFile.tcpState(99) == nil)
    }

    @Test func signaturesSummarise() {
        let chrome = CodeSignatureInfo(
            authority: .developerID,
            identifier: "com.google.Chrome",
            teamID: "EQHXZ8M8AV",
            signer: "Developer ID Application: Google LLC (EQHXZ8M8AV)",
            isSandboxed: false,
            hasHardenedRuntime: true
        )
        #expect(chrome.summary == "Developer ID · Google LLC (EQHXZ8M8AV)")
        let numbers = CodeSignatureInfo(
            authority: .appStore,
            identifier: "com.apple.iWork.Numbers",
            teamID: "74J34U3R6X",
            signer: "Apple Mac OS Application Signing",
            isSandboxed: true,
            hasHardenedRuntime: true
        )
        #expect(numbers.summary == "Mac App Store · Team 74J34U3R6X")
    }
}
