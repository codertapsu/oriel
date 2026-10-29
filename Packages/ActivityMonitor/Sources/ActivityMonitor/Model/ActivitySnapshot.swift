import Foundation

/// One sample, computed and ready to show: what the sampler hands the window each interval.
nonisolated struct ActivitySnapshot: Sendable {
    let date: Date
    /// Seconds the rates cover; nil for the first sample, which has none.
    let interval: Double?
    let processes: [ProcessMetrics]
    let system: SystemMetrics
    let history: HistorySnapshot
    /// The selected process's history, when the request named one.
    let selectedHistory: ProcessHistorySnapshot?
    let sources: SampleSources
}
