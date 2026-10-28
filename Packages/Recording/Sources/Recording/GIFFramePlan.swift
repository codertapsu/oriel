/// Which moments of a movie become GIF frames, how long each is shown and how large they are (PLAN §7.4). Pure.
///
/// GIF stores delays in whole centiseconds, so 12 fps cannot be 8.33 cs per frame. Each delay is the difference of
/// two rounded frame start times, which keeps the total exact (8, 8, 9, 8, 8, 9 … cs at 12 fps).
nonisolated struct GIFFramePlan: Equatable, Sendable {
    /// The longest GIF the exporter writes, in frames: five minutes at 10 fps. Longer GIFs take minutes to make and
    /// are too large to share, which is what GIFs are for.
    static let maximumFrameCount = 3000

    /// When each frame is sampled, in seconds from the start.
    let times: [Double]
    /// How long each frame is shown, in seconds, as multiples of 0.01.
    let delays: [Double]
    /// The GIF's width in pixels.
    let width: Int
    /// The GIF's height in pixels.
    let height: Int

    init(duration: Double, frameRate: Int, sourceWidth: Int, sourceHeight: Int, maxWidth: Int) {
        let rate = Double(max(frameRate, 1))
        let duration = duration.isFinite ? max(duration, 0) : 0
        // The epsilon keeps a 2.0 s movie at 10 fps at 20 frames instead of 21.
        let wanted = Int((duration * rate - 0.001).rounded(.up))
        let count = min(max(wanted, 1), Self.maximumFrameCount)
        times = (0 ..< count).map { Double($0) / rate }
        let starts = (0 ..< count).map { Int((Double($0) * 100 / rate).rounded()) }
        let end = max(Int((min(duration, Double(count) / rate) * 100).rounded()), (starts.last ?? 0) + 2)
        delays = (0 ..< count).map { index in
            let next = index + 1 < count ? starts[index + 1] : end
            return Double(max(next - starts[index], 2)) / 100
        }
        let sourceWidth = max(sourceWidth, 1)
        let sourceHeight = max(sourceHeight, 1)
        width = min(max(maxWidth, 1), sourceWidth)
        height = max(Int((Double(sourceHeight) * Double(width) / Double(sourceWidth)).rounded()), 1)
    }
}
