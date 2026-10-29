import AppKit

/// The Opacity row of a pin's menus: a slider from 10 to 100 % that changes the pin as it moves, and the value.
final class PinOpacitySlider: NSView {
    static let size = CGSize(width: 250, height: 30)

    private let slider: NSSlider
    private let value = NSTextField(labelWithString: "")
    private let onChange: (CGFloat) -> Void

    init(opacity: CGFloat, onChange: @escaping @MainActor (CGFloat) -> Void) {
        self.onChange = onChange
        slider = NSSlider(
            value: Double(opacity),
            minValue: Double(PinState.opacities.lowerBound),
            maxValue: Double(PinState.opacities.upperBound),
            target: nil,
            action: nil
        )
        super.init(frame: CGRect(origin: .zero, size: Self.size))
        slider.target = self
        slider.action = #selector(slid)
        slider.isContinuous = true
        slider.controlSize = .small
        slider.setAccessibilityLabel("Opacity")
        let label = NSTextField(labelWithString: "Opacity")
        label.font = .menuFont(ofSize: 0)
        value.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        value.textColor = .secondaryLabelColor
        value.alignment = .right
        let stack = NSStackView(views: [label, slider, value])
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 22, bottom: 0, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            value.widthAnchor.constraint(equalToConstant: 38),
        ])
        show(opacity)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// A menu item holding a slider.
    static func menuItem(opacity: CGFloat, onChange: @escaping @MainActor (CGFloat) -> Void) -> NSMenuItem {
        let item = NSMenuItem()
        item.view = PinOpacitySlider(opacity: opacity, onChange: onChange)
        return item
    }

    @objc private func slid() {
        let opacity = CGFloat(slider.doubleValue)
        show(opacity)
        onChange(opacity)
    }

    private func show(_ opacity: CGFloat) {
        value.stringValue = "\(Int((opacity * 100).rounded())) %"
        slider.setAccessibilityValueDescription(value.stringValue)
    }
}
