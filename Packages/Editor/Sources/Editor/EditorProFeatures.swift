import OrielCore

/// What only Oriel Pro unlocks in the editor (PLAN §19). Arrows, lines, shapes, the pen, the highlighter, text, crop,
/// blur and pixelate, and PNG and JPEG export stay free.
public extension ProFeature {
    nonisolated static let smartRedact = ProFeature(
        id: "editor.smartRedact",
        title: "Smart Redact",
        summary: "Find keys, card numbers, email addresses and more in a screenshot and blur them in one step.",
        module: .editor
    )
    nonisolated static let simplify = ProFeature(
        id: "editor.simplify",
        title: "Simplify",
        summary: "Turn every line of text into a bar, for a clean diagram.",
        module: .editor
    )
    nonisolated static let smartMove = ProFeature(
        id: "editor.smartMove",
        title: "Smart Move",
        summary: "Lift text and objects out of a screenshot to move or delete them.",
        module: .editor
    )
    nonisolated static let backgrounds = ProFeature(
        id: "editor.backgrounds",
        title: "Backgrounds",
        summary: "Padding, gradients, your desktop picture, window frames and the sizes social networks ask for.",
        module: .editor
    )
    nonisolated static let numberedSteps = ProFeature(
        id: "editor.steps",
        title: "Numbered steps",
        summary: "Steps that number themselves, in shapes and styles, with pointers.",
        module: .editor
    )
    nonisolated static let spotlight = ProFeature(
        id: "editor.spotlight",
        title: "Spotlight",
        summary: "Dim everything around what matters.",
        module: .editor
    )
    nonisolated static let editorDocuments = ProFeature(
        id: "editor.documents",
        title: "Editable documents, HEIC and PDF",
        summary: "Save .oriel files you can edit again, and export HEIC and PDF.",
        module: .editor
    )

    /// The editor's Pro features, in the order Settings → Oriel Pro lists them.
    nonisolated static let editorFeatures: [ProFeature] = [
        .smartRedact, .simplify, .smartMove, .backgrounds, .numberedSteps, .spotlight, .editorDocuments,
    ]
}
