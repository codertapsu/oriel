import AVFoundation

/// Plays the movie of a video editor window (PLAN §17): an `AVPlayer` showing the zoom composition, with the
/// J/K/L shuttle, frame steps and the trim range, which playback stops at.
///
/// The playhead follows a periodic time observer, which AVFoundation calls while the movie plays and when time
/// jumps, never while it is paused (CLAUDE.md rule 3: no polling). `close()` must be called when the window
/// closes.
final class VideoEditorPlayback {
    let player: AVPlayer
    /// Called with the time whenever it changes.
    var onTime: ((Double) -> Void)?
    /// Called with the rate whenever playback starts, stops or changes speed.
    var onRateChange: ((Double) -> Void)?

    private let item: AVPlayerItem
    private let duration: Double
    private let frameDuration: Double
    private var shuttle = Shuttle()
    private var range: ClosedRange<Double>
    private var timeObserver: Any?
    private var rateObserver: NSObjectProtocol?

    init(info: MovieInfo) {
        let asset = AVURLAsset(url: info.url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        item = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: item)
        player.actionAtItemEnd = .pause
        duration = info.duration
        frameDuration = 1 / max(info.frameRate, 1)
        range = 0 ... info.duration
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 60), queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                self?.onTime?(time.seconds)
            }
        }
        rateObserver = NotificationCenter.default.addObserver(
            forName: AVPlayer.rateDidChangeNotification,
            object: player,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.rateDidChange()
            }
        }
    }

    /// Stops playback and the observers.
    func close() {
        player.pause()
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        if let rateObserver {
            NotificationCenter.default.removeObserver(rateObserver)
        }
        rateObserver = nil
        player.replaceCurrentItem(with: nil)
    }

    var currentTime: Double {
        let time = player.currentTime().seconds
        return time.isFinite ? min(max(time, 0), duration) : 0
    }

    var isPlaying: Bool {
        player.rate != 0
    }

    var rate: Double {
        Double(player.rate)
    }

    /// Shows the movie through `composition` (the zoom), redrawing the frame at once when paused.
    func setComposition(_ composition: AVVideoComposition?) {
        item.videoComposition = composition
        if !isPlaying {
            seek(to: currentTime)
        }
    }

    /// The part that playback keeps to: it stops at the end of it, and starting from outside it starts at its start.
    func setRange(_ range: ClosedRange<Double>) {
        self.range = range
        item.forwardPlaybackEndTime = range.upperBound < duration - 0.001 ? Self.time(range.upperBound) : .invalid
        item.reversePlaybackEndTime = range.lowerBound > 0.001 ? Self.time(range.lowerBound) : .invalid
    }

    /// Shows the frame at `time`: exactly, or, while scrubbing (`exact` false), a frame within a tenth of a second,
    /// which keeps up with the mouse.
    func seek(to time: Double, exact: Bool = true) {
        let clamped = min(max(time.isFinite ? time : 0, 0), duration)
        let tolerance = exact ? CMTime.zero : CMTime(value: 1, timescale: 10)
        player.seek(to: Self.time(clamped), toleranceBefore: tolerance, toleranceAfter: tolerance)
        onTime?(clamped)
    }

    /// Space.
    func togglePlayback() {
        if isPlaying {
            shuttle.stop()
        } else {
            shuttle.toggle()
        }
        apply()
    }

    /// L.
    func forward() {
        shuttle.follow(rate)
        shuttle.forward()
        apply()
    }

    /// J.
    func reverse() {
        shuttle.follow(rate)
        shuttle.reverse()
        apply()
    }

    /// K.
    func stop() {
        shuttle.stop()
        apply()
    }

    /// ← and →: pauses and moves by whole frames of the movie's frame rate.
    func step(frames: Int) {
        stop()
        let frame = (currentTime / frameDuration).rounded()
        seek(to: (frame + Double(frames)) * frameDuration)
    }

    func step(seconds: Double) {
        stop()
        seek(to: currentTime + seconds)
    }

    private func apply() {
        var rate = shuttle.rate
        if rate < 0, !item.canPlayReverse {
            rate = 0
        } else if rate > 2, !item.canPlayFastForward {
            rate = 2
        } else if rate < -1, !item.canPlayFastReverse {
            rate = -1
        }
        shuttle.follow(rate)
        let now = currentTime
        if rate > 0, now >= range.upperBound - 0.01 || now < range.lowerBound {
            seek(to: range.lowerBound)
        } else if rate < 0, now <= range.lowerBound + 0.01 || now > range.upperBound {
            seek(to: range.upperBound)
        }
        player.rate = Float(rate)
    }

    private func rateDidChange() {
        shuttle.follow(rate)
        onRateChange?(rate)
    }

    private static func time(_ seconds: Double) -> CMTime {
        CMTime(seconds: seconds, preferredTimescale: 60000)
    }
}
