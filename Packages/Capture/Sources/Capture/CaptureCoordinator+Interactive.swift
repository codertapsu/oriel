import AppKit
import OrielCore
import ScreenCaptureKit
import SharedUI

/// Interactive captures: freeze every display (or leave the screen live), let the user pick on the overlay, and turn
/// the pick into an image.
extension CaptureCoordinator {
    func interactiveCapture(_ mode: CaptureMode) async throws -> CapturedImage? {
        switch mode {
        case .area: try await overlayCapture(.area)
        case .window: try await overlayCapture(.window)
        case .screen: try await overlayCapture(.screen)
        case .previousArea: try await previousAreaCapture()
        case .allDisplays: try await allDisplaysCapture()
        case .scrolling: try await scrollingCapture()
        }
    }

    /// Fetches the shareable content again (the start of a capture is when window frames must be current) and
    /// captures every display at once, leaving Oriel's own windows out (PLAN §7.2, item 2), and the desktop icons and
    /// widgets when `hidesDesktop` is on. With Settings → Capture → Freeze the screen while selecting off, it captures
    /// nothing yet: the overlay is see-through and the pick is captured once it has gone.
    func prepareSelection(keepsHDR: Bool, hidesDesktop: Bool = false) async throws -> SelectionScreens {
        let content = try await cache.current(refresh: true)
        let windows = ShareableContentCache.windowTargets(in: content)
        guard settings[CaptureSettings.freezesScreen] else {
            let displays = content.displays.map { ScreenshotEngine.frame(of: $0) }
            guard !displays.isEmpty else { throw CaptureError.displayNotFound }
            return SelectionScreens(displays: displays, frozen: [], windows: windows, content: content, hidesDesktop: hidesDesktop)
        }
        let options = ScreenshotEngine.Options(showsCursor: settings[CaptureSettings.showsCursor], keepsHDR: keepsHDR)
        let excluded = ShareableContentCache.excludedWindows(in: content, hidesDesktop: hidesDesktop)
        let frozen = await engine.freeze(content.displays, excluding: excluded, options: options)
        guard !frozen.isEmpty else { throw CaptureError.displayNotFound }
        return SelectionScreens(
            displays: frozen.map(\.display),
            frozen: frozen,
            windows: windows,
            content: content,
            hidesDesktop: hidesDesktop
        )
    }

    /// Settings → Capture → Hide desktop icons and widgets, for the captures that show the desktop: area, screen,
    /// all displays and previous area. Selections for recording, translation and Instant Capture keep them, because
    /// what they capture afterwards does.
    var hidesDesktop: Bool {
        settings[CaptureSettings.hidesDesktopIcons]
    }

    private func overlayCapture(_ mode: OverlayMode) async throws -> CapturedImage? {
        let interval = signposter.beginInterval("Capture to overlay")
        let screens = try await prepareSelection(keepsHDR: keepsHDR, hidesDesktop: hidesDesktop)
        var configuration = OverlayConfiguration(mode: mode)
        configuration.showsMagnifier = settings[CaptureSettings.showsMagnifier]
        let overlay = FreezeFrameOverlay(backdrops: screens.backdrops, windows: screens.windows, configuration: configuration)
        overlay.onPresented = { [signposter] in signposter.endInterval("Capture to overlay", interval) }
        switch await overlay.run() {
        case .cancelled:
            return nil
        case let .area(rect, displayID, intent):
            settings[CaptureSettings.previousArea] = StoredRegion(rect: rect, displayID: displayID)
            let display = try await picture(of: displayID, in: screens)
            return try crop(rect, from: display, windows: screens.windows, kind: .area, intent: intent)
        case let .window(target, intent):
            return try await windowImage(target, screens: screens, intent: intent)
        case let .screen(displayID, intent):
            let display = try await picture(of: displayID, in: screens)
            let result = CaptureResult(image: display.image, kind: .screen, rect: display.display.frame, scale: display.display.scale)
            return CapturedImage(result: result, hdrImage: display.hdrImage, intent: intent)
        }
    }

