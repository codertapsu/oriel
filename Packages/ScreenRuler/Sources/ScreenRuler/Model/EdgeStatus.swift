/// Whether Dimensions can find edges, which takes a still screenshot of each display.
nonisolated enum EdgeStatus: Equatable, Sendable {
    /// Screen Recording is not granted, so there is no screenshot to read.
    case notPermitted
    /// The screenshots are being taken and read.
    case reading
    case ready
    /// The screenshot failed; the reason, for the hint.
    case failed(String)
}
