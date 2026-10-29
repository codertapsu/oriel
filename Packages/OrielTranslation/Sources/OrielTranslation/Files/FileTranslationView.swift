import AppKit

/// The file window's content (PLAN §17): the header, then the drop zone, the table of originals and translations, or
/// for an image the translated picture above that table, and the footer. Files can be dropped anywhere on it.
@MainActor
final class FileTranslationView: NSView {
    let header: FileTranslationHeader
    let footer: FileTranslationFooter
    let dropZone: FileDropZone
    let table = FileSegmentTable()
    let imagePane = FileImagePane()
    private let split = NSSplitView()
    private let dropOutline = NSView()
    /// Under the header; the table's column headers draw their own line, so it shows only above the drop zone and the
    /// picture.
    private let topLine = NSBox()
    private let actions: FileTranslationActions
    private var showsImage = false

    init(actions: FileTranslationActions) {
        self.actions = actions
        header = FileTranslationHeader(actions: actions)
        footer = FileTranslationFooter(actions: actions)
        dropZone = FileDropZone(choose: actions.chooseFile)
        super.init(frame: CGRect(x: 0, y: 0, width: 880, height: 600))
        build()
        registerForDraggedTypes([.fileURL])
        table.onCopy = actions.copy
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func build() {
        split.isVertical = false
        split.dividerStyle = .thin
        split.addArrangedSubview(imagePane)
        split.addArrangedSubview(table.scrollView)
        // Below the window's own wish to keep its size (500), so resizing the window resizes the panes; the picture
        // gives way first.
        split.setHoldingPriority(.defaultLow, forSubviewAt: 0)
        split.setHoldingPriority(NSLayoutConstraint.Priority(260), forSubviewAt: 1)
        split.setContentHuggingPriority(.defaultLow, for: .vertical)
        split.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        imagePane.isHidden = true
        topLine.boxType = .separator
        let bottomLine = NSBox()
        bottomLine.boxType = .separator
        dropOutline.wantsLayer = true
        dropOutline.layer?.borderWidth = 3
        dropOutline.layer?.cornerRadius = 10
        dropOutline.isHidden = true
        for view in [header, topLine, split, dropZone, bottomLine, footer, dropOutline] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: topAnchor),
            header.leadingAnchor.constraint(equalTo: leadingAnchor),
            header.trailingAnchor.constraint(equalTo: trailingAnchor),
            topLine.topAnchor.constraint(equalTo: header.bottomAnchor),
            topLine.leadingAnchor.constraint(equalTo: leadingAnchor),
            topLine.trailingAnchor.constraint(equalTo: trailingAnchor),
            split.topAnchor.constraint(equalTo: topLine.bottomAnchor),
            split.leadingAnchor.constraint(equalTo: leadingAnchor),
            split.trailingAnchor.constraint(equalTo: trailingAnchor),
            split.bottomAnchor.constraint(equalTo: bottomLine.topAnchor),
            dropZone.topAnchor.constraint(equalTo: split.topAnchor),
            dropZone.leadingAnchor.constraint(equalTo: split.leadingAnchor),
            dropZone.trailingAnchor.constraint(equalTo: split.trailingAnchor),
            dropZone.bottomAnchor.constraint(equalTo: split.bottomAnchor),
            bottomLine.leadingAnchor.constraint(equalTo: leadingAnchor),
            bottomLine.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomLine.bottomAnchor.constraint(equalTo: footer.topAnchor),
            footer.leadingAnchor.constraint(equalTo: leadingAnchor),
            footer.trailingAnchor.constraint(equalTo: trailingAnchor),
            footer.bottomAnchor.constraint(equalTo: bottomAnchor),
            dropOutline.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            dropOutline.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            dropOutline.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            dropOutline.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
    }

    func update(from model: FileTranslationModel, glossaries: GlossaryLibraryModel) {
        header.update(from: model, glossaries: glossaries)
        footer.update(from: model)
        let hasDocument = model.kind != nil
        dropZone.isHidden = hasDocument
        split.isHidden = !hasDocument
        if case let .failed(message) = model.phase, !hasDocument {
            dropZone.show(problem: message)
        } else {
            dropZone.show(problem: nil)
        }
        table.update(
            segments: model.segments, translations: model.translations, target: LanguageCatalog.name(of: model.targetCode),
            isFinished: !model.isBusy
        )
        let isImage = model.kind == .image
        topLine.isHidden = hasDocument && !isImage
        imagePane.isHidden = !isImage
        if isImage {
            imagePane.update(from: model)
        }
        if isImage != showsImage {
            showsImage = isImage
            split.adjustSubviews()
            if isImage {
                split.setPosition((split.bounds.height * 0.62).rounded(), ofDividerAt: 0)
            }
        }
    }

    // MARK: - Dropping files

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard !fileURLs(in: sender).isEmpty else { return [] }
        setTargeted(true)
        return .copy
    }

    override func draggingExited(_: (any NSDraggingInfo)?) {
        setTargeted(false)
    }

    override func draggingEnded(_: any NSDraggingInfo) {
        setTargeted(false)
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        setTargeted(false)
        let urls = fileURLs(in: sender)
        guard !urls.isEmpty else { return false }
        actions.openFiles(urls)
        return true
    }

    private func fileURLs(in info: any NSDraggingInfo) -> [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        return (info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL]) ?? []
    }

    private func setTargeted(_ isTargeted: Bool) {
        dropOutline.isHidden = !isTargeted
        effectiveAppearance.performAsCurrentDrawingAppearance {
            dropOutline.layer?.borderColor = NSColor.controlAccentColor.cgColor
        }
        dropZone.setTargeted(isTargeted)
    }
}
