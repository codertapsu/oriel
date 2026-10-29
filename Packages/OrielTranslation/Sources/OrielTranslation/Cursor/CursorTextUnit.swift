/// How much text Translate Under Cursor takes from under the pointer.
enum CursorTextUnit: String, Codable, Sendable, CaseIterable, Identifiable {
    /// The line under the pointer only, for menus, buttons and tables.
    case line
    /// The paragraph the line belongs to, which reads better for running text. The default.
    case paragraph

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .line: "Line"
        case .paragraph: "Paragraph"
        }
    }
}
