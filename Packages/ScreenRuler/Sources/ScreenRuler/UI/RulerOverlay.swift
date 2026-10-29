import AppKit
import OrielCore
import os
import SharedUI

/// The open Screen Ruler: one see-through window per display, over everything and on every Space, which takes the
/// mouse and the keyboard until Esc. `RulerSession` decides what every event means; this class hands it the events,
/// draws its scenes, and does what it asks: copy, close, fit a box, ask for Screen Recording.
///
/// The screen is read once, when the ruler opens, and only when Screen Recording is already granted; without it the
/// windows stay see-through and Dimensions explains itself. Switching to another app or changing the displays closes
/// the ruler. Nothing polls: everything follows events, and closing cancels the reading.
final class RulerOverlay: RulerEventHandling {
    /// Called once the windows are gone.
    var onClose: (() -> Void)?
    private(set) var session: RulerSession
    private var windows: [RulerWindow] = []
    private let screens: [NSScreen]
    private let settings: SettingsStore
    private let permissions: any PermissionChecking
    private let capture: any DisplayCapturing
    private let copier: (String) -> Void
    private var reading: Task<Void, Never>?
    private var fitting: Task<Void, Never>?
    private var flashTask: Task<Void, Never>?
    private var flashText: String?
    private var observers: [(center: NotificationCenter, token: any NSObjectProtocol)] = []
    private var previousApp: NSRunningApplication?
    private let log = Log.logger("screen-ruler")

    init(
        settings: SettingsStore,
        permissions: any PermissionChecking,
        capture: any DisplayCapturing,
        copier: @escaping (String) -> Void,
        screens: [NSScreen] = NSScreen.screens
    ) {
        self.settings = settings
        self.permissions = permissions
        self.capture = capture
        self.copier = copier
        self.screens = screens
        let primaryHeight = screens.first?.frame.height ?? 0
        let displays = screens.compactMap { screen -> RulerDisplay? in
            guard let id = ScreenLocator.displayID(of: screen) else { return nil }
            return RulerDisplay(id: id, cocoaFrame: screen.frame, primaryHeight: primaryHeight, scale: screen.backingScaleFactor)
        }
        let canRead = permissions.status(of: .screenRecording) == .granted
        session = RulerSession(
            displays: displays,
            mode: settings[RulerSettings.defaultMode],
            unit: settings[RulerSettings.unit],
            tolerance: settings[RulerSettings.tolerance],
            edgeStatus: canRead ? .reading : .notPermitted
        )
    }

    var isOpen: Bool {
        !windows.isEmpty
    }

    /// Shows the windows, starts reading the screen when allowed, and takes the keyboard.
    func present() {
        guard !isOpen else { return }
        let current = NSRunningApplication.current
        previousApp = NSWorkspace.shared.frontmostApplication.flatMap { $0 == current ? nil : $0 }
        let color = RulerColor.color(hex: settings[RulerSettings.guideColor]) ?? RulerColor.fallback
        for screen in screens {
            guard let id = ScreenLocator.displayID(of: screen), let display = session.display(id) else { continue }
            let window = RulerWindow(screen: screen, display: display, lineColor: color)
            window.handler = self
            windows.append(window)
        }
        guard !windows.isEmpty else {
            onClose?()
            return
        }
        session.pointerMoved(to: ScreenGeometry.cgPoint(fromCocoa: NSEvent.mouseLocation, primaryHeight: ScreenLocator.primaryHeight))
        NSApp.activate()
        for window in windows {
            window.orderFrontRegardless()
        }
        let underPointer = windows.first { window in session.pointer.map(window.display.contains) ?? false } ?? windows.first
        underPointer?.makeKeyAndOrderFront(nil)
        NSCursor.crosshair.set()
        observeInterruptions()
        render()
        if session.edgeStatus == .reading {
            readScreen()
        }
    }

    func close() {
        guard isOpen else { return }
        reading?.cancel()
        fitting?.cancel()
        flashTask?.cancel()
        for observer in observers {
            observer.center.removeObserver(observer.token)
        }
        observers = []
        for window in windows {
            window.handler = nil
            window.orderOut(nil)
        }
        windows = []
        if let previousApp, NSApp.isActive {
            previousApp.activate(from: .current, options: [])
        }
        onClose?()
    }

    // MARK: Reading the screen

    /// One picture of each display, turned into edge maps off the main thread.
    private func readScreen() {
        let displays = session.displays
        let capture = capture
        reading = Task { [weak self] in
            do {
                let images = try await capture.capture(displays)
                for (id, image) in images {
                    let map = await Task.detached(priority: .userInitiated) { EdgeMap(image: image) }.value
                    guard let self, isOpen, !Task.isCancelled else { return }
                    if let map {
                        session.setEdgeMap(map, for: id)
                    }
                }
                guard let self, isOpen, !Task.isCancelled else { return }
                session.setEdgeStatus(images.isEmpty ? .failed("macOS returned no picture of the screen.") : .ready)
            } catch {
                guard let self, isOpen, !Task.isCancelled else { return }
                log.error("The screen could not be read: \(error.localizedDescription, privacy: .public)")
                session.setEdgeStatus(.failed(error.localizedDescription))
            }
            self?.render()
        }
    }

