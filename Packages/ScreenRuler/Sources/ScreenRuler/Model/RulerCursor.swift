/// The pointer shape the overlay should show where the pointer is.
nonisolated enum RulerCursor: Equatable, Sendable {
    case crosshair
    case resize(RulerHandle)
    case move
    case moving
    /// Over a guide, which drags sideways (vertical guide) or up and down.
    case guide(Guide.Orientation)
}
