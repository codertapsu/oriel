import Foundation

/// Keeps the camera background effect within its budget (PLAN §9, §17). Pure, so its rules are tested without a
/// camera.
///
/// Person segmentation runs at most `rate` times a second; the frames in between reuse the last mask, which a
/// person in front of a webcam does not outrun. The effect turns itself off, for the rest of the recording, when
/// segmentation stays slower than `budget` (the Mac is busy), when the Mac runs hot, or in Low Power Mode: the
/// bubble then shows the camera as it is, which costs nothing.
nonisolated struct SegmentationGovernor: Equatable, Sendable {
    /// Segmentations per second, at most.
    static let rate = 15.0
    /// The longest a segmentation may take on average, in seconds.
    static let budget = 0.045
    /// Segmentations measured before the average is trusted; the first one also loads the model.
    static let warmUp = 5
    /// How much each new measurement moves the average.
    static let smoothing = 0.2

    /// Why the effect turned off, once it has.
    private(set) var stopReason: String?
    private var lastSegmentation: Double?
    private var averageCost: Double?
    private var measured = 0

    var isRunning: Bool {
        stopReason == nil
    }

    /// Whether the frame at `time` (seconds, any clock) should be segmented; if so, it counts as segmented.
    mutating func shouldSegment(at time: Double) -> Bool {
        guard isRunning else { return false }
        if let last = lastSegmentation, time - last < 1 / Self.rate - 0.002, time >= last {
            return false
        }
        lastSegmentation = time
        return true
    }

    /// Takes in how long a segmentation took, in seconds.
    mutating func record(cost: Double) {
        guard isRunning, cost.isFinite, cost >= 0 else { return }
        measured += 1
        guard measured > 1 else { return }
        averageCost = averageCost.map { $0 + (cost - $0) * Self.smoothing } ?? cost
        if measured > Self.warmUp, let averageCost, averageCost > Self.budget {
            stopReason = "segmentation took \(Int(averageCost * 1000)) ms a frame"
        }
    }

    /// Turns the effect off when the Mac runs hot or saves power.
    mutating func observe(thermalState: ProcessInfo.ThermalState, lowPowerMode: Bool) {
        guard isRunning else { return }
        if thermalState == .serious || thermalState == .critical {
            stopReason = "the Mac is running hot"
        } else if lowPowerMode {
            stopReason = "Low Power Mode is on"
        }
    }
}
