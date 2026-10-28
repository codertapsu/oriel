/// How a capture was made.
public enum CaptureKind: String, Codable, Sendable {
    case area
    case window
    case screen
    case scrolling
    /// An image handed in from outside (a file, the CLI's `debug capture --fixture`).
    case imported
}
