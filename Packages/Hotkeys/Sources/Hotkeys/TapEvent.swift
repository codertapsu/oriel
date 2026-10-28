import CoreGraphics
import OrielCore

/// One event from the switcher's event tap, reduced to what its state machine needs.
public enum TapEvent: Sendable, Equatable {
    case keyDown(keyCode: UInt16, modifiers: KeyCombo.Modifiers, isRepeat: Bool)
    case keyUp(keyCode: UInt16, modifiers: KeyCombo.Modifiers)
    case flagsChanged(modifiers: KeyCombo.Modifiers)
    /// A trackpad gesture frame: every finger touching right now.
    case gesture(touches: [TouchSample])
    case leftMouseDown(location: CGPoint)
}

/// One finger on the trackpad.
public struct TouchSample: Sendable, Equatable {
    /// Stable for the life of the touch.
    public let identity: Int
    /// 0…1 across the trackpad, origin bottom-left.
    public let position: CGPoint
    public let isResting: Bool

    public init(identity: Int, position: CGPoint, isResting: Bool) {
        self.identity = identity
        self.position = position
        self.isResting = isResting
    }
}

/// What the tap does with an event after the handler has seen it.
public enum TapDecision: Sendable {
    case pass
    case consume
}
