/// One core's load over the last interval, for the per-core strip.
nonisolated struct CoreLoad: Sendable, Equatable, Codable {
    let type: CoreType
    let load: CPULoad
}
