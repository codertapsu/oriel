import AppKit
import SharedUI

/// One step in the sequence window: its number, thumbnail, editable title and note, where it came from, and buttons
/// to retake, annotate and delete it. Titles and notes are saved as they are typed.
final class StepRowView: NSTableCellView, NSTextFieldDelegate {
    static let identifier = NSUserInterfaceItemIdentifier("StepRow")
    static let height: CGFloat = 132
    static let thumbnailSize = CGSize(width: 184, height: 112)
    /// Three lines of the note's font.
    static let noteHeight: CGFloat = 46

    var onTitleChange: ((String) -> Void)?
    var onNoteChange: ((String) -> Void)?
    var onRetake: (() -> Void)?
    var onAnnotate: (() -> Void)?
    var onDelete: (() -> Void)?

    private let badge = StepNumberBadge()
    private let thumbnail = StepThumbnailView()
    private let titleField = NSTextField()
    private let noteField = NSTextField()
    private let caption = NSTextField(labelWithString: "")
    private var annotateButton: HUDButton?

    override init(frame: CGRect) {
        super.init(frame: frame)
        identifier = Self.identifier
        build()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func configure(step: Step, number: Int, thumbnail image: CGImage?, canAnnotate: Bool) {
        badge.number = number
        thumbnail.show(image, pixelSize: CGSize(width: step.pixelWidth, height: step.pixelHeight), click: step.click, scale: step.scale)
        if titleField.currentEditor() == nil {
            titleField.stringValue = step.title
        }
        if noteField.currentEditor() == nil {
            noteField.stringValue = step.note
        }
        titleField.placeholderString = "Step \(number)"
        titleField.setAccessibilityLabel("Title of step \(number)")
        noteField.setAccessibilityLabel("Note for step \(number)")
        let source = [step.appName, step.windowTitle].compactMap(\.self).first { !$0.isEmpty }
        let parts = [source, step.date.formatted(date: .omitted, time: .shortened), "\(step.pixelWidth) × \(step.pixelHeight)"]
        caption.stringValue = parts.compactMap(\.self).joined(separator: " · ")
        annotateButton?.isHidden = !canAnnotate
    }

    /// A thumbnail that arrived after the row was set up; the title and note are left alone, as they may be edited.
    func showThumbnail(_ image: CGImage?, of step: Step) {
        thumbnail.show(image, pixelSize: CGSize(width: step.pixelWidth, height: step.pixelHeight), click: step.click, scale: step.scale)
    }

    func controlTextDidChange(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }
        if field === titleField {
            onTitleChange?(field.stringValue)
        } else if field === noteField {
            onNoteChange?(field.stringValue)
        }
    }

    /// Return in the title moves on to the note; in the note it ends editing (⌥Return starts a new line).
    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard selector == #selector(NSResponder.insertNewline(_:)) else { return false }
        if control === titleField {
            window?.makeFirstResponder(noteField)
        } else {
            window?.makeFirstResponder(nil)
        }
        return true
    }

    private func build() {
        titleField.font = .systemFont(ofSize: 13, weight: .semibold)
        titleField.isBordered = false
        titleField.drawsBackground = false
        titleField.focusRingType = .exterior
        titleField.lineBreakMode = .byTruncatingTail
        titleField.delegate = self
        noteField.font = .systemFont(ofSize: 12)
        noteField.textColor = .secondaryLabelColor
        noteField.placeholderString = "Add a note"
        noteField.isBordered = false
        noteField.drawsBackground = false
        noteField.focusRingType = .exterior
        noteField.usesSingleLineMode = false
        noteField.cell?.wraps = true
        noteField.cell?.isScrollable = false
        noteField.cell?.truncatesLastVisibleLine = true
        noteField.lineBreakMode = .byWordWrapping
        noteField.maximumNumberOfLines = 3
        noteField.delegate = self
        caption.font = .systemFont(ofSize: 11)
        caption.textColor = .tertiaryLabelColor
        caption.lineBreakMode = .byTruncatingMiddle

        let retake = HUDButton(symbol: "camera.viewfinder", label: "Retake") { [weak self] in self?.onRetake?() }
        let annotate = HUDButton(symbol: "pencil.tip.crop.circle", label: "Annotate") { [weak self] in self?.onAnnotate?() }
        let delete = HUDButton(symbol: "trash", label: "Delete") { [weak self] in self?.onDelete?() }
        for button in [retake, annotate, delete] {
            button.contentTintColor = .secondaryLabelColor
        }
        annotateButton = annotate
        let buttons = NSStackView(views: [retake, annotate, delete])
        buttons.spacing = 2

        let text = NSStackView(views: [titleField, noteField, caption])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 4
        text.setCustomSpacing(6, after: noteField)

        for view in [badge, thumbnail, text, buttons] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        titleField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        noteField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        NSLayoutConstraint.activate([
            badge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            badge.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            badge.widthAnchor.constraint(equalToConstant: StepNumberBadge.diameter),
            badge.heightAnchor.constraint(equalToConstant: StepNumberBadge.diameter),
            thumbnail.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 12),
            thumbnail.centerYAnchor.constraint(equalTo: centerYAnchor),
            thumbnail.widthAnchor.constraint(equalToConstant: Self.thumbnailSize.width),
            thumbnail.heightAnchor.constraint(equalToConstant: Self.thumbnailSize.height),
            text.leadingAnchor.constraint(equalTo: thumbnail.trailingAnchor, constant: 16),
            text.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            text.trailingAnchor.constraint(equalTo: buttons.leadingAnchor, constant: -12),
            titleField.widthAnchor.constraint(equalTo: text.widthAnchor),
            noteField.widthAnchor.constraint(equalTo: text.widthAnchor),
            // Room for three lines, so every row's caption sits at the same height.
            noteField.heightAnchor.constraint(equalToConstant: Self.noteHeight),
            caption.widthAnchor.constraint(lessThanOrEqualTo: text.widthAnchor),
            buttons.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            buttons.topAnchor.constraint(equalTo: topAnchor, constant: 10),
        ])
    }
}
