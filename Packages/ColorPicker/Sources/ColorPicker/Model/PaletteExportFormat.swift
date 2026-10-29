import UniformTypeIdentifiers

/// What a palette can be exported as.
nonisolated enum PaletteExportFormat: CaseIterable, Sendable {
    /// Names, HEX, the exact sRGB components and Display P3, for scripts and design tokens.
    case json
    /// `:root` custom properties, with Display P3 values for the colors sRGB cannot show.
    case css
    /// An Apple color list, which the system Colors panel and design apps open (`NSColorList`).
    case colorList

    var title: String {
        switch self {
        case .json: "JSON"
        case .css: "CSS Variables"
        case .colorList: "Color List (.clr)"
        }
    }

    var fileExtension: String {
        switch self {
        case .json: "json"
        case .css: "css"
        case .colorList: "clr"
        }
    }

    var contentType: UTType {
        switch self {
        case .json: .json
        case .css: UTType(filenameExtension: "css") ?? .plainText
        case .colorList: UTType(filenameExtension: "clr") ?? .data
        }
    }
}
