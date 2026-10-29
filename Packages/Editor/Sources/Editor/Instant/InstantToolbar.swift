import AppKit
import SharedUI

/// Instant Capture's compact toolbar (PLAN §17), on the floating chrome's glass: the drawing tools, the colour and
/// width, undo and redo, then Upload (when there is somewhere to upload to), Save, Open in Editor, Copy and Close.
final class InstantToolbar: NSView {
    /// The tools Instant Capture offers, in toolbar order: select, then the drawing tools of the brief.
    static let tools: [EditorTool] = [.select, .pen, .arrow, .line, .rectangle, .ellipse, .highlighter, .text, .counter, .blur, .pixelate]

    private let background = Material.make(cornerRadius: 10)
    private var toolButtons: [EditorTool: InstantToolButton] = [:]
    let colorButton: InstantColorButton
    private let undoButton: InstantToolButton
    private let redoButton: InstantToolButton

    /// - Parameters:
    ///   - showsUpload: whether an upload destination is set up.
    ///   - selectTool: picks a tool. `showStyle`: opens the colour and width popover from the view given.
    ///   - perform: runs an action.
    init(
        showsUpload: Bool,
        selectTool: @escaping @MainActor (EditorTool) -> Void,
        showStyle: @escaping @MainActor (NSView) -> Void,
        perform: @escaping @MainActor (InstantAction) -> Void
    ) {
        colorButton = InstantColorButton(handler: showStyle)
        undoButton = InstantToolButton(symbol: "arrow.uturn.backward", label: "Undo", help: "Undo (⌘Z)") { perform(.undo) }
        redoButton = InstantToolButton(symbol: "arrow.uturn.forward", label: "Redo", help: "Redo (⇧⌘Z)") { perform(.redo) }
        super.init(frame: .zero)
        var views: [NSView] = []
        for tool in Self.tools {
            let button = InstantToolButton(symbol: tool.symbolName, label: tool.title, help: tool.help) { selectTool(tool) }
            toolButtons[tool] = button
            views.append(button)
        }
        views += [Self.separator(), colorButton, Self.separator(), undoButton, redoButton, Self.separator()]
        if showsUpload {
            views.append(InstantToolButton(symbol: "icloud.and.arrow.up", label: "Upload") { perform(.upload) })
        }
        views += [
            InstantToolButton(symbol: "square.and.arrow.down", label: "Save", help: "Save (⌘S)") { perform(.save) },
            InstantToolButton(symbol: "arrow.up.forward.app", label: "Open in Editor", help: "Open in Editor (⌘E)") {
                perform(.openInEditor)
            },
            InstantToolButton(symbol: "doc.on.doc", label: "Copy", help: "Copy and close (⌘C or Return)") { perform(.copy) },
            InstantToolButton(symbol: "xmark", label: "Close", help: "Close (Esc)") { perform(.close) },
        ]
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        background.contentView.addSubview(stack)
        background.translatesAutoresizingMaskIntoConstraints = false
        addSubview(background)
        // Padding as constraints: a horizontal stack's own insets do not count towards its fitting height.
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.contentView.leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: background.contentView.trailingAnchor, constant: -6),
            stack.topAnchor.constraint(equalTo: background.contentView.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: background.contentView.bottomAnchor, constant: -4),
            background.leadingAnchor.constraint(equalTo: leadingAnchor),
            background.trailingAnchor.constraint(equalTo: trailingAnchor),
            background.topAnchor.constraint(equalTo: topAnchor),
            background.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        setFrameSize(fittingSize)
        setAccessibilityElement(true)
        setAccessibilityRole(.toolbar)
        setAccessibilityLabel("Instant Capture tools")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Shows the session's tool, colour and undo state.
    func update(tool: EditorTool, color: RGBAColor, canUndo: Bool, canRedo: Bool) {
        for (each, button) in toolButtons {
            button.isChosen = each == tool
        }
        colorButton.color = color
        undoButton.isEnabled = canUndo
        redoButton.isEnabled = canRedo
    }

    private static func separator() -> NSView {
        let box = NSBox()
        box.boxType = .separator
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(equalToConstant: 1).isActive = true
        box.heightAnchor.constraint(equalToConstant: 18).isActive = true
        return box
    }
}
