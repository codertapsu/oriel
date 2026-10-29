import AppKit
import CoreGraphics
import OrielCore
import OrielTestSupport
@testable import ScreenRuler
import Testing

/// What each display draws in each mode, and the hint bar.
struct RulerSceneTests {
    private let retina = RulerDisplay(id: 1, frame: CGRect(x: 0, y: 0, width: 400, height: 300), scale: 2)
    private let external = RulerDisplay(id: 2, frame: CGRect(x: 400, y: 0, width: 800, height: 600), scale: 1)

    private func session(_ mode: RulerMode, status: EdgeStatus = .ready) -> RulerSession {
        var session = RulerSession(displays: [retina, external], mode: mode, unit: .points, tolerance: 5, edgeStatus: status)
        var bitmap = SyntheticBitmap(width: 800, height: 600)
        bitmap.fill(x: 100, y: 50, width: 200, height: 100, gray: 0)
        if status == .ready {
            session.setEdgeMap(bitmap.map, for: retina.id)
        }
        return session
    }

    @Test func measureAreaLabelsTheAreaInBothUnitsAndItsPosition() {
        var ruler = session(.measureArea)
        _ = ruler.mouseDown(at: CGPoint(x: 20, y: 30), clickCount: 1)
        ruler.mouseDragged(to: CGPoint(x: 120, y: 80), square: false, snaps: false)
        _ = ruler.mouseUp(at: CGPoint(x: 120, y: 80))
        let scene = RulerSceneBuilder.scene(for: retina, session: ruler)
        #expect(scene.area == CGRect(x: 20, y: 30, width: 100, height: 50))
        #expect(scene.showsHandles)
        #expect(scene.labels.first?.text == "100 × 50 pt")
        #expect(scene.labels.first?.detail == "200 × 100 px   x 20  y 30")
        #expect(scene.crosshair == nil, "the crosshair steps aside once there is an area")
        #expect(RulerSceneBuilder.scene(for: external, session: ruler).area == nil, "the other display draws nothing")
    }

    @Test func beforeAnAreaThePointerHasACrosshairAndItsPosition() {
        var ruler = session(.measureArea)
        ruler.pointerMoved(to: CGPoint(x: 600.4, y: 120.6))
        let scene = RulerSceneBuilder.scene(for: external, session: ruler)
        #expect(scene.crosshair == CGPoint(x: 600.4, y: 120.6))
        #expect(scene.labels.map(\.text) == ["x 200  y 121"])
        #expect(RulerSceneBuilder.scene(for: retina, session: ruler).crosshair == nil)
    }

    @Test func dimensionsDrawsTheCrossTheBoxAndTheArms() {
        var ruler = session(.dimensions)
        ruler.pointerMoved(to: CGPoint(x: 100, y: 50))
        let scene = RulerSceneBuilder.scene(for: retina, session: ruler)
        #expect(scene.measuredBox == CGRect(x: 50, y: 25, width: 100, height: 50))
        #expect(scene.segments == [
            RulerScene.Segment(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 150, y: 50)),
            RulerScene.Segment(from: CGPoint(x: 100, y: 25), to: CGPoint(x: 100, y: 75)),
        ])
        #expect(scene.labels.first?.text == "100 × 50 pt")
        // Arms of 50 points are labelled; the vertical ones, 25 points, are too short for a badge.
        #expect(scene.labels.dropFirst().map(\.text) == ["50", "50"])
        #expect(scene.notice == nil)
    }

    @Test func dimensionsExplainsWhatIsMissing() {
        var blind = session(.dimensions, status: .notPermitted)
        blind.pointerMoved(to: CGPoint(x: 100, y: 50))
        #expect(RulerSceneBuilder.scene(for: retina, session: blind).notice == .screenRecordingNeeded)
        #expect(RulerSceneBuilder.scene(for: external, session: blind).notice == nil, "only where the pointer is")
        var broken = session(.dimensions, status: .failed("The capture timed out."))
        broken.pointerMoved(to: CGPoint(x: 100, y: 50))
        #expect(RulerSceneBuilder.scene(for: retina, session: broken).notice?.title == "Screen Ruler could not read the screen")
        var waiting = session(.dimensions, status: .reading)
        waiting.pointerMoved(to: CGPoint(x: 100, y: 50))
        #expect(RulerSceneBuilder.scene(for: retina, session: waiting).labels.map(\.text) == ["Reading the screen…"])
        var other = session(.dimensions)
        other.pointerMoved(to: CGPoint(x: 600, y: 50))
        #expect(RulerSceneBuilder.scene(for: external, session: other).labels.map(\.text) == ["This display could not be read"])
    }

    @Test func guidesShowTheDistancesAlongThePointersRow() {
        var ruler = session(.guides)
        _ = ruler.mouseDown(at: CGPoint(x: 600, y: 100), clickCount: 1)
        _ = ruler.mouseUp(at: CGPoint(x: 600, y: 100))
        ruler.pointerMoved(to: CGPoint(x: 900, y: 300))
        let scene = RulerSceneBuilder.scene(for: external, session: ruler)
        #expect(scene.guides == [
            RulerScene.GuideLine(orientation: .vertical, position: 600, isSelected: true),
            RulerScene.GuideLine(orientation: .vertical, position: 900, isPreview: true),
        ])
        // From the left edge to the guide, to the pointer's preview line, to the right edge.
        #expect(scene.segments.map { $0.to.x - $0.from.x } == [200, 300, 300])
        #expect(scene.labels.map(\.text) == ["200", "300", "300"])
    }

    @Test func theHintBarNamesEachModesKeys() {
        var ruler = session(.dimensions)
        let dimensions = RulerSceneBuilder.hint(for: ruler)
        #expect(dimensions.instruction == "Click to keep, drag around to fit")
        #expect(dimensions.keys.first == KeyHint(key: "[ ]", label: "Tolerance 5%"))
        #expect(dimensions.keys.suffix(4).map(\.key) == ["⇥", "U", "⌘C", "⎋"])
        _ = ruler.handle(.toggleUnit)
        #expect(RulerSceneBuilder.hint(for: ruler).keys.contains(KeyHint(key: "U", label: "Pixels")))
        _ = ruler.handle(.mode(.guides))
        #expect(RulerSceneBuilder.hint(for: ruler).keys.first == KeyHint(key: "Space", label: "Switch to horizontal"))
        _ = ruler.handle(.flipGuide)
        #expect(RulerSceneBuilder.hint(for: ruler).keys.first == KeyHint(key: "Space", label: "Switch to vertical"))
    }
}

