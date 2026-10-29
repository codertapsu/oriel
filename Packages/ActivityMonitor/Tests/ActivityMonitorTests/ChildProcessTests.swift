@testable import ActivityMonitor
import Darwin
import Foundation
import Testing

/// Running tools and signalling processes, only ever with children this test starts itself.
struct ChildProcessTests {
    @Test func aToolsOutputAndStatus() async throws {
        let result = try await CommandRunner.run(URL(fileURLWithPath: "/bin/echo"), ["hello", "world"])
        #expect(result.status == 0)
        #expect(result.text == "hello world\n")
        let failing = try await CommandRunner.run(URL(fileURLWithPath: "/bin/ls"), ["/nonexistent-\(UUID().uuidString)"])
        #expect(failing.status != 0)
        #expect(!failing.errorText.isEmpty)
    }

    @Test func aToolThatOutlivesItsTimeoutIsStopped() async {
        let clock = ContinuousClock()
        let started = clock.now
        await #expect(throws: (any Error).self) {
            try await CommandRunner.run(URL(fileURLWithPath: "/bin/sleep"), ["30"], timeout: .milliseconds(300))
        }
        #expect(clock.now - started < .seconds(5))
    }

    @Test func cancellingTheTaskStopsTheTool() async {
        let clock = ContinuousClock()
        let started = clock.now
        let task = Task {
            try await CommandRunner.run(URL(fileURLWithPath: "/bin/sleep"), ["30"], timeout: .seconds(60))
        }
        try? await Task.sleep(for: .milliseconds(200))
        task.cancel()
        _ = await task.result
        #expect(clock.now - started < .seconds(5))
    }

    @Test @MainActor func quittingAChildWithASignal() throws {
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/bin/sleep")
        child.arguments = ["30"]
        try child.run()
        defer {
            if child.isRunning {
                child.terminate()
            }
        }
        let basics = try #require(ProcessTable.basics(of: child.processIdentifier))
        let target = SignalTarget(
            identity: basics.identity,
            name: "sleep",
            command: basics.command,
            uid: basics.uid,
            user: "me",
            isApp: false,
            isZombie: false
        )
        let policy = SignalPolicy(ownPID: getpid(), myUID: geteuid())
        #expect(policy.decide(.quit, for: target) == .send(.terminate))
        // A target whose start time no longer matches (a reused pid) is left alone.
        let stale = SignalTarget(
            identity: ProcessIdentity(pid: basics.pid, startTime: basics.startTime + 1),
            name: "sleep",
            command: basics.command,
            uid: basics.uid,
            user: "me",
            isApp: false,
            isZombie: false
        )
        #expect(ProcessController.perform(.send(.terminate), on: stale) == .failed("“sleep” has already quit."))
        #expect(child.isRunning)
        #expect(ProcessController.perform(policy.decide(.quit, for: target), on: target) == .done)
        child.waitUntilExit()
        #expect(child.terminationReason == .uncaughtSignal)
        #expect(child.terminationStatus == SIGTERM)
    }

    @Test @MainActor func protectedPIDsAreNeverSignalled() {
        for pid: Int32 in [-1, 0, 1] {
            let target = SignalTarget(
                identity: ProcessIdentity(pid: pid, startTime: 0),
                name: "x",
                command: "x",
                uid: geteuid(),
                user: "me",
                isApp: false,
                isZombie: false
            )
            #expect(ProcessController.perform(.send(.kill), on: target) == .failed("That process cannot be signalled."))
        }
    }
}
