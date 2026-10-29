/// What Instant Capture's toolbar and keys do besides drawing.
nonisolated enum InstantAction: Sendable, Equatable {
    /// ⌘C or Return: copies the result and closes.
    case copy
    /// ⌘S: saves the result in the editor's export format, in a save panel.
    case save
    case upload
    /// ⌘E: opens the full editor with the annotations kept.
    case openInEditor
    /// Esc: closes without keeping anything.
    case close
    case undo
    case redo
}