struct RulerSystemTests {
    /// A screenshot is read top row first, in sRGB, so pixel (0, 0) is the display's top-left corner.
    @Test func aScreenshotBecomesAnEdgeMapTopRowFirst() throws {
        let width = 4
        let height = 3
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        // CoreGraphics' y grows upwards, so the top row is y = height − 1.
        context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: height - 1, width: 1, height: 1))
        let image = try #require(context.makeImage())
        let map = try #require(EdgeMap(image: image))
        #expect(map.width == 4 && map.height == 3)
        #expect(map.pixel(x: 0, y: 0) == EdgeMap.pixel(red: 255, green: 0, blue: 0))
        #expect(map.pixel(x: 0, y: 2) == EdgeMap.pixel(red: 255, green: 255, blue: 255))
        #expect(map.horizontalSpan(row: 0, column: 2, tolerance: 10) == (1, 4))
    }

    @Test func theLineColorIsKeptAsHex() throws {
        let color = try #require(RulerColor.color(hex: "#FF2D55"))
        #expect(RulerColor.hex(of: color) == "#FF2D55")
        #expect(RulerColor.color(hex: "00ff80").map(RulerColor.hex) == "#00FF80")
        #expect(RulerColor.color(hex: "#FFF") == nil)
        #expect(RulerColor.color(hex: "orange") == nil)
    }

    @Test func percentsBecomeChannelDifferences() {
        #expect(RulerSettings.channelTolerance(percent: 0) == 0)
        #expect(RulerSettings.channelTolerance(percent: 5) == 13)
        #expect(RulerSettings.channelTolerance(percent: 100) == 255)
        #expect(RulerSettings.channelTolerance(percent: 400) == 255)
    }

    /// Captures the real screen, so it runs only with ORIEL_TCC_TESTS=1 on a Mac that granted Screen Recording.
    @Test(.requiresTCC) @MainActor
    func theScreenIsCapturedAtItsPixelSize() async throws {
        let screen = try #require(NSScreen.main)
        let id = try #require(screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber).uint32Value
        let display = RulerDisplay(id: id, cocoaFrame: screen.frame, primaryHeight: screen.frame.height, scale: screen.backingScaleFactor)
        let images = try await ScreenCaptureKitCapture().capture([display])
        let image = try #require(images[id])
        #expect(image.width == display.pixelWidth && image.height == display.pixelHeight)
        #expect(EdgeMap(image: image) != nil)
    }
}

@MainActor
struct RulerOverlayTests {
    @Test func theRulerOpensAsSettingsSayAndReadsTheScreenOnlyWhenAllowed() {
        let settings = SettingsStore(defaults: UserDefaults(suiteName: "ScreenRulerTests-\(UUID().uuidString)") ?? .standard)
        let denied = RulerOverlay(
            settings: settings,
            permissions: FakePermissions(.notDetermined),
            capture: FakeCapture(),
            copier: { _ in },
            screens: []
        )
        #expect(denied.session.mode == .dimensions)
        #expect(denied.session.unit == .points)
        #expect(denied.session.tolerance == 5)
        #expect(denied.session.edgeStatus == .notPermitted)
        #expect(!denied.isOpen)
        let allowed = RulerOverlay(
            settings: settings,
            permissions: FakePermissions(.granted),
            capture: FakeCapture(),
            copier: { _ in },
            screens: []
        )
        #expect(allowed.session.edgeStatus == .reading)
    }
}

/// A permission state that never changes and never prompts.
@MainActor
final class FakePermissions: PermissionChecking {
    private let screenRecording: PermissionStatus

    init(_ screenRecording: PermissionStatus) {
        self.screenRecording = screenRecording
    }

    func status(of kind: PermissionKind) -> PermissionStatus {
        kind == .screenRecording ? screenRecording : .notDetermined
    }

    func request(_ kind: PermissionKind) async -> PermissionStatus {
        status(of: kind)
    }

    func openSystemSettings(for _: PermissionKind) {}
}

/// Takes no pictures.
@MainActor
final class FakeCapture: DisplayCapturing {
    func capture(_: [RulerDisplay]) async throws -> [CGDirectDisplayID: CGImage] {
        [:]
    }
}
