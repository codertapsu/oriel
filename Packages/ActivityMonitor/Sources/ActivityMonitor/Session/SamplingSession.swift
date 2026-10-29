import Foundation

/// Samples while Activity Monitor's window is open, and only then (CLAUDE.md rule 3): a loop that sleeps for the
/// interval between samples and stops when the window closes, leaving nothing running.
///
/// The sleep is the only repeating wait in Oriel outside recording and scrolling capture, which is why this file is
/// named `…Session.swift` (the `no_polling` lint rule exempts it). It wakes early when what the window shows changes,
/// and lets macOS shift a wake by a tenth of the interval, so it can be grouped with other work.
final class SamplingSession {
    let sampler: ActivitySampler
    private(set) var interval: Duration
    /// Asked before every sample, so the sample follows the window's tab and view.
    private let request: () -> SampleRequest
    private let deliver: (ActivitySnapshot) -> Void
    private var loop: Task<Void, Never>?
    private var nap: Task<Void, Never>?
    /// A wake that came while a sample was being read: the next sample follows at once.
    private var wakeRequested = false
    /// A shorter wait for the next sample only, so rates appear quickly after opening or switching tabs.
    private var nextDelay: Duration?

    init(
        interval: Duration,
        historyCapacity: Int,
        request: @escaping () -> SampleRequest,
        deliver: @escaping (ActivitySnapshot) -> Void
    ) {
        self.interval = interval
        sampler = ActivitySampler(historyCapacity: historyCapacity)
        self.request = request
        self.deliver = deliver
    }

    var isRunning: Bool {
        loop != nil
    }

    /// Samples at once, again after a second, then every interval.
    func start() {
        guard loop == nil else { return }
        nextDelay = .seconds(1)
        // Utility, so macOS may run the reading on efficiency cores; only the views wait for the main thread.
        loop = Task(priority: .utility) { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let snapshot = await sampler.sample(request())
                guard !Task.isCancelled else { return }
                deliver(snapshot)
                await pause()
            }
        }
    }

    /// Stops sampling; the loop ends at its next step and any `ps` or `nettop` it started is terminated.
    func stop() {
        loop?.cancel()
        loop = nil
        nap?.cancel()
        nap = nil
    }

    /// Samples now rather than at the end of the interval, then once more after `followUp` if given, so a tab that
    /// needs two samples for its rates fills in quickly.
    func wake(followUp: Duration? = nil) {
        nextDelay = followUp
        if let nap {
            nap.cancel()
        } else {
            wakeRequested = true
        }
    }

    func setInterval(_ newInterval: Duration) {
        guard newInterval != interval else { return }
        interval = newInterval
        wake()
    }

    private func pause() async {
        if wakeRequested {
            wakeRequested = false
            return
        }
        let delay = nextDelay ?? interval
        nextDelay = nil
        let tolerance = delay / 10
        let nap = Task {
            _ = try? await Task.sleep(for: delay, tolerance: tolerance)
        }
        self.nap = nap
        await nap.value
        self.nap = nil
    }
}
