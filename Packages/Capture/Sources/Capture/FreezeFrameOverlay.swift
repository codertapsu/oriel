import AppKit
import OrielCore
import SharedUI

/// The freeze-frame selection (PLAN §7.2, items 2–4): one `OverlayWindow` per screen showing that display as it was
/// when the capture began, so menus and hover states stay in the shot, the loupe is exact and selecting has no
/// latency. With the screen left live (Settings → Capture, for video) the windows are see-through instead, without
/// the loupe, and the pick is captured after the overlay has gone. Area mode draws, moves, resizes, nudges and snaps
/// a rectangle on one display (`SelectionEditor`); window mode highlights the window under the pointer from the
/// cached window list; screen mode picks a display. Esc or a right click cancels, Return confirms.
final class FreezeFrameOverlay: OverlayEventHandling {
    /// Called once the windows are on screen, to end the capture-to-overlay signpost.
    var onPresented: (() -> Void)?
    private let backdrops: [SelectionBackdrop]
    private let windowTargets: [WindowTarget]
    private let configuration: OverlayConfiguration
    private var mode: OverlayMode
    private var windows: [OverlayWindow] = []
    private var editor: SelectionEditor?
    private var editorDisplay: CGDirectDisplayID?
    private var pointer: CGPoint?
    private var hovered: WindowTarget?
    private var spaceHeld = false
    private var continuation: CheckedContinuation<OverlayOutcome, Never>?
    private var previousApp: NSRunningApplication?
    private var observers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []

    init(backdrops: [SelectionBackdrop], windows: [WindowTarget], configuration: OverlayConfiguration) {
        self.backdrops = backdrops
        windowTargets = windows
        self.configuration = configuration
        mode = configuration.mode
    }