    /// The display's frozen picture or, while the screen stays live, the display as it is now. The overlay has gone
    /// by then, and the content is fetched again so that every window of Oriel's, the overlay's included, is left out.
    func picture(of displayID: CGDirectDisplayID, in screens: SelectionScreens) async throws -> FrozenDisplay {
        if let frozen = screens.frozenDisplay(displayID) {
            return frozen
        }
        guard screens.isLive else { throw CaptureError.displayNotFound }
        let content = try await cache.current(refresh: true)
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else { throw CaptureError.displayNotFound }
        let options = ScreenshotEngine.Options(showsCursor: settings[CaptureSettings.showsCursor], keepsHDR: keepsHDR)
        let excluded = ShareableContentCache.excludedWindows(in: content, hidesDesktop: screens.hidesDesktop)
        return try await engine.capture(display, excluding: excluded, options: options)
    }

    /// The pixels of `rect` from the frozen display, cropped in pixel space at the display's scale.
    func crop(
        _ rect: CGRect,
        from display: FrozenDisplay,
        windows: [WindowTarget],
        kind: CaptureKind,
        intent: OverlayIntent
    ) throws -> CapturedImage {
        let pixels = CaptureGeometry.pixelRect(for: rect, on: display.display)
        guard let image = ImageCropping.crop(display.image, to: pixels) else { throw CaptureError.emptyArea }
        let hdrImage = display.hdrImage.flatMap { ImageCropping.crop($0, to: pixels) }
        let source = WindowTarget.topmost(at: CGPoint(x: rect.midX, y: rect.midY), in: windows)
        let clipped = rect.intersection(display.display.frame)
        let result = CaptureResult(
            image: image,
            kind: kind,
            rect: clipped,
            scale: display.display.scale,
            windowTitle: source?.title,
            appName: source?.appName
        )
        return CapturedImage(result: result, hdrImage: hdrImage, intent: intent)
    }

    /// The window by itself (with its shadow when that is on); if ScreenCaptureKit cannot do that, what its display
    /// shows of it.
    private func windowImage(_ target: WindowTarget, screens: SelectionScreens, intent: OverlayIntent) async throws -> CapturedImage {
        if let window = screens.content.windows.first(where: { $0.windowID == target.id }) {
            do {
                let shot = try await engine.capture(window: window, shadow: settings[CaptureSettings.windowShadow], keepsHDR: keepsHDR)
                let result = CaptureResult(
                    image: shot.image,
                    kind: .window,
                    rect: target.frame,
                    scale: shot.scale,
                    windowTitle: target.title,
                    appName: target.appName
                )
                return CapturedImage(result: result, hdrImage: shot.hdrImage, intent: intent)
            } catch {
                log.error("Window capture failed, cropping the frozen display: \(error.localizedDescription, privacy: .private)")
            }
        }
        guard let frame = CaptureGeometry.display(for: target.frame, among: screens.displays) else {
            throw CaptureError.windowNotFound(target.id)
        }
        let display = try await picture(of: frame.id, in: screens)
        return try crop(target.frame, from: display, windows: [target], kind: .window, intent: intent)
    }

    /// The last area again without the overlay; the area mode when there is none or its display is gone.
    private func previousAreaCapture() async throws -> CapturedImage? {
        guard let stored = settings[CaptureSettings.previousArea] else { return try await overlayCapture(.area) }
        let content = try await cache.current(refresh: true)
        let display = content.displays.first { $0.displayID == stored.displayID } ?? content.displays
            .first { $0.frame.intersects(stored.rect) }
        guard let display else { return try await overlayCapture(.area) }
        let options = ScreenshotEngine.Options(showsCursor: settings[CaptureSettings.showsCursor], keepsHDR: keepsHDR)
        let excluded = ShareableContentCache.excludedWindows(in: content, hidesDesktop: hidesDesktop)
        let frozen = try await engine.capture(display, excluding: excluded, options: options)
        let windows = ShareableContentCache.windowTargets(in: content)
        return try crop(stored.rect, from: frozen, windows: windows, kind: .area, intent: .capture)
    }

