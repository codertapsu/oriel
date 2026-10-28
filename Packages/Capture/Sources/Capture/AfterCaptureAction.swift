/// What happens right after an interactive capture (Settings → Capture).
nonisolated enum AfterCaptureAction: String, CaseIterable, Codable, Sendable, Identifiable {
    /// Show the Quick Access Overlay (PLAN §7.2, item 6).
    case quickAccess
    /// Copy the image to the clipboard.
    case copy
    /// Save it to the default folder with the filename template.
    case save
    /// Open it in the editor.
    case annotate

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .quickAccess: "Show Quick Access Overlay"
        case .copy: "Copy to Clipboard"
        case .save: "Save to Folder"
        case .annotate: "Open in Editor"
        }
    }
}
