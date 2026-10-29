import AppKit
import UniformTypeIdentifiers

/// The video editor's content view, which takes a movie file dropped on it (PLAN §17) and shows a highlight
/// while one is dragged over it.
final class MovieDropView: NSView {
    /// A movie was dropped.
    var onDrop: ((URL) -> Void)?

    /// Drawn over everything while a movie is dragged over the window.
    private let highlight = NSView()

    private var isTargeted = false {
        didSet { showHighlight(isTargeted) }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
        highlight.wantsLayer = true
        highlight.layer?.borderWidth = 3
        highlight.layer?.cornerRadius = 8
        highlight.isHidden = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Whether `url` is a movie file the editor can open.
    static func isMovie(_ url: URL) -> Bool {
        guard url.isFileURL, let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .movie)
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard movie(in: sender) != nil else { return [] }
        isTargeted = true
        return .copy
    }

    override func draggingExited(_: (any NSDraggingInfo)?) {
        isTargeted = false
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        isTargeted = false
        guard let url = movie(in: sender) else { return false }
        onDrop?(url)
        return true
    }

    private func showHighlight(_ shows: Bool) {
        if shows {
            highlight.frame = bounds.insetBy(dx: 3, dy: 3)
            highlight.autoresizingMask = [.width, .height]
            effectiveAppearance.performAsCurrentDrawingAppearance {
                highlight.layer?.borderColor = NSColor.controlAccentColor.cgColor
            }
            addSubview(highlight, positioned: .above, relativeTo: nil)
        }
        highlight.isHidden = !shows
    }

    private func movie(in info: any NSDraggingInfo) -> URL? {
        let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]
        return urls?.first(where: Self.isMovie)
    }
}
