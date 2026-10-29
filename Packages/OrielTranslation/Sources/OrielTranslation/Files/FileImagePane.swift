import AppKit

/// The picture of an image file in the file window: the translation drawn over it, like Translate Area, or the
/// original, chosen with the switch in the corner.
@MainActor
final class FileImagePane: NSView {
    private let imageView = NSImageView()
    private let switcher = NSSegmentedControl(labels: ["Translation", "Original"], trackingMode: .selectOne, target: nil, action: nil)
    private var shown: CGImage?
    var onShowOriginal: (@MainActor (Bool) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.underPageBackgroundColor.cgColor
        imageView.imageScaling = .scaleProportionallyDown
        imageView.imageAlignment = .alignCenter
        imageView.setAccessibilityLabel("Translated image")
        imageView.translatesAutoresizingMaskIntoConstraints = false
        switcher.target = self
        switcher.action = #selector(switched)
        switcher.selectedSegment = 0
        switcher.controlSize = .small
        switcher.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)
        addSubview(switcher)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            imageView.topAnchor.constraint(equalTo: switcher.bottomAnchor, constant: 8),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            switcher.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            switcher.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = NSColor.underPageBackgroundColor.cgColor
        }
    }

    func update(from model: FileTranslationModel) {
        let showsOriginal = model.showsOriginalImage || model.annotatedImage == nil
        switcher.selectedSegment = model.showsOriginalImage ? 1 : 0
        switcher.setEnabled(model.annotatedImage != nil, forSegment: 0)
        let image = showsOriginal ? model.image : model.annotatedImage
        guard image !== shown else { return }
        shown = image
        imageView.image = image.map { NSImage(cgImage: $0, size: CGSize(width: $0.width, height: $0.height)) }
        imageView.setAccessibilityLabel(showsOriginal ? "Original image" : "Translated image")
    }

    @objc private func switched() {
        onShowOriginal?(switcher.selectedSegment == 1)
    }
}
