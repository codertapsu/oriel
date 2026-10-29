import AppKit

/// The right side of the panel: the selected item in full — text, formatted text, a link, a color, an image, files or
/// other data — over a line about its contents and one about where and when it was copied.
final class ClipboardPreviewView: NSView {
    var onOpenLink: ((URL) -> Void)?
    var onRevealFiles: (([URL]) -> Void)?

    private let body = NSView()
    private let placeholder = NSTextField(labelWithString: "")
    private let summaryField = NSTextField(labelWithString: "")
    private let provenanceField = NSTextField(labelWithString: "")
    private var shown: NSView?
    private var link: URL?
    private var files: [URL] = []

    /// Apps whose text is code, shown in a monospaced font.
    private static let codeApps: Set<String> = [
        "com.microsoft.VSCode", "com.apple.dt.Xcode", "com.apple.Terminal", "com.googlecode.iterm2", "dev.zed.Zed",
        "com.sublimetext.4", "com.todesktop.230313mzl4w4u92", "com.mitchellh.ghostty", "net.kovidgoyal.kitty",
        "com.github.wez.wezterm", "io.alacritty",
    ]

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        placeholder.font = .systemFont(ofSize: 13)
        placeholder.textColor = .tertiaryLabelColor
        placeholder.alignment = .center
        summaryField.font = .systemFont(ofSize: 12, weight: .medium)
        summaryField.textColor = .secondaryLabelColor
        summaryField.lineBreakMode = .byTruncatingTail
        provenanceField.font = .systemFont(ofSize: 11)
        provenanceField.textColor = .tertiaryLabelColor
        provenanceField.lineBreakMode = .byTruncatingTail
        let info = NSStackView(views: [summaryField, provenanceField])
        info.orientation = .vertical
        info.alignment = .leading
        info.spacing = 2
        for view in [body, info, placeholder] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            body.leadingAnchor.constraint(equalTo: leadingAnchor),
            body.trailingAnchor.constraint(equalTo: trailingAnchor),
            body.topAnchor.constraint(equalTo: topAnchor),
            body.bottomAnchor.constraint(equalTo: info.topAnchor, constant: -8),
            info.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            info.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
            info.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            placeholder.centerXAnchor.constraint(equalTo: body.centerXAnchor),
            placeholder.centerYAnchor.constraint(equalTo: body.centerYAnchor),
            placeholder.widthAnchor.constraint(lessThanOrEqualTo: body.widthAnchor, constant: -32),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func showPlaceholder(_ text: String) {
        replace(with: nil)
        placeholder.stringValue = text
        placeholder.isHidden = false
        summaryField.stringValue = ""
        provenanceField.stringValue = ""
    }

    func show(_ item: ClipboardItem, detail: ClipboardPreviewDetail, icons: ClipboardIconCache) {
        placeholder.isHidden = true
        replace(with: content(for: item, detail: detail, icons: icons))
        summaryField.stringValue = detail.isMissing ? item.kind.displayName : ClipboardFormat.summary(of: item, text: detail.text)
        provenanceField.stringValue = ClipboardFormat.provenance(of: item)
    }

    static func looksLikeCode(_ text: String, source: String?) -> Bool {
        if let source, codeApps.contains(source) || source.hasPrefix("com.jetbrains.") {
            return true
        }
        let lines = text.split(whereSeparator: \.isNewline).prefix(200)
        guard lines.count >= 3 else { return false }
        return lines.count { $0.first == " " || $0.first == "\t" } * 3 >= lines.count
    }

    // MARK: Kinds

    private func content(for item: ClipboardItem, detail: ClipboardPreviewDetail, icons: ClipboardIconCache) -> NSView {
        guard !detail.isMissing else {
            return Self.centered([Self.label("The contents of this item could not be read.", size: 13, color: .secondaryLabelColor)])
        }
        switch item.kind {
        case .text, .richText:
            let text = detail.text ?? item.text ?? ""
            return textView(text, rtf: detail.rtf, monospaced: Self.looksLikeCode(text, source: item.sourceBundleID))
        case .link:
            return linkView(detail.text ?? item.title)
        case .color:
            return colorView(item.colorHex.flatMap { ClipboardColor(parsing: $0) }, text: item.title)
        case .image:
            return imageView(detail.image)
        case .files:
            return filesView(detail.files, icons: icons)
        case .other:
            return otherView(detail.representations)
        }
    }

