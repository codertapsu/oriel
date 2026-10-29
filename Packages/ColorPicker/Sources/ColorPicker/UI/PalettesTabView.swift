import AppKit

/// The Palettes tab: every palette with its colors, in the user's order, the selected color's bar, and New Palette.
/// Section views are kept by palette and reused, so a name being edited survives a refresh.
final class PalettesTabView: NSView {
    let detail = PaletteColorDetailView()
    let newPaletteButton = NSButton(title: "New Palette", target: nil, action: nil)
    /// Set up a new section's callbacks; called once per palette.
    var configureSection: ((PaletteSectionView) -> Void)?

    private let scroll = NSScrollView()
    private let stack = NSStackView()
    private let emptyLabel = NSTextField(wrappingLabelWithString: "")
    private let divider = NSBox()
    private var sections: [UUID: PaletteSectionView] = [:]
    /// Sections already as wide as the list.
    private var fitted: Set<NSView> = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.edgeInsets = NSEdgeInsets(top: 2, left: 0, bottom: 12, right: 0)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let document = FlippedView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        scroll.documentView = document
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.horizontalScrollElasticity = .none
        emptyLabel.stringValue = "No palettes yet.\nMake one to keep colors together, then add the current color with + or drag colors in."
        emptyLabel.font = .systemFont(ofSize: 13)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center
        newPaletteButton.bezelStyle = .push
        newPaletteButton.controlSize = .regular
        newPaletteButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)
        newPaletteButton.imagePosition = .imageLeading
        divider.boxType = .separator
        for view in [scroll, emptyLabel, divider, detail, newPaletteButton] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: divider.topAnchor, constant: -8),
            document.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor),
            document.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            document.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -2),
            stack.topAnchor.constraint(equalTo: document.topAnchor),
            document.bottomAnchor.constraint(equalTo: stack.bottomAnchor),
            emptyLabel.centerXAnchor.constraint(equalTo: scroll.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scroll.centerYAnchor, constant: -12),
            emptyLabel.widthAnchor.constraint(equalTo: widthAnchor, constant: -48),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: detail.topAnchor, constant: -8),
            detail.leadingAnchor.constraint(equalTo: leadingAnchor),
            detail.trailingAnchor.constraint(equalTo: trailingAnchor),
            detail.bottomAnchor.constraint(equalTo: newPaletteButton.topAnchor, constant: -10),
            newPaletteButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            newPaletteButton.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show(_ palettes: [Palette], selectedColor: UUID?, uppercaseHex: Bool) {
        let ids = Set(palettes.map(\.id))
        for (id, section) in sections where !ids.contains(id) {
            section.removeFromSuperview()
            sections[id] = nil
            fitted.remove(section)
        }
        var ordered: [NSView] = []
        for palette in palettes {
            let section = sections[palette.id] ?? makeSection(palette.id)
            section.show(palette, selected: selectedColor, uppercaseHex: uppercaseHex)
            ordered.append(section)
        }
        if stack.arrangedSubviews != ordered {
            stack.setViews(ordered, in: .top)
            for section in ordered where !fitted.contains(section) {
                section.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
                fitted.insert(section)
            }
        }
        emptyLabel.isHidden = !palettes.isEmpty
        // The selected color's bar says nothing useful before there is a palette.
        detail.isHidden = palettes.isEmpty
        divider.isHidden = palettes.isEmpty
        let entry = selectedColor.flatMap { id in palettes.lazy.flatMap(\.colors).first { $0.id == id } }
        detail.show(entry, uppercaseHex: uppercaseHex)
    }

    func section(_ id: UUID) -> PaletteSectionView? {
        sections[id]
    }

    /// Scrolls a palette into view, as after it was made.
    func reveal(_ id: UUID) {
        guard let section = sections[id] else { return }
        layoutSubtreeIfNeeded()
        section.scrollToVisible(section.bounds)
    }

    private func makeSection(_ id: UUID) -> PaletteSectionView {
        let section = PaletteSectionView(paletteID: id)
        sections[id] = section
        configureSection?(section)
        return section
    }
}
