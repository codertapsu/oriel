/// J, K and L, the way video editors use them (PLAN §17): L plays forward and each further L doubles the speed,
/// J does the same backwards, K stops, and Space plays or stops. Pure: it only says which rate to play at.
nonisolated struct Shuttle: Equatable, Sendable {
    /// The speeds J and L step through.
    static let speeds: [Double] = [1, 2, 4, 8]

    /// The playback rate: 0 stopped, negative backwards.
    private(set) var rate: Double = 0

    /// L: forward at normal speed, or faster when already playing forward.
    mutating func forward() {
        rate = rate > 0 ? Self.next(after: rate) : 1
    }

    /// J: backward at normal speed, or faster when already playing backward.
    mutating func reverse() {
        rate = rate < 0 ? -Self.next(after: -rate) : -1
    }

    /// K.
    mutating func stop() {
        rate = 0
    }

    /// Space: plays forward at normal speed when stopped, stops otherwise.
    mutating func toggle() {
        rate = rate == 0 ? 1 : 0
    }

    /// Follows the player when something else changed its rate (it reached the end, say).
    mutating func follow(_ rate: Double) {
        self.rate = rate
    }

    private static func next(after speed: Double) -> Double {
        speeds.first { $0 > speed + 0.001 } ?? speeds[speeds.count - 1]
    }
}