    /// Shows the overlay and waits until the user confirms or cancels.
    func run() async -> OverlayOutcome {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            present()
        }
    }

    /// Ends the overlay as Esc would.
    func cancel() {
        finish(.cancelled)
    }

    // MARK: - Presentation

    private func present() {
        let current = NSRunningApplication.current
        previousApp = NSWorkspace.shared.frontmostApplication.flatMap { $0 == current ? nil : $0 }
        for screen in NSScreen.screens {
            guard let id = ScreenLocator.displayID(of: screen), let backdrop = backdrops.first(where: { $0.id == id }) else { continue }
            let window = OverlayWindow(backdrop: backdrop, screen: screen, tools: configuration.tools)
            window.handler = self
            windows.append(window)
        }
        guard !windows.isEmpty else {
            finish(.cancelled)
            return
        }
        let location = ScreenGeometry.cgPoint(fromCocoa: NSEvent.mouseLocation, primaryHeight: ScreenLocator.primaryHeight)
        pointerMoved(to: location)
        NSApp.activate()
        for window in windows {
            window.orderFrontRegardless()
        }
        let underPointer = windows.first { $0.backdrop.display.frame.contains(location) } ?? windows.first
        underPointer?.makeKeyAndOrderFront(nil)
        NSCursor.crosshair.set()
        observeInterruptions()
        render()
        onPresented?()
    }

    /// Switching to another app or changing the displays ends the overlay: the frozen images and window frames would
    /// no longer match.
    /// Another app's activation is watched rather than Oriel's deactivation, because macOS may not have activated
    /// Oriel at all.
    private func observeInterruptions() {
        let workspace = NSWorkspace.shared.notificationCenter
        let activated = NSWorkspace.didActivateApplicationNotification
        let activation = workspace.addObserver(forName: activated, object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let isOriel = app?.processIdentifier == ProcessInfo.processInfo.processIdentifier
            MainActor.assumeIsolated {
                if !isOriel {
                    self?.finish(.cancelled)
                }
            }
        }
        workspaceObservers.append(activation)
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.finish(.cancelled) }
        })
    }

    private func finish(_ outcome: OverlayOutcome) {
        guard let continuation else { return }
        self.continuation = nil
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        workspaceObservers = []
        observers = []
        for window in windows {
            window.handler = nil
            window.orderOut(nil)
        }
        windows = []
        if let previousApp, NSApp.isActive {
            previousApp.activate(from: .current, options: [])
        }
        continuation.resume(returning: outcome)
    }

    // MARK: - Events

    func overlay(_ event: OverlayEvent) {
        switch event {
        case let .mouseMoved(point):
            pointerMoved(to: point)
        case let .mouseDown(point, clickCount):
            mouseDown(at: point, clickCount: clickCount)
        case let .mouseDragged(point):
            pointer = point
            editor?.drag(to: point, movesAnchor: spaceHeld, snaps: !NSEvent.modifierFlags.contains(.command))
        case let .mouseUp(point):
            mouseUp(at: point)
        case .rightMouseDown:
            finish(.cancelled)
        case let .tool(tool):
            if let intent = tool.intent {
                confirm(intent)
            } else {
                finish(.cancelled)
            }
        }
        render()
    }

    func overlayKeyDown(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        switch event.keyCode {
        case KeyCode.escape:
            finish(.cancelled)
        case KeyCode.returnKey, Self.keypadEnter:
            let horizontal = flags.contains(.option) && configuration.tools.contains(.scrollHorizontally)
            confirm(horizontal ? .alternate : .capture)
        case KeyCode.space:
            spacePressed(isRepeat: event.isARepeat)
        case KeyCode.leftArrow, KeyCode.rightArrow, KeyCode.upArrow, KeyCode.downArrow:
            arrow(event.keyCode, flags: flags)
        default:
            // With ⌘ held, `characters` is the Latin letter even on layouts such as Russian, whose base layer is not.
            let keys = Set([event.characters, event.charactersIgnoringModifiers].compactMap { $0?.lowercased() })
            guard flags.contains(.command) else { return false }
            if keys.contains("c"), configuration.tools.contains(.copy) {
                confirm(.copy)
            } else if keys.contains("s"), configuration.tools.contains(.save) {
                confirm(.save)
            } else {
                return false
            }
        }
        render()
        return true
    }

    func overlayKeyUp(_ event: NSEvent) {
        if event.keyCode == KeyCode.space {
            spaceHeld = false
        }
    }

    func overlayCursor(at point: CGPoint) -> NSCursor {
        guard mode == .area else { return .pointingHand }
        guard let editor, editorDisplay == display(containing: point)?.id else { return .crosshair }
        switch editor.phase {
        case .moving:
            return .closedHand
        case let .resizing(handle, _):
            return Self.cursor(for: handle)
        case .drawing:
            return .crosshair
        case .idle:
            if let handle = editor.handle(at: point, tolerance: Self.handleTolerance) {
                return Self.cursor(for: handle)
            }
            return editor.rect?.contains(point) == true ? .openHand : .crosshair
        }
    }

    private static let keypadEnter: UInt16 = 76
    private static let handleTolerance: CGFloat = 6

    private func pointerMoved(to point: CGPoint) {
        pointer = point
        switch mode {
        case .area:
            let idle = editor?.rect == nil && editor?.isDragging != true
            hovered = idle ? WindowTarget.topmost(at: point, in: windowTargets) : nil
        case .window:
            hovered = WindowTarget.topmost(at: point, in: windowTargets)
        case .screen:
            hovered = nil
        }
    }

    private func mouseDown(at point: CGPoint, clickCount: Int) {
        pointer = point
        guard mode == .area, let display = display(containing: point) else { return }
        if clickCount >= 2, editorDisplay == display.id, editor?.rect?.contains(point) == true {
            confirm(.capture)
            return
        }
        if editorDisplay != display.id || editor == nil {
            let frames = windowTargets.map(\.frame).filter { $0.intersects(display.display.frame) } + [display.display.frame]
            editor = SelectionEditor(
                bounds: display.display.frame,
                scale: display.display.scale,
                snapping: EdgeSnapping(frames: frames)
            )
            editorDisplay = display.id
        }
        editor?.begin(at: point, handleTolerance: Self.handleTolerance)
        hovered = nil
    }

    private func mouseUp(at point: CGPoint) {
        pointer = point
        switch mode {
        case .area:
            guard var editor else { return }
            if !editor.end() {
                // A click picks the window under the pointer as the area, or clears the selection.
                if let window = WindowTarget.topmost(at: point, in: windowTargets) {
                    editor.select(window.frame)
                } else {
                    editor.clear()
                }
            }
            self.editor = editor
            if configuration.confirmsOnRelease, editor.rect != nil {
                confirm(.capture)
            }
        case .window:
            if let target = WindowTarget.topmost(at: point, in: windowTargets) {
                finish(.window(target, intent: .capture))
            }
        case .screen:
            if let display = display(containing: point) {
                finish(.screen(display.id, intent: .capture))
            }
        }
    }

    private func spacePressed(isRepeat: Bool) {
        guard !isRepeat else { return }
        if editor?.isDrawing == true {
            spaceHeld = true
        } else if configuration.allowsModeSwitch, editor?.isDragging != true, mode != .screen {
            mode = mode == .area ? .window : .area
            editor = nil
            editorDisplay = nil
            if let pointer {
                pointerMoved(to: pointer)
            }
        }
    }

    /// Arrows nudge by one pixel, Shift by ten; with Option they resize instead.
    private func arrow(_ keyCode: UInt16, flags: NSEvent.ModifierFlags) {
        guard mode == .area, editor?.rect != nil else { return }
        let step = flags.contains(.shift) ? 10 : 1
        let delta: (x: Int, y: Int) = switch keyCode {
        case KeyCode.leftArrow: (-step, 0)
        case KeyCode.rightArrow: (step, 0)
        case KeyCode.upArrow: (0, -step)
        default: (0, step)
        }
        if flags.contains(.option) {
            editor?.resize(dWidth: delta.x, dHeight: delta.y)
        } else {
            editor?.nudge(dx: delta.x, dy: delta.y)
        }
    }

    private func confirm(_ intent: OverlayIntent) {
        switch mode {
        case .area:
            guard let rect = editor?.rect, let id = editorDisplay, rect.width > 0, rect.height > 0 else {
                NSSound.beep()
                return
            }
            finish(.area(rect, display: id, intent: intent))
        case .window:
            guard let target = hovered ?? pointer.flatMap({ WindowTarget.topmost(at: $0, in: windowTargets) }) else {
                NSSound.beep()
                return
            }
            finish(.window(target, intent: intent))
        case .screen:
            guard let display = pointer.flatMap(display(containing:)) ?? backdrops.first else { return }
            finish(.screen(display.id, intent: intent))
        }
    }

    // MARK: - Rendering

    private func render() {
        for window in windows {
            window.render(scene(for: window.backdrop))
        }
    }

    private func scene(for display: SelectionBackdrop) -> OverlayScene {
        var scene = OverlayScene()
        scene.pointer = pointer
        let pointerHere = pointer.map { display.display.frame.contains($0) } ?? false
        switch mode {
        case .area:
            if editorDisplay == display.id, let editor, let rect = editor.rect {
                scene.selection = rect
                scene.showsHandles = !editor.isDrawing
                scene.showsToolbar = !editor.isDragging
                scene.readout = editor.pixelSize.map { "\(Int($0.width)) × \(Int($0.height))" }
            }
            // While the whole selection is being moved the pointer is not aiming at anything, so the crosshair
            // and the loupe step aside; while drawing and resizing they help place the edge exactly.
            if pointerHere, let pointer, editor?.isMoving != true {
                scene.crosshair = pointer
                scene.highlight = hovered?.frame
                if configuration.showsMagnifier {
                    addMagnifier(to: &scene, display: display, at: pointer)
                }
            }
        case .window:
            scene.highlight = hovered?.frame
            scene.highlightIsStrong = true
            if pointerHere, let hovered {
                let names = [hovered.appName, hovered.title].compactMap(\.self).filter { !$0.isEmpty }
                scene.readout = names.joined(separator: " — ")
            }
        case .screen:
            if pointerHere {
                scene.highlight = display.display.frame
                scene.highlightIsStrong = true
            }
        }
        if pointerHere, scene.selection == nil {
            scene.hint = configuration.hint(for: mode)
        }
        return scene
    }

    /// The loupe samples the frozen picture, so a live screen has none.
    private func addMagnifier(to scene: inout OverlayScene, display: SelectionBackdrop, at point: CGPoint) {
        guard let image = display.image else { return }
        let geometry = OverlayGeometry(displayFrame: display.display.frame, scale: display.display.scale)
        let pixel = geometry.pixel(at: point)
        guard let patch = PixelPatch.sample(image, x: pixel.x, y: pixel.y, size: MagnifierView.pixels) else { return }
        scene.magnifier = patch
        scene.magnifierCaption = "\(patch.hexColor)   \(pixel.x), \(pixel.y)"
    }

    private func display(containing point: CGPoint) -> SelectionBackdrop? {
        backdrops.first { $0.display.frame.contains(point) }
    }

    private static func cursor(for handle: SelectionHandle) -> NSCursor {
        let position: NSCursor.FrameResizePosition = switch handle {
        case .topLeft: .topLeft
        case .top: .top
        case .topRight: .topRight
        case .right: .right
        case .bottomRight: .bottomRight
        case .bottom: .bottom
        case .bottomLeft: .bottomLeft
        case .left: .left
        }
        return NSCursor.frameResize(position: position, directions: .all)
    }
}
