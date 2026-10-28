/// Virtual key codes Oriel refers to by name (Carbon's `kVK_*`, which is layout-independent), and the labels
/// shortcuts are displayed with.
public enum KeyCode {
    public static let returnKey: UInt16 = 36
    public static let tab: UInt16 = 48
    public static let space: UInt16 = 49
    public static let delete: UInt16 = 51
    public static let escape: UInt16 = 53
    public static let forwardDelete: UInt16 = 117
    public static let leftArrow: UInt16 = 123
    public static let rightArrow: UInt16 = 124
    public static let downArrow: UInt16 = 125
    public static let upArrow: UInt16 = 126
    public static let grave: UInt16 = 50

    public static let ansiQ: UInt16 = 12
    public static let ansiW: UInt16 = 13
    public static let ansiF: UInt16 = 3
    public static let ansiM: UInt16 = 46
    public static let ansiH: UInt16 = 4
    public static let ansiT: UInt16 = 17
    public static let ansiR: UInt16 = 15
    public static let ansiA: UInt16 = 0
    public static let ansiS: UInt16 = 1
    public static let ansi1: UInt16 = 18
    public static let ansi2: UInt16 = 19
    public static let ansi3: UInt16 = 20
    public static let ansi4: UInt16 = 21
    public static let ansi5: UInt16 = 23
    public static let ansi6: UInt16 = 22
    public static let ansi7: UInt16 = 26
    public static let ansi8: UInt16 = 28
    public static let ansi9: UInt16 = 25

    /// The digit keys 1…9, in order, for "jump to item N".
    public static let digits: [UInt16] = [ansi1, ansi2, ansi3, ansi4, ansi5, ansi6, ansi7, ansi8, ansi9]

    /// A short label for `code` on a US layout. Unknown codes show as `key 99`.
    public static func name(for code: UInt16) -> String {
        names[code] ?? "key \(code)"
    }

    private static let names: [UInt16: String] = [
        0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G", 4: "H", 34: "I", 38: "J", 40: "K", 37: "L",
        46: "M", 45: "N", 31: "O", 35: "P", 12: "Q", 15: "R", 1: "S", 17: "T", 32: "U", 9: "V", 13: "W", 7: "X",
        16: "Y", 6: "Z",
        29: "0", 18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7", 28: "8", 25: "9",
        27: "-", 24: "=", 33: "[", 30: "]", 42: "\\", 41: ";", 39: "'", 43: ",", 47: ".", 44: "/", 50: "`",
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋", 117: "⌦", 115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9",
        109: "F10", 103: "F11", 111: "F12",
    ]
}
