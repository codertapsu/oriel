import OrielCore

public extension FeatureGuide {
    /// The editor's page in the feature tour (PLAN §19).
    nonisolated static let editor = FeatureGuide(
        id: ModuleID.editor.rawValue,
        title: "Editor",
        symbol: "pencil.and.outline",
        summary: "Annotate a capture with arrows, shapes, text and highlights, hide what is private, then copy or export "
            + "it. Choose Annotate after a capture, or open any image.",
        highlights: [
            Highlight("Annotate", "Arrows, lines, shapes, pen, highlighter and text, each a single key away."),
            Highlight("Blur and pixelate", "Hide anything by hand, and crop to what matters."),
            Highlight(
                "Smart Redact",
                "Finds keys, card numbers, email addresses, phone numbers and links in the text and blurs them in one "
                    + "step, on this Mac.",
                pro: .smartRedact
            ),
            Highlight("Simplify", "Turns every line of text into a bar, for a clean diagram.", pro: .simplify),
            Highlight("Smart Move", "Lift text and objects out of a screenshot to move or delete them.", pro: .smartMove),
            Highlight(
                "Backgrounds",
                "Padding, gradients, pictures, window frames and shadows, at the sizes social networks ask for.",
                pro: .backgrounds
            ),
            Highlight("Numbered steps", "Click to number the steps of a how-to; they renumber themselves.", pro: .numberedSteps),
            Highlight("Spotlight", "Dim everything but what matters.", pro: .spotlight),
            Highlight(
                "Documents and formats",
                "Save editable .oriel documents and export HEIC or PDF. PNG and JPEG are free.",
                pro: .editorDocuments
            ),
        ],
        commandID: "openImage"
    )
}
