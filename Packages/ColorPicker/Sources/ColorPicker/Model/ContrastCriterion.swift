/// One WCAG 2.2 contrast requirement: text (SC 1.4.3 at AA, 1.4.6 at AAA) and user-interface components and graphics
/// (SC 1.4.11, AA only). Large text is at least 18 pt (24 CSS px), or 14 pt (about 18.7 px) bold.
nonisolated enum ContrastCriterion: CaseIterable, Sendable {
    case normalTextAA
    case normalTextAAA
    case largeTextAA
    case largeTextAAA
    case userInterfaceAA

    enum Use: CaseIterable, Sendable {
        case normalText
        case largeText
        case userInterface

        var title: String {
            switch self {
            case .normalText: "Normal text"
            case .largeText: "Large text"
            case .userInterface: "UI components"
            }
        }
    }

    enum Level: CaseIterable, Sendable {
        case aa
        case aaa

        var title: String {
            switch self {
            case .aa: "AA"
            case .aaa: "AAA"
            }
        }
    }

    /// The ratio the colors must reach. WCAG compares the exact ratio, so 4.499:1 does not pass 4.5:1.
    var minimum: Double {
        switch self {
        case .normalTextAA: 4.5
        case .normalTextAAA: 7
        case .largeTextAA: 3
        case .largeTextAAA: 4.5
        case .userInterfaceAA: 3
        }
    }

    var use: Use {
        switch self {
        case .normalTextAA, .normalTextAAA: .normalText
        case .largeTextAA, .largeTextAAA: .largeText
        case .userInterfaceAA: .userInterface
        }
    }

    var level: Level {
        switch self {
        case .normalTextAA, .largeTextAA, .userInterfaceAA: .aa
        case .normalTextAAA, .largeTextAAA: .aaa
        }
    }

    /// The criterion for a use and level; none for AAA user-interface components, which WCAG does not define.
    static func criterion(for use: Use, level: Level) -> ContrastCriterion? {
        allCases.first { $0.use == use && $0.level == level }
    }

    func isMet(by ratio: Double) -> Bool {
        ratio >= minimum
    }
}
