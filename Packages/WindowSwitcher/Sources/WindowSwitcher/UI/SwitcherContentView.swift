import AppKit

/// The panel's content inside the glass: the search bar, the scrolling tile grid and the empty-state label,
/// laid out from a `SwitcherLayout`.
final class SwitcherContentView: NSView {
    let searchBar = SearchBarView()
    let scrollView = NSScrollView()
    let grid = TileGridView()
    private let emptyLabel = NSTextField(labelWithString: "")

    var layoutModel: SwitcherLayout? {
        didSet { needsLayout = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScrollElasticity = .none
        scrollView.horizontalScrollElasticity = .none
        scrollView.documentView = grid
        emptyLabel.alignment = .center
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.font = .systemFont(ofSize: 14)
        for view in [searchBar, scrollView, emptyLabel] as [NSView] {
            addSubview(view)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override var isFlipped: Bool {
        true
    }

    func showEmpty(query: String) {
        emptyLabel.stringValue = query.isEmpty ? "No windows" : "No windows match “\(query)”"
    }

    override func layout() {
        super.layout()
        guard let model = layoutModel else { return }
        searchBar.isHidden = model.searchBarHeight == 0
        searchBar.frame = CGRect(x: 0, y: 0, width: bounds.width, height: model.searchBarHeight)
        let viewport = CGRect(x: 0, y: model.searchBarHeight, width: bounds.width, height: max(bounds.height - model.searchBarHeight, 0))
        scrollView.frame = viewport
        scrollView.hasVerticalScroller = model.isScrolling
        grid.frame = CGRect(x: 0, y: 0, width: viewport.width, height: max(model.contentSize.height, viewport.height))
        emptyLabel.isHidden = model.count > 0
        emptyLabel.frame = CGRect(x: 16, y: viewport.midY - 10, width: max(bounds.width - 32, 0), height: 20)
    }
}
