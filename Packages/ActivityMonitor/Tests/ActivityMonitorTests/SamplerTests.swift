@testable import ActivityMonitor
import Darwin
import Foundation
import Testing

/// The sampler and the session on this Mac. `ps` and nettop only read process information. Serialized, so the cost
/// measurement sees only its own samples.
@Suite(.serialized)
struct SamplerTests {
    @Test func twoSamplesGiveRatesForThisProcess() async throws {
        let sampler = ActivitySampler(historyCapacity: 10)
        let request = SampleRequest(sources: [.devices])
        let first = await sampler.sample(request)
        #expect(first.interval == nil)
        #expect(first.processes.contains { $0.pid == getpid() })
        try await Task.sleep(for: .milliseconds(300))
        let second = await sampler.sample(request)
        let me = try #require(second.processes.first { $0.pid == getpid() })
        #expect(me.cpuPercent != nil)
        #expect(me.isMine)
        #expect(me.memory != nil)
        #expect(second.interval != nil)
        #expect(second.system.cpu != nil)
        #expect(second.system.memory != nil)
        #expect(second.system.disk != nil)
        #expect(second.system.network != nil)
        #expect(second.history.values(.cpuUser).count == 2)
        // Without ps, other users' processes are listed but not measured.
        let launchd = try #require(second.processes.first { $0.pid == 1 })
        #expect(launchd.cpuPercent == nil)
        #expect(launchd.user == "root")
    }

    @Test func psMeasuresOtherUsersProcesses() async throws {
        let sampler = ActivitySampler(historyCapacity: 10)
        let request = SampleRequest(sources: [.otherUsers])
        _ = await sampler.sample(request)
        try await Task.sleep(for: .milliseconds(500))
        let snapshot = await sampler.sample(request)
        #expect(snapshot.sources.contains(.otherUsers))
        let launchd = try #require(snapshot.processes.first { $0.pid == 1 })
        #expect(launchd.realMemory != nil)
        #expect(launchd.cpuTime != nil)
        #expect(launchd.cpuPercent != nil)
        #expect(launchd.status != nil)
    }

    @Test func nettopGivesTrafficRates() async throws {
        let sampler = ActivitySampler(historyCapacity: 10)
        let request = SampleRequest(sources: [.network])
        _ = await sampler.sample(request)
        try await Task.sleep(for: .milliseconds(500))
        let snapshot = await sampler.sample(request)
        #expect(snapshot.sources.contains(.network))
        // Every process gets a rate once nettop ran twice, zero for the quiet ones.
        #expect(snapshot.processes.allSatisfy { $0.network != nil })
        #expect(snapshot.processes.allSatisfy { $0.networkTotal != nil })
    }

    /// The budget: well under 1 % of a core at a 2-second interval, `ps` included.
    @Test func aSampleIsCheap() async {
        let sampler = ActivitySampler(historyCapacity: 10)
        let request = SampleRequest(sources: [.devices, .otherUsers])
        _ = await sampler.sample(request)
        let before = Self.cpuSeconds()
        let runs = 5
        for _ in 0 ..< runs {
            _ = await sampler.sample(request)
        }
        let perSample = (Self.cpuSeconds() - before) / Double(runs)
        // 1 % of a core at 2 s is 20 ms; the machine may be busy, so this checks the order of magnitude.
        #expect(perSample < 0.020, "a sample cost \(perSample * 1000) ms of CPU")
    }

    @Test @MainActor func theSessionSamplesUntilItIsStopped() async throws {
        var delivered = 0
        let session = SamplingSession(
            interval: .milliseconds(100),
            historyCapacity: 10,
            request: { SampleRequest(sources: []) },
            deliver: { _ in delivered += 1 }
        )
        session.start()
        #expect(session.isRunning)
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(10)
        while delivered < 3, clock.now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        #expect(delivered >= 3)
        session.stop()
        #expect(!session.isRunning)
        let stopped = delivered
        try await Task.sleep(for: .milliseconds(400))
        // At most the sample that was already being read when it stopped.
        #expect(delivered <= stopped + 1)
    }

    /// The test process's own CPU time plus its finished children's (ps and nettop).
    private static func cpuSeconds() -> Double {
        var own = rusage()
        var children = rusage()
        getrusage(RUSAGE_SELF, &own)
        getrusage(RUSAGE_CHILDREN, &children)
        func seconds(_ value: timeval) -> Double {
            Double(value.tv_sec) + Double(value.tv_usec) / 1_000_000
        }
        return seconds(own.ru_utime) + seconds(own.ru_stime) + seconds(children.ru_utime) + seconds(children.ru_stime)
    }
}
