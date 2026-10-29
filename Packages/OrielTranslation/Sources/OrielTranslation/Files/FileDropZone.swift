import AppKit

/// What the file window shows before a file is open, or when a file cannot be translated: where to drop one, what
/// kinds work, and a button to choose one.
@MainActor
final class FileDropZone: NSView {
    private let symbol = NSImageView()
    private let title = NSTextField(labelWithString: "Drop a File to Translate")
    private let detail = NSTextField(wrappingLabelWithString: "")
    private let choose: NSButton

    static let kinds = "Images, PDFs, text and Markdown, Word and RTF documents, web pages, and SRT or WebVTT subtitles."

    init(choose action: @escaping @MainActor () -> Void) {
        choose = NSButton(title: "Choose File…", target: nil, action: nil)
        chooseAction = action
        super.init(frame: .zero)
        let configuration = NSImage.SymbolConfiguration(pointSize: 44, weight: .light)
        symbol.symbolConfiguration = configuration
        symbol.contentTintColor = .tertiaryLabelColor
        title.font = .systemFont(ofSize: 17, weight: .semibold)
        title.alignment = .center
        detail.alignment = .center
        detail.textColor = .secondaryLabelColor
        detail.font = .systemFont(ofSize: NSFont.systemFontSize)
        detail.preferredMaxLayoutWidth = 380
        choose.target = self
        choose.action = #selector(chooseFile)
        choose.bezelStyle = .push
        let stack = NSStackView(views: [symbol, title, detail, choose])
        stack.orientation = .vertical
        stack.spacing = 10
        stack.setCustomSpacing(16, after: detail)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            detail.widthAnchor.constraint(lessThanOrEqualToConstant: 380),
        ])
        show(problem: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private let chooseAction: @MainActor () -> Void

    /// The usual invitation, or why the dropped file cannot be translated.
    func show(problem: String?) {
        let name = problem == nil ? "arrow.down.doc" : "exclamationmark.triangle"
        symbol.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        title.stringValue = problem == nil ? "Drop a File to Translate" : "This File Can't Be Translated"
        detail.stringValue = problem ?? Self.kinds
        choose.title = problem == nil ? "Choose File…" : "Choose Another File…"
    }

    /// Whether a drag is over the window, to invite the drop.
    func setTargeted(_ isTargeted: Bool) {
        symbol.contentTintColor = isTargeted ? .controlAccentColor : .tertiaryLabelColor
    }

    @objc private func chooseFile() {
        chooseAction()
    }
}
