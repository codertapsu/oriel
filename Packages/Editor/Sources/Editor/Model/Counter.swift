import CoreGraphics
import Foundation

/// A numbered step marker: a filled circle or rounded square with its label, centred on `center` in image space, and
/// optionally a pointer whose tip is at `pointer`.
///
/// Markers of one `sequence` number themselves in the order they were placed; restarting the numbering starts a new
/// sequence, so deleting a step closes the gap only among its own sequence.
nonisolated struct Counter: Sendable, Equatable {
    var id: UUID
    var center: CGPoint
    var number: Int
    var color: RGBAColor
    var radius: CGFloat
    var shape: StepShape
    var label: StepLabel
    /// The pointer's tip in image space; nil draws no pointer.
    var pointer: CGPoint?
    /// The numbering group the marker belongs to.
    var sequence: Int

    init(
        id: UUID = UUID(),
        center: CGPoint,
        number: Int,
        color: RGBAColor,
        radius: CGFloat,
        shape: StepShape = .circle,
        label: StepLabel = .numbers,
        pointer: CGPoint? = nil,
        sequence: Int = 0
    ) {
        self.id = id
        self.center = center
        self.number = number
        self.color = color
        self.radius = radius
        self.shape = shape
        self.label = label
        self.pointer = pointer
        self.sequence = sequence
    }

    /// The body's square: the circle's bounding box, or the rounded square itself.
    var circleRect: CGRect {
        CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }

    /// What the marker shows: its number in its label style.
    var text: String {
        label.text(for: number)
    }

    /// Whether a pointer is drawn: a tip inside the body would not show.
    var showsPointer: Bool {
        showsPointer(farther: 1.05)
    }

    /// Whether the pointer's tip is more than `radii` radii from the centre.
    func showsPointer(farther radii: CGFloat) -> Bool {
        guard let pointer else { return false }
        return hypot(pointer.x - center.x, pointer.y - center.y) > radius * radii
    }
}

/// Documents saved before step styles existed have no shape, label, pointer or sequence: they read as numbered
/// circles in one sequence.
extension Counter: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, center, number, color, radius, shape, label, pointer, sequence
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: container.decode(UUID.self, forKey: .id),
            center: container.decode(CGPoint.self, forKey: .center),
            number: container.decode(Int.self, forKey: .number),
            color: container.decode(RGBAColor.self, forKey: .color),
            radius: container.decode(CGFloat.self, forKey: .radius),
            shape: container.decodeIfPresent(StepShape.self, forKey: .shape) ?? .circle,
            label: container.decodeIfPresent(StepLabel.self, forKey: .label) ?? .numbers,
            pointer: container.decodeIfPresent(CGPoint.self, forKey: .pointer),
            sequence: container.decodeIfPresent(Int.self, forKey: .sequence) ?? 0
        )
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(center, forKey: .center)
        try container.encode(number, forKey: .number)
        try container.encode(color, forKey: .color)
        try container.encode(radius, forKey: .radius)
        try container.encode(shape, forKey: .shape)
        try container.encode(label, forKey: .label)
        try container.encodeIfPresent(pointer, forKey: .pointer)
        try container.encode(sequence, forKey: .sequence)
    }
}