    /// Every display in one image, at the highest scale among them.
    private func allDisplaysCapture() async throws -> CapturedImage? {
        let content = try await cache.current(refresh: true)
        let options = ScreenshotEngine.Options(showsCursor: settings[CaptureSettings.showsCursor], keepsHDR: keepsHDR)
        let excluded = ShareableContentCache.excludedWindows(in: content, hidesDesktop: hidesDesktop)
        let frozen = await engine.freeze(content.displays, excluding: excluded, options: options)
        if frozen.count == 1, let only = frozen.first {
            let result = CaptureResult(image: only.image, kind: .screen, rect: only.display.frame, scale: only.display.scale)
            return CapturedImage(result: result, hdrImage: only.hdrImage, intent: .capture)
        }
        guard let layout = CaptureGeometry.composite(of: frozen.map(\.display)),
              let image = ImageCropping.compose(frozen.map(\.image), layout: layout)
        else {
            throw CaptureError.displayNotFound
        }
        let hdrImages = frozen.compactMap(\.hdrImage)
        let hdrImage = hdrImages.count == frozen.count ? ImageCropping.compose(hdrImages, layout: layout) : nil
        let result = CaptureResult(image: image, kind: .screen, rect: layout.bounds, scale: layout.scale)
        return CapturedImage(result: result, hdrImage: hdrImage, intent: .capture)
    }

    /// Select a region on the overlay, then scroll it and stitch (PLAN §7.3). Low confidence in automatic mode fails
    /// fast and offers manual mode for the same region.
    private func scrollingCapture() async throws -> CapturedImage? {
        let screens = try await prepareSelection(keepsHDR: false)
        var configuration = OverlayConfiguration(mode: .area)
        configuration.allowsModeSwitch = false
        configuration.prompt = "Select the area to scroll"
        configuration.tools = OverlayTool.scrollingTools
        configuration.showsMagnifier = settings[CaptureSettings.showsMagnifier]
        let overlay = FreezeFrameOverlay(backdrops: screens.backdrops, windows: screens.windows, configuration: configuration)
        guard case let .area(rect, displayID, intent) = await overlay.run() else { return nil }
        guard let display = screens.content.displays.first(where: { $0.displayID == displayID }) else {
            throw CaptureError.displayNotFound
        }
        let direction: ScrollDirection = intent == .alternate ? .horizontal : .vertical
        var mode = await scrollingMode()
        // Captures leave pins and Quick Access cards out, so one may cover the region (unseen on a frozen screen):
        // let the mouse through them, or they would take the scroll events.
        pins.setPassingThrough(true)
        quickAccess.setPassingThrough(true)
        defer {
            pins.setPassingThrough(false)
            quickAccess.setPassingThrough(false)
        }
        while true {
            let session = ScrollingCaptureSession(
                region: rect,
                display: display,
                mode: mode,
                direction: direction,
                maxLength: settings[CaptureSettings.scrollingMaxLength],
                engine: engine,
                cache: cache
            )
            switch await session.run() {
            case let .finished(image, scale, stoppedEarly):
                if stoppedEarly {
                    Toast.show("Stopped where the content could no longer be lined up", symbol: "exclamationmark.triangle")
                }
                let result = CaptureResult(image: image, kind: .scrolling, rect: rect, scale: scale)
                return CapturedImage(result: result, hdrImage: nil, intent: .capture)
            case .cancelled:
                return nil
            case .lowConfidence:
                guard mode == .automatic, PermissionPrompt.offerManualAfterLowConfidence() else { return nil }
                mode = .manual
            case let .failed(message):
                throw CaptureError.failed(message)
            }
        }
    }

    /// Automatic scrolling posts events, which needs Accessibility; without it the user scrolls (manual mode).
    private func scrollingMode() async -> ScrollingMode {
        if permissions.status(of: .accessibility) == .granted {
            return .automatic
        }
        if await permissions.request(.accessibility) == .granted {
            return .automatic
        }
        Toast.show("Scroll yourself: automatic scrolling needs the Accessibility permission", symbol: "hand.draw")
        return .manual
    }
}
