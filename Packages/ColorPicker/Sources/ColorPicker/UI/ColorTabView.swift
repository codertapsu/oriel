import AppKit

/// The Color tab: the current color, large, with the buttons that put it in a palette or the contrast checker; every
/// format, each a click (or its number key) from the clipboard; and the latest picks.
final class ColorTabView: NSView {
    let swatch = LargeSwatchView()
    let addToPaletteButton = NSPopUpButton(frame: .zero, pullsDown: true)
    let contrastButton = NSPopUpButton(frame: .zero, pullsDown: true)
    let recent = RecentColorsView()
    private(set) var rows: [FormatRowView] = []
    private let recentTitle = NSTextField(labelWithString: "Recent")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        rows = ColorFormat.allCases.map(FormatRowView.init)
        Self.configure(addToPaletteButton, title: "Add to Palette", symbol: "plus.circle")
        Self.configure(contrastButton, title: "Check Contrast", symbol: "circle.lefthalf.filled")
        recentTitle.font = .systemFont(ofSize: 11, weight: .semibold)
        recentTitle.textColor = .secondaryLabelColor
        layOut()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Shows `color` in every format. Display P3 has a row only while it differs from sRGB.
    func show(_ color: ColorValue?, defaultFormat: ColorFormat, uppercaseHex: Bool) {
        swatch.show(color, text: color.map { ColorFormatter.string(.hex, for: $0, uppercaseHex: uppercaseHex) } ?? "")
        for row in rows {
            guard let color else {
                row.isHidden = row.format == .displayP3
                row.configure(title: row.format.title, value: "—", isDefault: row.format == defaultFormat)
                continue
            }
            row.isHidden = !row.format.isShown(for: color)
            row.configure(
                title: ColorFormatter.title(row.format, for: color),
                value: ColorFormatter.string(row.format, for: color, uppercaseHex: uppercaseHex),
                isDefault: row.format == defaultFormat
            )
        }
        addToPaletteButton.isEnabled = color != nil
        contrastButton.isEnabled = color != nil
    }

    func row(for format: ColorFormat) -> FormatRowView? {
        rows.first { $0.format == format }
    }

    private static func configure(_ button: NSPopUpButton, title: String, symbol: String) {
        button.controlSize = .small
        button.font = .systemFont(ofSize: 12)
        button.addItem(withTitle: title)
        button.lastItem?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        button.setAccessibilityLabel(title)
    }

    private func layOut() {
        let actions = NSStackView(views: [addToPaletteButton, contrastButton])
        actions.spacing = 8
        let list = NSStackView(views: rows)
        list.orientation = .vertical
        list.spacing = 0
        list.alignment = .leading
        for row in rows {
            row.widthAnchor.constraint(equalTo: list.widthAnchor).isActive = true
        }
        let divider = NSBox()
        divider.boxType = .separator
        for view in [swatch, actions, list, divider, recentTitle, recent] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            swatch.leadingAnchor.constraint(equalTo: leadingAnchor),
            swatch.trailingAnchor.constraint(equalTo: trailingAnchor),
            swatch.topAnchor.constraint(equalTo: topAnchor),
            swatch.heightAnchor.constraint(equalToConstant: 104),
            actions.leadingAnchor.constraint(equalTo: leadingAnchor),
            actions.topAnchor.constraint(equalTo: swatch.bottomAnchor, constant: 10),
            list.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -4),
            list.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 4),
            list.topAnchor.constraint(equalTo: actions.bottomAnchor, constant: 8),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: recentTitle.topAnchor, constant: -10),
            recentTitle.leadingAnchor.constraint(equalTo: leadingAnchor),
            recentTitle.bottomAnchor.constraint(equalTo: recent.topAnchor, constant: -6),
            recent.leadingAnchor.constraint(equalTo: leadingAnchor),
            recent.trailingAnchor.constraint(equalTo: trailingAnchor),
            recent.bottomAnchor.constraint(equalTo: bottomAnchor),
            list.bottomAnchor.constraint(lessThanOrEqualTo: divider.topAnchor, constant: -8),
        ])
    }
}
