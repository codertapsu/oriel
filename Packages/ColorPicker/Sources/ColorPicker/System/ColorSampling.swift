/// Picks a color off the screen. A seam, so tests hand in a fake and never start the system loupe.
protocol ColorSampling: AnyObject {
    /// Shows the loupe and returns the color the user clicked, or nil when they cancelled it.
    func sample() async -> ColorValue?
}
