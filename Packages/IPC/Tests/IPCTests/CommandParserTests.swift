import Foundation
import IPC
import OrielCore
import Testing

struct CommandParserTests {
    private func request(_ arguments: [String]) throws -> (IPCRequest, TimeInterval) {
        guard case let .request(request, timeout) = try CommandParser.parse(arguments) else {
            Issue.record("expected a request")
            return (IPCRequest(verb: ""), 0)
        }
        return (request, timeout)
    }

    @Test func helpAndVersion() throws {
        #expect(try CommandParser.parse([]) == .help)
        #expect(try CommandParser.parse(["--help"]) == .help)
        #expect(try CommandParser.parse(["--version"]) == .version)
    }

    @Test func nounAndVerbBecomeADottedVerbWithOptions() throws {
        let (list, listTimeout) = try request(["windows", "list", "--json", "--space", "current"])
        #expect(list.verb == "windows.list")
        #expect(list.flag("json"))
        #expect(list.options["space"] == "current")
        #expect(listTimeout == 30)

        let (focus, _) = try request(["windows", "focus", "4242"])
        #expect(focus.arguments == ["4242"])
    }

    @Test func interactiveCommandsWaitLongerUnlessARectIsGiven() throws {
        #expect(try request(["capture", "area"]).1 == 600)
        #expect(try request(["capture", "area", "--rect", "100,100,400,300", "--to", "file"]).1 == 30)
        #expect(try request(["translate", "area", "--timeout", "5"]).1 == 5)
    }

    @Test func aDelayedCaptureWaitsForItsCountdownToo() throws {
        let (delayed, timeout) = try request(["capture", "area", "--rect", "100,100,400,300", "--delay", "5"])
        #expect(delayed.options["delay"] == "5")
        #expect(timeout == 35)
        #expect(try request(["capture", "window", "--delay", "10"]).1 == 610)
    }

    @Test func aScriptedRecordingWaitsForItsLengthAndTheSave() throws {
        let (record, timeout) = try request(["debug", "record", "--seconds", "10", "--pause-at", "3", "--resume-at", "5"])
        #expect(record.verb == "debug.record")
        #expect(record.options == ["seconds": "10", "pause-at": "3", "resume-at": "5"])
        #expect(timeout == 70)
        #expect(try request(["debug", "perf-capture", "--runs", "20", "--json"]).0.options == ["runs": "20", "json": "true"])
        #expect(try request(["debug", "clipboard", "--json"]).0.verb == "debug.clipboard")
    }

    @Test func topIsAOneWordCommand() throws {
        let (top, timeout) = try request(["top", "--sort", "memory", "--limit", "5", "--json"])
        #expect(top.verb == "top")
        #expect(top.options == ["sort": "memory", "limit": "5", "json": "true"])
        #expect(timeout == 30)
        #expect(try request(["top"]).0.verb == "top")
    }

    @Test(arguments: [
        ["frobnicate"], ["windows"], ["top", "--bogus"], ["top", "--limit"], ["windows", "explode"], ["windows", "list", "--bogus"], [
            "windows",
            "focus",
            "--title",
        ],
        ["capture", "area", "--rect", "1,2,3"], ["capture", "area", "--delay", "0"], ["capture", "area", "--delay", "61"],
        ["capture", "area", "--delay", "2.5"], ["capture", "screen", "--delay"],
    ])
    func badInputIsAUsageError(_ arguments: [String]) {
        #expect(throws: CommandParser.ParseError.self) { try CommandParser.parse(arguments) }
    }

    @Test func rectsParse() {
        #expect(CommandParser.parseRect("100, 100, 400, 300") == CGRect(x: 100, y: 100, width: 400, height: 300))
        #expect(CommandParser.parseRect("0,0,0,10") == nil)
    }
}
