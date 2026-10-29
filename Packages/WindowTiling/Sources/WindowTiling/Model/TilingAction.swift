import OrielCore

/// One thing Window Tiling does to the focused window of the app in front (PLAN §7.14): a half, a quarter, a third or two
/// thirds of its screen, maximize, almost maximize, maximize height, center, restore, another display, or one step
/// smaller or larger. Each action is a `ToolCommand` with a Rectangle-like default shortcut.
nonisolated enum TilingAction: String, CaseIterable, Codable, Sendable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeft, topRight, bottomLeft, bottomRight
    case firstThird, centerThird, lastThird
    case firstTwoThirds, lastTwoThirds
    case maximize, almostMaximize, maximizeHeight
    case center
    case smaller, larger
    case nextDisplay, previousDisplay
    case restore

    /// The command's stable id. The shortcut is stored under `shortcuts.<id>`, so these never change.
    var commandID: String {
        switch self {
        case .leftHalf: "tileLeftHalf"
        case .rightHalf: "tileRightHalf"
        case .topHalf: "tileTopHalf"
        case .bottomHalf: "tileBottomHalf"
        case .topLeft: "tileTopLeft"
        case .topRight: "tileTopRight"
        case .bottomLeft: "tileBottomLeft"
        case .bottomRight: "tileBottomRight"
        case .firstThird: "tileFirstThird"
        case .centerThird: "tileCenterThird"
        case .lastThird: "tileLastThird"
        case .firstTwoThirds: "tileFirstTwoThirds"
        case .lastTwoThirds: "tileLastTwoThirds"
        case .maximize: "tileMaximize"
        case .almostMaximize: "tileAlmostMaximize"
        case .maximizeHeight: "tileMaximizeHeight"
        case .center: "tileCenter"
        case .smaller: "tileSmaller"
        case .larger: "tileLarger"
        case .nextDisplay: "tileNextDisplay"
        case .previousDisplay: "tilePreviousDisplay"
        case .restore: "tileRestore"
        }
    }

    /// The name in the menu and in Settings → Shortcuts.
    var title: String {
        switch self {
        case .leftHalf: "Left Half"
        case .rightHalf: "Right Half"
        case .topHalf: "Top Half"
        case .bottomHalf: "Bottom Half"
        case .topLeft: "Top Left"
        case .topRight: "Top Right"
        case .bottomLeft: "Bottom Left"
        case .bottomRight: "Bottom Right"
        case .firstThird: "First Third"
        case .centerThird: "Center Third"
        case .lastThird: "Last Third"
        case .firstTwoThirds: "First Two Thirds"
        case .lastTwoThirds: "Last Two Thirds"
        case .maximize: "Maximize"
        case .almostMaximize: "Almost Maximize"
        case .maximizeHeight: "Maximize Height"
        case .center: "Center"
        case .smaller: "Make Smaller"
        case .larger: "Make Larger"
        case .nextDisplay: "Next Display"
        case .previousDisplay: "Previous Display"
        case .restore: "Restore"
        }
    }

    /// An SF Symbol for the command. The menu draws its own glyphs for the layouts (`LayoutGlyph`).
    var symbol: String {
        switch self {
        case .leftHalf: "rectangle.lefthalf.inset.filled"
        case .rightHalf: "rectangle.righthalf.inset.filled"
        case .topHalf: "rectangle.tophalf.inset.filled"
        case .bottomHalf: "rectangle.bottomhalf.inset.filled"
        case .topLeft: "rectangle.inset.topleft.filled"
        case .topRight: "rectangle.inset.topright.filled"
        case .bottomLeft: "rectangle.inset.bottomleft.filled"
        case .bottomRight: "rectangle.inset.bottomright.filled"
        case .firstThird: "rectangle.leadingthird.inset.filled"
        case .centerThird: "rectangle.center.inset.filled"
        case .lastThird: "rectangle.trailingthird.inset.filled"
        case .firstTwoThirds: "rectangle.leadinghalf.inset.filled"
        case .lastTwoThirds: "rectangle.trailinghalf.inset.filled"
        case .maximize: "rectangle.inset.filled"
        case .almostMaximize: "macwindow"
        case .maximizeHeight: "rectangle.expand.vertical"
        case .center: "inset.filled.center.rectangle"
        case .smaller: "arrow.down.right.and.arrow.up.left.rectangle"
        case .larger: "arrow.up.left.and.arrow.down.right.rectangle"
        case .nextDisplay: "rectangle.righthalf.inset.filled.arrow.right"
        case .previousDisplay: "rectangle.lefthalf.inset.filled.arrow.left"
        case .restore: "arrow.uturn.backward.square"
        }
    }

    /// Rectangle's defaults: ⌃⌥ with an arrow, a letter, Return, Delete, - or =; ⌃⌥⌘ with an arrow for displays.
    var defaultShortcut: KeyCombo? {
        let base: KeyCombo.Modifiers = [.control, .option]
        let key: UInt16
        var modifiers = base
        switch self {
        case .leftHalf: key = KeyCode.leftArrow
        case .rightHalf: key = KeyCode.rightArrow
        case .topHalf: key = KeyCode.upArrow
        case .bottomHalf: key = KeyCode.downArrow
        case .topLeft: key = KeyCode.ansiU
        case .topRight: key = KeyCode.ansiI
        case .bottomLeft: key = KeyCode.ansiJ
        case .bottomRight: key = KeyCode.ansiK
        case .firstThird: key = KeyCode.ansiD
        case .centerThird: key = KeyCode.ansiF
        case .lastThird: key = KeyCode.ansiG
        case .firstTwoThirds: key = KeyCode.ansiE
        case .lastTwoThirds: key = KeyCode.ansiT
        case .maximize: key = KeyCode.returnKey
        case .almostMaximize: return nil
        case .maximizeHeight:
            key = KeyCode.upArrow
            modifiers.insert(.shift)
        case .center: key = KeyCode.ansiC
        case .smaller: key = KeyCode.ansiMinus
        case .larger: key = KeyCode.ansiEqual
        case .nextDisplay:
            key = KeyCode.rightArrow
            modifiers.insert(.command)
        case .previousDisplay:
            key = KeyCode.leftArrow
            modifiers.insert(.command)
        case .restore: key = KeyCode.delete
        }
        return KeyCombo(keyCode: key, modifiers: modifiers)
    }

    /// Pressing it again on the window it just placed steps through ½, ⅔ and ⅓ of the screen, when that is turned on.
    var cyclesSizes: Bool {
        switch self {
        case .leftHalf, .rightHalf, .topHalf, .bottomHalf: true
        default: false
        }
    }

    /// Whether the action names a part of the screen whatever the window was like, so moving the window to another
    /// display can apply it there again.
    var isFixedLayout: Bool {
        switch self {
        case .leftHalf, .rightHalf, .topHalf, .bottomHalf, .topLeft, .topRight, .bottomLeft, .bottomRight, .firstThird,
             .centerThird, .lastThird, .firstTwoThirds, .lastTwoThirds, .maximize, .almostMaximize:
            true
        case .maximizeHeight, .center, .smaller, .larger, .nextDisplay, .previousDisplay, .restore:
            false
        }
    }

    /// The groups of the Window Tiling menu, separated by lines.
    static let menuSections: [[TilingAction]] = [
        [.leftHalf, .rightHalf, .topHalf, .bottomHalf],
        [.topLeft, .topRight, .bottomLeft, .bottomRight],
        [.firstThird, .centerThird, .lastThird, .firstTwoThirds, .lastTwoThirds],
        [.maximize, .almostMaximize, .maximizeHeight, .center],
        [.smaller, .larger],
        [.nextDisplay, .previousDisplay],
        [.restore],
    ]
}
