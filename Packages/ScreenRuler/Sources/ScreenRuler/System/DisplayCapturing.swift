import CoreGraphics

/// Takes the still pictures Dimensions reads edges from. A seam, so tests and previews never capture the screen.
protocol DisplayCapturing: AnyObject {
    /// What each display shows now, without Oriel's own windows, at its native pixel size. A display that could not
    /// be captured is left out.
    func capture(_ displays: [RulerDisplay]) async throws -> [CGDirectDisplayID: CGImage]
}
