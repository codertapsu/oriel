@testable import ActivityMonitor
import Testing

struct HeavyConsumerDetectorTests {
    /// One 2-second sample after another.
    private func run(_ detector: inout HeavyConsumerDetector, _ samples: [[ProcessMetrics]]) -> [[ProcessIdentity: HeavyFlags]] {
        samples.enumerated().map { index, processes in
            detector.update(processes, from: Fixtures.time(Double(index) * 2), to: Fixtures.time(Double(index + 1) * 2))
        }
    }

    @Test func cpuMustStayOverTheLimitForTheWholeDuration() {
        var detector = HeavyConsumerDetector(thresholds: HeavyThresholds(cpuPercent: 80, seconds: 10))
        let busy = Fixtures.process(42, cpu: 95)
        let results = run(&detector, Array(repeating: [busy], count: 6))
        // 2, 4, 6, 8 s are not enough; at 10 s it counts.
        #expect(results.prefix(4).allSatisfy { $0[busy.id] == nil })
        #expect(results[4][busy.id] == .cpu)
        #expect(results[5][busy.id] == .cpu)
    }

    @Test func dippingBelowStartsTheWaitAgain() {
        var detector = HeavyConsumerDetector(thresholds: HeavyThresholds(cpuPercent: 80, seconds: 4))
        let busy = Fixtures.process(42, cpu: 95)
        let calm = Fixtures.process(42, cpu: 20)
        let unknown = Fixtures.process(42, cpu: nil)
        let results = run(&detector, [[busy], [busy], [calm], [busy], [unknown], [busy], [busy]])
        #expect(results[1][busy.id] == .cpu)
        #expect(results[2][busy.id] == nil)
        #expect(results[3][busy.id] == nil)
        #expect(results[5][busy.id] == nil)
        #expect(results[6][busy.id] == .cpu)
    }

    @Test func memoryCountsAtOnceAndUsesRealMemoryForOthers() {
        var detector = HeavyConsumerDetector(thresholds: HeavyThresholds(memoryBytes: 2_000_000_000))
        let large = Fixtures.process(1, memory: 3_000_000_000)
        let otherUsers = Fixtures.process(2, uid: 0, realMemory: 2_500_000_000)
        let small = Fixtures.process(3, memory: 100)
        let flags = detector.update([large, otherUsers, small], from: 0, to: Fixtures.time(2))
        #expect(flags[large.id] == .memory)
        #expect(flags[otherUsers.id] == .memory)
        #expect(flags[small.id] == nil)
    }

    @Test func diskAndNetworkRatesAreWatchedToo() {
        var detector = HeavyConsumerDetector(thresholds: HeavyThresholds(seconds: 2, diskBytesPerSecond: 10, networkBytesPerSecond: 10))
        var process = Fixtures.process(5)
        process.diskWrittenPerSecond = 50
        process.network = TrafficRate(received: 6, sent: 6)
        let flags = detector.update([process], from: 0, to: Fixtures.time(2))
        #expect(flags[process.id] == [.disk, .network])
    }

    @Test func endedProcessesAreForgotten() {
        var detector = HeavyConsumerDetector(thresholds: HeavyThresholds(cpuPercent: 50, seconds: 4))
        let busy = Fixtures.process(42, cpu: 99)
        _ = detector.update([busy], from: 0, to: Fixtures.time(2))
        _ = detector.update([], from: Fixtures.time(2), to: Fixtures.time(4))
        let flags = detector.update([busy], from: Fixtures.time(4), to: Fixtures.time(6))
        #expect(flags[busy.id] == nil)
    }
}
