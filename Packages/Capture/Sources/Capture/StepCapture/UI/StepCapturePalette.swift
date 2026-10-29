import AppKit
import SharedUI

/// Step Capture's palette (PLAN §17): a small floating bar at the top of the screen with the number of steps so far,
/// a button that captures the next one, Mark Clicks, Cancel and Finish. Any capture taken meanwhile, in any mode,
/// becomes the next step. Closing the bar with × keeps the session going; Finish Step Capture is in Oriel's menu.
/// Non-activating, so the app being documented keeps focus, and left out of captures like every Oriel window.
final class StepCapturePalette {
    var onAddStep: (() -> Void)?
    var onFinish: (() -> Void)?
    var onCancel: (() -> Void)?
    /// The × button: the session goes on without the bar.
    var onHide: (() -> Void)?
    var onMarksClicksChanged: ((Bool) -> Void)?

    let panel = FloatingPanel(level: .floating)
    private let count = NSTextField(labelWithString: "")
    private let marksClicks = FirstClickButton(checkboxWithTitle: "Mark clicks", target: nil, action: nil)

    init(marksClicks isOn: Bool) {
        build()
        marksClicks.state = isOn ? .on : .off
        update(count: 0)
    }

    var isVisible: Bool {
        panel.isVisible
    }

    /// At the top of the screen under the pointer, below the menu bar.
    func show() {
        let screen = ScreenLocator.screenUnderMouse ?? NSScreen.main
        let visible = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let size = panel.frame.size
        panel.setFrameOrigin(CGPoint(x: (visible.midX - size.width / 2).rounded(), y: (visible.maxY - size.height - 12).rounded()))
        panel.orderFrontRegardless()
    }

    func close() {
        panel.orderOut(nil)
    }

    func update(count steps: Int) {
        count.stringValue = switch steps {
        case 0: "No steps yet"
        case 1: "1 step"
        default: "\(steps) steps"
        }
        count.setAccessibilityLabel(count.stringValue)
    }

    @objc private func addStepPressed() {
        onAddStep?()
    }

    @objc private func finishPressed() {
        onFinish?()
    }

    @objc private func cancelPressed() {
        onCancel?()
    }

    @objc private func hidePressed() {
        onHide?()
    }

    @objc private func marksClicksToggled() {
        onMarksClicksChanged?(marksClicks.state == .on)
    }

    private func build() {
        let icon = NSImageView(image: NSImage(systemSymbolName: "list.number", accessibilityDescription: nil) ?? NSImage())
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        icon.contentTintColor = .controlAccentColor
        let title = NSTextField(labelWithString: "Step Capture")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        count.font = .systemFont(ofSize: 11)
        count.textColor = .secondaryLabelColor
        let labels = NSStackView(views: [title, count])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 0

        let addStep = FirstClickButton(title: "Add Step", target: self, action: #selector(addStepPressed))
        addStep.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: nil)
        addStep.imagePosition = .imageLeading
        addStep.toolTip = "Select an area to capture the next step. Any other capture becomes a step too."
        marksClicks.target = self
        marksClicks.action = #selector(marksClicksToggled)
        marksClicks.toolTip = "Mark where you clicked last before each capture"
        let cancel = FirstClickButton(title: "Cancel", target: self, action: #selector(cancelPressed))
        let finish = FirstClickButton(title: "Finish", target: self, action: #selector(finishPressed))
        // The palette is never the key window, where an accent bezel would show, so a symbol marks the main action.
        finish.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)
        finish.imagePosition = .imageLeading
        finish.contentTintColor = .controlAccentColor
        finish.toolTip = "Open the steps to edit and export them"
        let hide = HUDButton(symbol: "xmark", label: "Hide the palette; Step Capture goes on") { [weak self] in
            self?.hidePressed()
        }

        let stack = NSStackView(views: [icon, labels, addStep, marksClicks, cancel, finish, hide])
        stack.spacing = 10
        stack.setCustomSpacing(8, after: icon)
        stack.setCustomSpacing(18, after: labels)
        stack.setCustomSpacing(16, after: marksClicks)
        stack.setCustomSpacing(6, after: cancel)
        stack.setCustomSpacing(4, after: finish)
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 14, bottom: 8, right: 6)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let background = Material.make(cornerRadius: 14)
        background.contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: background.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: background.contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: background.contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: background.contentView.bottomAnchor),
            labels.widthAnchor.constraint(greaterThanOrEqualToConstant: 92),
        ])
        panel.contentView = background
        panel.setContentSize(background.fittingSize)
        panel.isMovableByWindowBackground = true
        panel.setAccessibilityLabel("Step Capture")
    }
}
