/// The panel's three tabs, in order; ⌘1…⌘3 switch between them.
enum ColorPanelTab: Int, CaseIterable {
    case color
    case palettes
    case contrast

    var title: String {
        switch self {
        case .color: "Color"
        case .palettes: "Palettes"
        case .contrast: "Contrast"
        }
    }
}
