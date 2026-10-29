import AppKit

/// The popover of Instant Capture's colour button: the editor's palette, a colour well for any other colour, and the
/// width (stroke, text size, step size, blur strength), applied to new marks and to the selection.
final class InstantStyleController: NSViewController {
    private let session: EditorSession
    private var swatches: [InstantSwatchButton] = []
    private let well = NSColorWell(style: .default)
    private let slider = NSSlider()
    private let widthLabel = NSTextField(labelWithString: "")
    /// Called after a change, so the toolbar shows the new colour.
    var onChange: (() -> Void)?

    init(session: EditorSession) {
        self.session = session
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        swatches = RGBAColor.palette.map { entry in
            InstantSwatchButton(color: entry.color, name: entry.name, target: self, action: #selector(pickSwatch(_:)))
        }
        let palette = NSStackView(views: swatches)
        palette.spacing = 4
        well.color = session.color.nsColor
        well.target = self
        well.action = #selector(pickCustom(_:))
        well.setAccessibilityLabel("Custom colour")
        let customLabel = NSTextField(labelWithString: "Custom colour")
        customLabel.textColor = .secondaryLabelColor
        let custom = NSStackView(views: [customLabel, well])
        custom.spacing = 8
        slider.minValue = Double(ToolStyle.widthRange.lowerBound)
        slider.maxValue = Double(ToolStyle.widthRange.upperBound)
        slider.numberOfTickMarks = 0
        slider.controlSize = .small
        slider.target = self
        slider.action = #selector(changeWidth(_:))
        slider.setAccessibilityLabel("Width")
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: 150).isActive = true
        widthLabel.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        widthLabel.textColor = .secondaryLabelColor
        widthLabel.alignment = .right
        widthLabel.translatesAutoresizingMaskIntoConstraints = false
        widthLabel.widthAnchor.constraint(equalToConstant: 22).isActive = true
        let widthTitle = NSTextField(labelWithString: "Width")
        widthTitle.textColor = .secondaryLabelColor
        let width = NSStackView(views: [widthTitle, slider, widthLabel])
        width.spacing = 8
        let stack = NSStackView(views: [palette, custom, width])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        view = stack
        refresh()
    }

    /// Shows the session's colour and width.
    func refresh() {
        for swatch in swatches {
            swatch.isCurrent = swatch.swatch == session.color
        }
        well.color = session.color.nsColor
        slider.doubleValue = Double(session.strokeWidth)
        widthLabel.stringValue = "\(Int(session.strokeWidth))"
        slider.setAccessibilityValueDescription("\(Int(session.strokeWidth)) points")
    }

    @objc private func pickSwatch(_ sender: InstantSwatchButton) {
        session.setColor(sender.swatch)
        changed()
    }

    @objc private func pickCustom(_ sender: NSColorWell) {
        if let color = RGBAColor(sender.color) {
            session.setColor(color)
            changed()
        }
    }

    @objc private func changeWidth(_ sender: NSSlider) {
        session.setStrokeWidth(CGFloat(sender.doubleValue.rounded()))
        changed()
    }

    private func changed() {
        refresh()
        onChange?()
    }
}
