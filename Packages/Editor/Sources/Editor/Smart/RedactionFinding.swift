import CoreGraphics

/// A place Smart Redact would hide: what was found there and its padded box in image space. The text itself is not
/// kept.
nonisolated struct RedactionFinding: Sendable, Equatable {
    let category: RedactionCategory
    let rect: CGRect
}