    private func textView(_ text: String, rtf: Data?, monospaced: Bool) -> NSView {
        let scroll = NSTextView.scrollableTextView()
        scroll.drawsBackground = false
        scroll.autohidesScrollers = true
        guard let textView = scroll.documentView as? NSTextView else { return scroll }
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 12, height: 12)
        // Formatted text keeps its colors, mapped so dark text stays readable in Dark Mode.
        textView.usesAdaptiveColorMappingForDarkAppearance = true
        if let rtf, let attributed = NSAttributedString(rtf: rtf, documentAttributes: nil) {
            textView.textStorage?.setAttributedString(attributed)
        } else {
            textView.font = monospaced ? .monospacedSystemFont(ofSize: 12, weight: .regular) : .systemFont(ofSize: 13)
            textView.textColor = .labelColor
            textView.string = text
        }
        return scroll
    }

    private func linkView(_ text: String) -> NSView {
        let address = text.trimmingCharacters(in: .whitespacesAndNewlines)
        link = URL(string: address).flatMap { $0.scheme == nil ? URL(string: "https://" + address) : $0 }
        let symbol = NSImageView(image: NSImage(systemSymbolName: "link.circle.fill", accessibilityDescription: "Link") ?? NSImage())
        symbol.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 40, weight: .regular)
        symbol.contentTintColor = .controlAccentColor
        let field = Self.label(address, size: 14, weight: .medium, wraps: true)
        field.isSelectable = true
        field.maximumNumberOfLines = 6
        field.alignment = .center
        let host = Self.label(link?.host() ?? "", size: 12, color: .secondaryLabelColor)
        let open = NSButton(title: "Open Link", target: self, action: #selector(openLink))
        open.bezelStyle = .push
        open.isEnabled = link != nil
        return Self.centered([symbol, field, host, open])
    }

    private func colorView(_ color: ClipboardColor?, text: String) -> NSView {
        guard let color else { return textView(text, rtf: nil, monospaced: true) }
        let swatch = NSView()
        swatch.wantsLayer = true
        swatch.layer?.backgroundColor = CGColor(srgbRed: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
        swatch.layer?.cornerRadius = 18
        swatch.layer?.borderWidth = 1
        swatch.layer?.borderColor = NSColor.separatorColor.cgColor
        swatch.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            swatch.widthAnchor.constraint(equalToConstant: 120),
            swatch.heightAnchor.constraint(equalToConstant: 120),
        ])
        let values = [color.hex, color.rgbDescription, color.hslDescription].map { value in
            let field = Self.label(value, size: 13, monospaced: true)
            field.isSelectable = true
            return field
        }
        return Self.centered([swatch] + values)
    }

    private func imageView(_ image: CGImage?) -> NSView {
        let view = NSImageView()
        view.image = image.map { NSImage(cgImage: $0, size: .zero) }
        view.imageScaling = .scaleProportionallyDown
        view.imageAlignment = .alignCenter
        view.setAccessibilityLabel("Copied image")
        Self.yields(view)
        return Self.padded(view, inset: 14)
    }

    private func filesView(_ list: [ClipboardPreviewDetail.File], icons: ClipboardIconCache) -> NSView {
        files = list.filter(\.exists).map(\.url)
        var rows: [NSView] = list.prefix(8).map { file in
            let icon = NSImageView(image: icons.fileIcon(file.url))
            icon.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                icon.widthAnchor.constraint(equalToConstant: 32),
                icon.heightAnchor.constraint(equalToConstant: 32),
            ])
            let name = Self.label(file.url.lastPathComponent, size: 13, weight: .medium)
            let facts = [file.kind, file.size.map(ClipboardFormat.bytes)].compactMap(\.self).joined(separator: ", ")
            let folder = (file.url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath
            let path = Self.label("\(file.exists ? facts : "Missing") · \(folder)", size: 11)
            path.textColor = file.exists ? .secondaryLabelColor : .systemRed
            path.lineBreakMode = .byTruncatingMiddle
            let texts = NSStackView(views: [name, path])
            texts.orientation = .vertical
            texts.alignment = .leading
            texts.spacing = 1
            let row = NSStackView(views: [icon, texts])
            row.spacing = 8
            return row
        }
        if list.count > 8 {
            rows.append(Self.label("and \(list.count - 8) more", size: 12, color: .secondaryLabelColor))
        }
        let reveal = NSButton(title: "Show in Finder", target: self, action: #selector(revealFiles))
        reveal.bezelStyle = .push
        reveal.isEnabled = !files.isEmpty
        rows.append(reveal)
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        return Self.padded(stack, inset: 16, fills: false)
    }

    private func otherView(_ representations: [ClipboardPreviewDetail.Representation]) -> NSView {
        let title = Self.label("Data for other apps", size: 14, weight: .semibold)
        let note = Self.label("Paste it into the app it was copied from.", size: 12, color: .secondaryLabelColor)
        let types = representations.prefix(12).map { representation in
            Self.label(
                "\(representation.type)  \(ClipboardFormat.bytes(representation.size))",
                size: 11,
                color: .secondaryLabelColor,
                monospaced: true
            )
        }
        let stack = NSStackView(views: [title, note] + types)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        return Self.padded(stack, inset: 16, fills: false)
    }

    // MARK: Building blocks

    private func replace(with view: NSView?) {
        shown?.removeFromSuperview()
        shown = view
        guard let view else { return }
        view.translatesAutoresizingMaskIntoConstraints = false
        body.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: body.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: body.trailingAnchor),
            view.topAnchor.constraint(equalTo: body.topAnchor),
            view.bottomAnchor.constraint(equalTo: body.bottomAnchor),
        ])
    }

    @objc private func openLink() {
        if let link {
            onOpenLink?(link)
        }
    }

    @objc private func revealFiles() {
        onRevealFiles?(files)
    }

    private static func label(
        _ text: String,
        size: CGFloat,
        weight: NSFont.Weight = .regular,
        color: NSColor = .labelColor,
        monospaced: Bool = false,
        wraps: Bool = false
    ) -> NSTextField {
        let field = wraps ? NSTextField(wrappingLabelWithString: text) : NSTextField(labelWithString: text)
        field.font = monospaced ? .monospacedSystemFont(ofSize: size, weight: weight) : .systemFont(ofSize: size, weight: weight)
        field.textColor = color
        if !wraps {
            field.lineBreakMode = .byTruncatingTail
        }
        yields(field)
        return field
    }

    /// Lets a view shrink to the preview instead of growing the panel: an image or a long name is as wide as it likes
    /// otherwise, and the panel gives way to anything above `windowSizeStayPut`.
    private static func yields(_ view: NSView) {
        for orientation in [NSLayoutConstraint.Orientation.horizontal, .vertical] {
            view.setContentCompressionResistancePriority(.defaultLow, for: orientation)
            view.setContentHuggingPriority(.defaultLow, for: orientation)
        }
    }

    /// Views stacked in the middle of the preview.
    private static func centered(_ views: [NSView]) -> NSView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor, constant: -40),
        ])
        return container
    }

    /// `view` inset from the preview's edges; `fills` false keeps it at the top instead of stretching it.
    private static func padded(_ view: NSView, inset: CGFloat, fills: Bool = true) -> NSView {
        let container = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        var constraints = [
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: inset),
            view.topAnchor.constraint(equalTo: container.topAnchor, constant: inset),
        ]
        if fills {
            constraints += [
                view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -inset),
                view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -inset),
            ]
        } else {
            constraints.append(view.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -inset))
        }
        NSLayoutConstraint.activate(constraints)
        return container
    }
}
