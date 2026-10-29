import AppKit
import OrielCore
import SharedUI

/// The Translate Under Cursor tooltip (PLAN §17): a small glass panel below the text being read, with the languages
/// and provider above the translation. It never takes focus or clicks (`ignoresMouseEvents`, a non-activating panel
/// that cannot become key), floats above every app and full-screen Space, and VoiceOver announces each translation.
@MainActor
final class CursorTooltipPanel: CursorTooltipPresenting {
    /// Translations wrap at this width.
    static let maximumTextWidth: CGFloat = 380
    /// Short translations still get a tooltip this wide.
    static let minimumTextWidth: CGFloat = 120
    /// Longer translations are cut off after this many lines.
    static let maximumLines = 14

    private let panel = FloatingPanel(level: .popUpMenu, joinsAllSpaces: true)
    private let background = Material.make(cornerRadius: 10)
    private let icon = NSImageView()
    private let caption = NSTextField(labelWithString: "")
    private let body = NSTextField(wrappingLabelWithString: "")
    private let spinner = NSProgressIndicator()
    private let visibleFrame: @MainActor (CGPoint) -> CGRect?
    /// The width the text wraps at, set for each translation before the panel is measured.
    private let textWidth: NSLayoutConstraint

    /// `visibleFrame` is the visible frame (global points, top-left origin) of the screen with a point on it.
    init(visibleFrame: @escaping @MainActor (CGPoint) -> CGRect? = CursorTooltipPanel.visibleFrame(at:)) {
        self.visibleFrame = visibleFrame
        textWidth = body.widthAnchor.constraint(equalToConstant: Self.minimumTextWidth)
        panel.ignoresMouseEvents = true
        panel.hasShadow = true
        panel.collectionBehavior.insert(.stationary)
        panel.setAccessibilityRole(.popover)
        caption.font = .systemFont(ofSize: NSFont.smallSystemFontSize, weight: .medium)
        caption.textColor = .secondaryLabelColor
        caption.lineBreakMode = .byTruncatingTail
        // Above the stack's hugging (250), so the caption keeps its width; the width limit below still truncates it.
        caption.setContentCompressionResistancePriority(NSLayoutConstraint.Priority(500), for: .horizontal)
        body.font = .systemFont(ofSize: 13)
        body.textColor = .labelColor
        body.maximumNumberOfLines = Self.maximumLines
        body.lineBreakMode = .byWordWrapping
        body.cell?.truncatesLastVisibleLine = true
        body.preferredMaxLayoutWidth = Self.maximumTextWidth
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        icon.contentTintColor = .secondaryLabelColor
        let top = NSStackView(views: [icon, caption, spinner])
        top.spacing = 5
        let stack = NSStackView(views: [top, body])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 11, bottom: 9, right: 11)
        stack.translatesAutoresizingMaskIntoConstraints = false
        background.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: background.contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: background.contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: background.contentView.bottomAnchor),
            top.widthAnchor.constraint(lessThanOrEqualToConstant: Self.maximumTextWidth),
            top.widthAnchor.constraint(lessThanOrEqualTo: body.widthAnchor),
            textWidth,
        ])
        panel.contentView = background
    }

    func showPending(region: CGRect, pointer: CGPoint) {
        fill(symbol: "character.bubble", caption: "Translating…", body: nil, isBusy: true)
        place(region: region, pointer: pointer)
    }

    func show(_ translation: CursorTranslation, region: CGRect, pointer: CGPoint) {
        fill(symbol: "character.bubble", caption: translation.caption, body: translation.translation, isBusy: false)
        body.baseWritingDirection = LanguageCatalog.isRightToLeft(Locale.Language(identifier: translation.targetLanguage))
            ? .rightToLeft : .natural
        place(region: region, pointer: pointer)
        panel.setAccessibilityLabel("Translation: \(translation.translation)")
        NSAccessibility.post(element: panel, notification: .announcementRequested, userInfo: [
            .announcement: translation.translation, .priority: NSAccessibilityPriorityLevel.medium.rawValue,
        ])
    }

    func showFailure(_ message: String, region: CGRect, pointer: CGPoint) {
        fill(symbol: "exclamationmark.triangle", caption: "Couldn't translate", body: message, isBusy: false)
        place(region: region, pointer: pointer)
    }

    func hide() {
        spinner.stopAnimation(nil)
        panel.orderOut(nil)
    }

    /// The content as it would be shown, for screenshots that never put it on screen.
    var contentView: NSView {
        background
    }

    private func fill(symbol: String, caption text: String, body bodyText: String?, isBusy: Bool) {
        icon.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        caption.stringValue = text
        body.stringValue = bodyText ?? ""
        body.isHidden = bodyText == nil
        spinner.isHidden = !isBusy
        // As wide as the caption or the text on one line, whichever is wider, up to the maximum; then it wraps. The
        // caption's row also holds the icon (16 points and 5 of spacing), the spinner when busy, and the label's padding.
        let captionWidth = caption.attributedStringValue.size().width + 16 + 5 + 4 + (isBusy ? 21 : 0)
        // A wrapping label draws its text 2 points in from each side.
        let textWidth = bodyText.map { _ in body.attributedStringValue.size().width + 4 } ?? 0
        let width = ceil(min(Self.maximumTextWidth, max(Self.minimumTextWidth, captionWidth, textWidth)))
        self.textWidth.constant = width
        body.preferredMaxLayoutWidth = width
        if isBusy {
            spinner.startAnimation(nil)
        } else {
            spinner.stopAnimation(nil)
        }
    }

    private func place(region: CGRect, pointer: CGPoint) {
        background.layoutSubtreeIfNeeded()
        let size = background.fittingSize
        guard let visible = visibleFrame(pointer) else { return }
        let frame = CursorGeometry.tooltipFrame(size: size, region: region, pointer: pointer, visible: visible)
        panel.setFrame(ScreenLocator.cocoaRect(fromCG: frame), display: true)
        panel.orderFrontRegardless()
    }

    /// The visible frame of the screen under `point` (global points, top-left origin).
    static func visibleFrame(at point: CGPoint) -> CGRect? {
        let cocoa = ScreenGeometry.cocoaPoint(fromCG: point, primaryHeight: ScreenLocator.primaryHeight)
        let screen = NSScreen.screens.first { $0.frame.contains(cocoa) } ?? NSScreen.main
        return screen.map { ScreenLocator.cgRect(fromCocoa: $0.visibleFrame) }
    }
}
