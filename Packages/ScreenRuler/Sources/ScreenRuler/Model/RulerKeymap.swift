import OrielCore

/// The ruler's keys. Letters and brackets are read from the characters they type, so `U`, `[` and `]` work on any
/// layout; Tab, Return, Esc, Space, Delete and the arrows by their key codes.
nonisolated enum RulerKeymap {
    static let keypadEnter: UInt16 = 76

    static func key(code: UInt16, modifiers: KeyCombo.Modifiers, characters: String?) -> RulerKey? {
        let command = modifiers.contains(.command)
        let shift = modifiers.contains(.shift)
        switch code {
        case KeyCode.tab:
            return shift ? .previousMode : .nextMode
        case KeyCode.escape:
            return .exit
        case KeyCode.returnKey, keypadEnter:
            return .confirm
        case KeyCode.space:
            return .flipGuide
        case KeyCode.delete, KeyCode.forwardDelete:
            return command ? .deleteAll : .delete
        case KeyCode.leftArrow, KeyCode.rightArrow, KeyCode.upArrow, KeyCode.downArrow:
            let step = shift ? 10 : 1
            let (dx, dy) = switch code {
            case KeyCode.leftArrow: (-step, 0)
            case KeyCode.rightArrow: (step, 0)
            case KeyCode.upArrow: (0, -step)
            default: (0, step)
            }
            return .arrow(dx: dx, dy: dy, resizes: modifiers.contains(.option))
        default:
            break
        }
        let text = (characters ?? "").lowercased()
        if command {
            return text == "c" || code == KeyCode.ansiC ? .copy : nil
        }
        switch text {
        case "[", "{": return .tolerance(delta: shift || text == "{" ? -5 : -1)
        case "]", "}": return .tolerance(delta: shift || text == "}" ? 5 : 1)
        case "u": return .toggleUnit
        case "h": return .guideOrientation(.horizontal)
        case "v": return .guideOrientation(.vertical)
        default: break
        }
        if let digit = Int(text), let mode = RulerMode.allCases.first(where: { $0.number == digit }) {
            return .mode(mode)
        }
        return nil
    }
}
