import CoreGraphics

/// What one display's overlay draws, in global points: built from the session by `RulerSceneBuilder`, drawn by
/// `RulerCanvasView`. Pure values, so what each mode shows is tested without a window.
nonisolated struct RulerScene: Equatable, Sendable {
    /// A measuring line, drawn with a short tick across each end.
    struct Segment: Equatable, Sendable {
        var from: CGPoint
        var to: CGPoint
    }

    struct GuideLine: Equatable, Sendable {
        var orientation: Guide.Orientation
        var position: CGFloat
        var isSelected = false
        /// The guide a click would add, drawn dashed.
        var isPreview = false
    }

    /// A number on the screen, in a dark badge.
    struct Label: Equatable, Sendable {
        enum Style: Equatable, Sendable {
            /// The main measurement, with an optional second line.
            case primary
            /// A distance along a line.
            case secondary
        }

        enum Placement: Equatable, Sendable {
            /// Centered on the anchor.
            case center
            /// Below and to the right of the anchor, as beside a pointer.
            case beside
            /// Centered below the anchor, flipping above it at the screen's edge.
            case below
        }

        var text: String
        var detail: String?
        var anchor: CGPoint
        var placement: Placement
        var style: Style
    }

    var area: CGRect?
    var showsHandles = false
    /// Thin lines across the whole display through this point.
    var crosshair: CGPoint?
    var segments: [Segment] = []
    /// The box between the edges around the pointer, in Dimensions.
    var measuredBox: CGRect?
    var pinnedBox: CGRect?
    /// A box being drawn to fit.
    var fitBox: CGRect?
    var guides: [GuideLine] = []
    var labels: [Label] = []
    /// A card in the middle of the display, such as why Dimensions cannot find edges.
    var notice: RulerNotice?
}
