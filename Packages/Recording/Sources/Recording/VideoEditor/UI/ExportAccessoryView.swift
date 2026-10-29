import AppKit
import AVFoundation

/// The video editor's export choices, below the save panel (PLAN §17): MPEG-4, QuickTime or GIF; HEVC or H.264;
/// the original size, 1080p or 720p; and a GIF's width and frame rate.
final class ExportAccessoryView: NSView {
    /// The format changed, so the save panel's file type and extension follow.
    var onFormatChange: ((VideoExportFormat) -> Void)?
    private(set) var options: VideoExportOptions

    private let info: MovieInfo
    private let codecs: [VideoCodec]
    private let format = NSPopUpButton(frame: .zero, pullsDown: false)
    private let codec = NSPopUpButton(frame: .zero, pullsDown: false)
    private let size = NSPopUpButton(frame: .zero, pullsDown: false)
    private let gifWidth = NSPopUpButton(frame: .zero, pullsDown: false)
    private let gifRate = NSPopUpButton(frame: .zero, pullsDown: false)
    private let summary = NSTextField(wrappingLabelWithString: "")
    private let grid: NSGridView
    private var sizes: [VideoExportSize] = []
    private var widths: [Int] = []
    private static let rates = [10, 12, 15]

    /// The codecs this Mac's encoders write: HEVC only where there is an HEVC encoder.
    static var availableCodecs: [VideoCodec] {
        AVOutputSettingsAssistant(preset: .hevc1920x1080) == nil ? [.h264] : [.hevc, .h264]
    }

    init(options: VideoExportOptions, info: MovieInfo, summary text: String, codecs: [VideoCodec] = ExportAccessoryView.availableCodecs) {
        self.info = info
        self.codecs = codecs
        var options = options
        if !codecs.contains(options.codec) {
            options.codec = codecs.first ?? .h264
        }
        self.options = options
        grid = NSGridView(views: [
            [Self.label("Format:"), format],
            [Self.label("Codec:"), codec],
            [Self.label("Size:"), size],
            [Self.label("Width:"), gifWidth],
            [Self.label("Frame rate:"), gifRate],
        ])
        super.init(frame: .zero)
        summary.stringValue = text
        summary.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        summary.textColor = .secondaryLabelColor
        summary.preferredMaxLayoutWidth = 360
        grid.rowSpacing = 8
        grid.columnSpacing = 8
        grid.column(at: 0).xPlacement = .trailing
        grid.rowAlignment = .firstBaseline
        fill()
        let stack = NSStackView(views: [grid, summary])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 20, bottom: 12, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        updateRows()
        frame.size = fittingSize
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func fill() {
        format.addItems(withTitles: VideoExportFormat.allCases.map(\.title))
        format.selectItem(at: VideoExportFormat.allCases.firstIndex(of: options.format) ?? 0)
        codec.addItems(withTitles: codecs.map(\.displayName))
        codec.selectItem(at: codecs.firstIndex(of: options.codec) ?? 0)
        sizes = VideoExportSize.allCases.filter { $0.isDistinct(for: info.size, codec: options.codec) }
        if !sizes.contains(options.size) {
            options.size = .original
        }
        refillSizes()
        let sourceWidth = Int(info.size.width)
        widths = [480, 640, 800, 1024, 1280].filter { $0 < sourceWidth } + [min(sourceWidth, 1280)]
        widths = Array(Set(widths)).sorted()
        let wanted = min(options.gif.maxWidth, widths.last ?? options.gif.maxWidth)
        let width = widths.last { $0 <= wanted } ?? widths.first ?? 800
        options.gif = GIFExportOptions(frameRate: options.gif.frameRate, maxWidth: width)
        gifWidth.addItems(withTitles: widths.map { "\($0) px" })
        gifWidth.selectItem(at: widths.firstIndex(of: width) ?? 0)
        let rate = Self.rates.last { $0 <= options.gif.frameRate } ?? 10
        options.gif = GIFExportOptions(frameRate: rate, maxWidth: width)
        gifRate.addItems(withTitles: Self.rates.map { "\($0) fps" })
        gifRate.selectItem(at: Self.rates.firstIndex(of: rate) ?? 0)
        for (popup, label) in [(format, "Format"), (codec, "Codec"), (size, "Size"), (gifWidth, "GIF width"), (gifRate, "GIF frame rate")] {
            popup.target = self
            popup.action = #selector(changed(_:))
            popup.setAccessibilityLabel(label)
        }
    }

    private func refillSizes() {
        size.removeAllItems()
        size.addItems(withTitles: sizes.map { choice in
            let pixels = choice.pixelSize(for: info.size, codec: options.codec)
            return "\(choice.title) (\(Int(pixels.width)) × \(Int(pixels.height)))"
        })
        size.selectItem(at: sizes.firstIndex(of: options.size) ?? 0)
    }

    @objc private func changed(_ sender: NSPopUpButton) {
        switch sender {
        case format:
            let formats = VideoExportFormat.allCases
            options.format = formats[min(max(format.indexOfSelectedItem, 0), formats.count - 1)]
            updateRows()
            onFormatChange?(options.format)
        case codec:
            options.codec = codecs[min(max(codec.indexOfSelectedItem, 0), codecs.count - 1)]
            refillSizes()
        case size:
            options.size = sizes[min(max(size.indexOfSelectedItem, 0), sizes.count - 1)]
        case gifWidth:
            options.gif = GIFExportOptions(
                frameRate: options.gif.frameRate,
                maxWidth: widths[min(max(gifWidth.indexOfSelectedItem, 0), widths.count - 1)]
            )
        default:
            let rate = Self.rates[min(max(gifRate.indexOfSelectedItem, 0), Self.rates.count - 1)]
            options.gif = GIFExportOptions(frameRate: rate, maxWidth: options.gif.maxWidth)
        }
    }

    /// A movie shows its codec and size, a GIF its width and frame rate.
    private func updateRows() {
        let isMovie = options.format.isMovie
        grid.row(at: 1).isHidden = !isMovie || codecs.count < 2
        grid.row(at: 2).isHidden = !isMovie || sizes.count < 2
        grid.row(at: 3).isHidden = isMovie
        grid.row(at: 4).isHidden = isMovie
        frame.size = fittingSize
    }

    private static func label(_ text: String) -> NSTextField {
        NSTextField(labelWithString: text)
    }
}
