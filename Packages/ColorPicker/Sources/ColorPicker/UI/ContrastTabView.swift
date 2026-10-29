import AppKit

/// The Contrast tab: the text and background colors (type, drop or pick each, and swap them), their WCAG 2.2 ratio
/// with AA and AAA for normal text, large text and UI components, a live sample, and APCA's Lc as extra information.
final class ContrastTabView: NSView {
    let textRow = ContrastColorRow(title: "Text")
    let backgroundRow = ContrastColorRow(title: "Background")
    let swapButton = NSButton()
    let sample = ContrastSampleView()

    private let ratioLabel = NSTextField(labelWithString: "")
    private let ratioCaption = NSTextField(labelWithString: "WCAG 2.2 contrast ratio")
    private var badges: [ContrastCriterion.Use: [ContrastCriterion.Level: PassBadge]] = [:]
    private let apcaTitle = NSTextField(labelWithString: "WCAG 3 draft (APCA)")
    private let apcaValue = NSTextField(labelWithString: "")
    private let apcaUse = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        swapButton.image = NSImage(systemSymbolName: "arrow.up.arrow.down", accessibilityDescription: "Swap the colors")
        swapButton.isBordered = false
        swapButton.imagePosition = .imageOnly
        swapButton.contentTintColor = .secondaryLabelColor
        swapButton.toolTip = "Swap text and background"
        ratioLabel.font = .monospacedDigitSystemFont(ofSize: 32, weight: .semibold)
        ratioCaption.font = .systemFont(ofSize: 11)
        ratioCaption.textColor = .secondaryLabelColor
        apcaTitle.font = .systemFont(ofSize: 12)
        apcaTitle.textColor = .secondaryLabelColor
        apcaTitle.toolTip = "APCA is the contrast method drafted for WCAG 3. It is not a requirement yet."
        apcaValue.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        apcaUse.font = .systemFont(ofSize: 11)
        apcaUse.textColor = .secondaryLabelColor
        apcaUse.lineBreakMode = .byTruncatingTail
        layOut()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show(text: ColorValue, background: ColorValue, uppercaseHex: Bool) {
        textRow.show(text, uppercaseHex: uppercaseHex)
        backgroundRow.show(background, uppercaseHex: uppercaseHex)
        let shown = WCAGContrast.shown(text, on: background)
        let ratio = WCAGContrast.ratio(shown, background)
        ratioLabel.stringValue = WCAGContrast.ratioText(ratio)
        ratioLabel.setAccessibilityLabel("Contrast ratio \(WCAGContrast.ratioText(ratio).replacingOccurrences(of: ":", with: " to "))")
        for use in ContrastCriterion.Use.allCases {
            for level in ContrastCriterion.Level.allCases {
                badges[use]?[level]?.show(
                    ContrastCriterion.criterion(for: use, level: level),
                    ratio: ratio,
                    name: "\(level.title), \(use.title)"
                )
            }
        }
        let lightness = APCAContrast.lightnessContrast(text: shown, background: background)
        apcaValue.stringValue = APCAContrast.text(lightness)
        apcaUse.stringValue = APCAContrast.use(for: lightness)
        sample.show(text: text, background: background)
    }

    private func layOut() {
        let grid = NSGridView(numberOfColumns: 3, rows: 0)
        grid.rowSpacing = 6
        grid.columnSpacing = 18
        let header = ContrastCriterion.Level.allCases.map { level -> NSView in
            let label = NSTextField(labelWithString: level.title)
            label.font = .systemFont(ofSize: 11, weight: .semibold)
            label.textColor = .secondaryLabelColor
            return label
        }
        grid.addRow(with: [NSGridCell.emptyContentView] + header)
        for use in ContrastCriterion.Use.allCases {
            let title = NSTextField(labelWithString: use.title)
            title.font = .systemFont(ofSize: 12)
            var row: [NSView] = [title]
            for level in ContrastCriterion.Level.allCases {
                let badge = PassBadge()
                badges[use, default: [:]][level] = badge
                row.append(badge)
            }
            grid.addRow(with: row)
        }
        grid.column(at: 0).width = 110
        let ratioStack = NSStackView(views: [ratioLabel, ratioCaption])
        ratioStack.orientation = .vertical
        ratioStack.alignment = .leading
        ratioStack.spacing = 0
        let apcaLine = NSStackView(views: [apcaTitle, apcaValue])
        apcaLine.spacing = 8
        let dividers = [NSBox(), NSBox()]
        dividers.forEach { $0.boxType = .separator }
        for view in [textRow, swapButton, backgroundRow, dividers[0], ratioStack, grid, sample, dividers[1], apcaLine, apcaUse] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            textRow.leadingAnchor.constraint(equalTo: leadingAnchor),
            textRow.trailingAnchor.constraint(equalTo: trailingAnchor),
            textRow.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            swapButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 84),
            swapButton.topAnchor.constraint(equalTo: textRow.bottomAnchor, constant: 2),
            swapButton.widthAnchor.constraint(equalToConstant: 24),
            swapButton.heightAnchor.constraint(equalToConstant: 18),
            backgroundRow.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundRow.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundRow.topAnchor.constraint(equalTo: swapButton.bottomAnchor, constant: 2),
            dividers[0].leadingAnchor.constraint(equalTo: leadingAnchor),
            dividers[0].trailingAnchor.constraint(equalTo: trailingAnchor),
            dividers[0].topAnchor.constraint(equalTo: backgroundRow.bottomAnchor, constant: 12),
            ratioStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            ratioStack.topAnchor.constraint(equalTo: dividers[0].bottomAnchor, constant: 10),
            grid.leadingAnchor.constraint(equalTo: leadingAnchor),
            grid.topAnchor.constraint(equalTo: ratioStack.bottomAnchor, constant: 12),
            sample.leadingAnchor.constraint(equalTo: leadingAnchor),
            sample.trailingAnchor.constraint(equalTo: trailingAnchor),
            sample.topAnchor.constraint(equalTo: grid.bottomAnchor, constant: 14),
            sample.heightAnchor.constraint(equalToConstant: 132),
            dividers[1].leadingAnchor.constraint(equalTo: leadingAnchor),
            dividers[1].trailingAnchor.constraint(equalTo: trailingAnchor),
            dividers[1].topAnchor.constraint(equalTo: sample.bottomAnchor, constant: 14),
            apcaLine.leadingAnchor.constraint(equalTo: leadingAnchor),
            apcaLine.topAnchor.constraint(equalTo: dividers[1].bottomAnchor, constant: 10),
            apcaUse.leadingAnchor.constraint(equalTo: leadingAnchor),
            apcaUse.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            apcaUse.topAnchor.constraint(equalTo: apcaLine.bottomAnchor, constant: 3),
        ])
    }
}
