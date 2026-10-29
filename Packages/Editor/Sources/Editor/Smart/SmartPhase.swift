/// Where a smart tool's review is: not started, reading the image, showing what it found, or stopped by an error.
nonisolated enum SmartPhase: Sendable, Equatable {
    case idle
    case working
    case ready
    case failed(String)
}
