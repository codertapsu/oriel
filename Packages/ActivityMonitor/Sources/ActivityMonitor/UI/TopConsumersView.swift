import AppKit

/// The strip above the list: the processes using the most of the tab's measure, with a flame on one over its
/// heavy-use threshold; clicking one selects it. On the right, what the list shows.
final class TopConsumersView: NSView {
    static let height: CGFloat = 34

    struct Item {
        let process: ProcessMetrics
        let value: String
        /// Why it is flagged, when it is over a threshold.
        let heavyNote: String?
    }

    var onSelect: ((ProcessIdentity) -> Void)?

    private let title = NSTextField(labelWithString: "")
    private let chips = NSStackView()
    private let status = NSTextField(labelWithString: "")
    private var identities: [ProcessIdentity] = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        title.font = .systemFont(ofSize: 11, weight: .medium)
        title.textColor = .secondaryLabelColor
        title.setContentHuggingPriority(.required, for: .horizontal)
        title.setContentCompressionResistancePriority(.required, for: .horizontal)
        chips.orientation = .horizontal
        chips.spacing = 6
        chips.setClippingResistancePriority(.defaultLow, for: .horizontal)
        chips.detachesHiddenViews = true
        status.font = .systemFont(ofSize: 11)
        status.textColor = .secondaryLabelColor
        status.alignment = .right
        status.lineBreakMode = .byTruncatingHead
        status.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        status.setContentHuggingPriority(.required, for: .horizontal)
        for view in [title, chips, status] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            title.centerYAnchor.constraint(equalTo: centerYAnchor),
            chips.leadingAnchor.constraint(equalTo: title.trailingAnchor, constant: 8),
            chips.centerYAnchor.constraint(equalTo: centerYAnchor),
            status.leadingAnchor.constraint(greaterThanOrEqualTo: chips.trailingAnchor, constant: 12),
            status.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            status.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// `emptyText` replaces the title when nothing is worth naming.
    func update(title text: String, emptyText: String, items: [Item], icons: ProcessIconCache, status statusText: String) {
        let heading = items.isEmpty ? emptyText : text
        if title.stringValue != heading {
            title.stringValue = heading
        }
        if status.stringValue != statusText {
            status.stringValue = statusText
        }
        identities = items.map(\.process.id)
        while chips.arrangedSubviews.count < items.count {
            chips.addArrangedSubview(makeChip())
        }
        for (index, view) in chips.arrangedSubviews.enumerated() {
            guard let chip = view as? NSButton else { continue }
            chip.isHidden = index >= items.count
            guard index < items.count else { continue }
            let item = items[index]
            // The name gives way, so the number always shows.
            let title = "\(Self.shortened(item.process.name))  \(item.value)"
            if chip.title != title {
                chip.title = title
            }
            chip.image = item.heavyNote == nil
                ? icons.icon(for: item.process)
                : NSImage(systemSymbolName: "flame.fill", accessibilityDescription: "Heavy use")
            chip.contentTintColor = item.heavyNote == nil ? nil : ActivityColors.heavy
            chip.toolTip = item.heavyNote.map { "\(item.process.name): \($0)" } ?? "Select \(item.process.name)"
            chip.setAccessibilityLabel("\(item.process.name), \(item.value)" + (item.heavyNote.map { ", \($0)" } ?? ""))
            chip.tag = index
        }
        setAccessibilityLabel(title.stringValue)
    }

    /// At most 24 characters, cut in the middle: "com.surfshark…WireGuard".
    static func shortened(_ name: String) -> String {
        guard name.count > 24 else { return name }
        return String(name.prefix(13)) + "…" + String(name.suffix(10))
    }

    private func makeChip() -> NSButton {
        let chip = NSButton(title: "", target: self, action: #selector(chipClicked))
        chip.bezelStyle = .recessed
        chip.showsBorderOnlyWhileMouseInside = false
        chip.controlSize = .small
        chip.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        chip.imagePosition = .imageLeading
        chip.imageScaling = .scaleProportionallyDown
        chip.lineBreakMode = .byTruncatingMiddle
        chip.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        chip.widthAnchor.constraint(lessThanOrEqualToConstant: 260).isActive = true
        return chip
    }

    @objc private func chipClicked(_ sender: NSButton) {
        guard identities.indices.contains(sender.tag) else { return }
        onSelect?(identities[sender.tag])
    }
}