    // MARK: Events

    func rulerMouseMoved(to point: CGPoint) {
        session.pointerMoved(to: point)
        render()
    }

    func rulerMouseDown(at point: CGPoint, clickCount: Int) {
        perform(session.mouseDown(at: point, clickCount: clickCount))
        render()
    }

    func rulerMouseDragged(to point: CGPoint, modifiers: NSEvent.ModifierFlags) {
        session.mouseDragged(to: point, square: modifiers.contains(.shift), snaps: !modifiers.contains(.command))
        render()
    }

    func rulerMouseUp(at point: CGPoint) {
        perform(session.mouseUp(at: point))
        render()
    }

    func rulerRightMouseDown(at point: CGPoint) {
        perform(session.rightMouseDown(at: point))
        render()
    }

    func rulerKeyDown(_ event: NSEvent) -> Bool {
        guard let key = RulerKeymap.key(
            code: event.keyCode,
            modifiers: Self.modifiers(of: event),
            characters: event.charactersIgnoringModifiers
        ) else { return false }
        perform(session.handle(key))
        render()
        return true
    }

    func rulerCursor() -> NSCursor {
        switch session.cursor {
        case .crosshair: .crosshair
        case .move: .openHand
        case .moving: .closedHand
        case let .guide(orientation): orientation == .vertical ? .columnResize : .rowResize
        case let .resize(handle): NSCursor.frameResize(position: Self.position(of: handle), directions: .all)
        }
    }

    // MARK: Effects

    private func perform(_ effect: RulerEffect?) {
        guard let effect else { return }
        switch effect {
        case .close:
            close()
        case let .copy(text):
            copier(text)
            flash("Copied \(text)")
        case let .copyAndClose(text):
            copier(text)
            close()
            Toast.show("Copied \(text)", symbol: "ruler")
        case .requestScreenRecording:
            close()
            let permissions = permissions
            Task {
                if await permissions.request(.screenRecording) != .granted {
                    permissions.openSystemSettings(for: .screenRecording)
                }
            }
        case let .fit(rect, displayID, tolerance):
            fit(rect, on: displayID, tolerance: tolerance)
        case let .toleranceChanged(percent):
            settings[RulerSettings.tolerance] = percent
        case .beep:
            NSSound.beep()
        }
    }

    /// Shrinks a drawn box to its content off the main thread: a box across a Retina display is millions of pixels.
    private func fit(_ rect: PixelRect, on displayID: CGDirectDisplayID, tolerance: Int) {
        guard let map = session.edgeMap(for: displayID) else { return }
        fitting?.cancel()
        fitting = Task { [weak self] in
            let box = await Task.detached(priority: .userInitiated) { map.contentBounds(in: rect, tolerance: tolerance) }.value
            guard let self, isOpen, !Task.isCancelled else { return }
            if box == nil {
                NSSound.beep()
            }
            session.pin(box, on: displayID)
            render()
        }
    }

    /// "Copied …" in the hint bar for a moment.
    private func flash(_ text: String) {
        flashText = text
        flashTask?.cancel()
        flashTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.flashText = nil
            self?.render()
        }
    }

    // MARK: Drawing

    private func render() {
        let hint = RulerSceneBuilder.hint(for: session)
        let content = (mode: session.mode.title, instruction: hint.instruction, keys: hint.keys)
        let pointer = session.pointer
        let pointerDisplay = pointer.flatMap(session.display(at:))?.id ?? windows.first?.display.id
        for window in windows {
            window.canvas.render(RulerSceneBuilder.scene(for: window.display, session: session))
            window.canvas.showHint(window.display.id == pointerDisplay ? content : nil, flash: flashText, pointer: pointer)
        }
    }

    // MARK: Interruptions

    /// Another app coming forward or the displays changing ends the ruler: the windows and the picture would no longer
    /// match. Another app's activation is watched rather than Oriel's deactivation, because macOS may not have
    /// activated Oriel at all.
    private func observeInterruptions() {
        let workspace = NSWorkspace.shared.notificationCenter
        let activation = workspace
            .addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
                let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                let isOriel = app?.processIdentifier == ProcessInfo.processInfo.processIdentifier
                MainActor.assumeIsolated {
                    if !isOriel {
                        self?.close()
                    }
                }
            }
        observers.append((workspace, activation))
        let screensChanged = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
        observers.append((NotificationCenter.default, screensChanged))
    }

    private static func modifiers(of event: NSEvent) -> KeyCombo.Modifiers {
        let flags = event.modifierFlags
        var modifiers: KeyCombo.Modifiers = []
        if flags.contains(.control) {
            modifiers.insert(.control)
        }
        if flags.contains(.option) {
            modifiers.insert(.option)
        }
        if flags.contains(.shift) {
            modifiers.insert(.shift)
        }
        if flags.contains(.command) {
            modifiers.insert(.command)
        }
        return modifiers
    }

    private static func position(of handle: RulerHandle) -> NSCursor.FrameResizePosition {
        switch handle {
        case .topLeft: .topLeft
        case .top: .top
        case .topRight: .topRight
        case .right: .right
        case .bottomRight: .bottomRight
        case .bottom: .bottom
        case .bottomLeft: .bottomLeft
        case .left: .left
        }
    }
}
