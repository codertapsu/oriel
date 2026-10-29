import AppKit

/// A key as the hint bar draws it: its glyph in a small outlined cap, then what it does.
final class KeyCapView: NSView {
    private let cap = NSTextField(labelWithString: "")
    private let text = NSTextField(labelWithString: "")
    private let capBox = NSView()

    init(_ hint: KeyHint) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        cap.stringValue = hint.key
        cap.font = .systemFont(ofSize: 11, weight: .semibold)
        cap.textColor = .labelColor
        cap.alignment = .center
        text.stringValue = hint.label
        text.font = .systemFont(ofSize: 12)
        text.textColor = .secondaryLabelColor
        capBox.wantsLayer = true
        capBox.layer?.cornerRadius = 4
        capBox.layer?.borderWidth = 1
        for view in [capBox, cap, text] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            capBox.leadingAnchor.constraint(equalTo: leadingAnchor),
            capBox.centerYAnchor.constraint(equalTo: centerYAnchor),
            capBox.heightAnchor.constraint(equalToConstant: 18),
            capBox.widthAnchor.constraint(greaterThanOrEqualToConstant: 20),
            cap.leadingAnchor.constraint(equalTo: capBox.leadingAnchor, constant: 5),
            cap.trailingAnchor.constraint(equalTo: capBox.trailingAnchor, constant: -5),
            cap.centerYAnchor.constraint(equalTo: capBox.centerYAnchor),
            text.leadingAnchor.constraint(equalTo: capBox.trailingAnchor, constant: 5),
            text.trailingAnchor.constraint(equalTo: trailingAnchor),
            text.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(equalToConstant: 20),
        ])
        updateColors()
        setAccessibilityElement(true)
        setAccessibilityRole(.staticText)
        setAccessibilityLabel("\(hint.key): \(hint.label)")
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            capBox.layer?.borderColor = NSColor.tertiaryLabelColor.cgColor
            capBox.layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.12).cgColor
        }
    }
}
