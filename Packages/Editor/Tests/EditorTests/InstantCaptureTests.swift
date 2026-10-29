import AppKit
import CoreGraphics
@testable import Editor
import Foundation
import OrielCore
import Testing

/// Instant Capture's controller (PLAN §17), built but never shown: its panel and canvas match the selection, its keys
/// map to the instant tools and actions, and Open in Editor hands the same session over. Copy and Save are left out:
/// they would write to the real clipboard and show a save panel.
@MainActor
struct InstantCaptureTests {
    private let screens = [
        InstantPlacement.Screen(
            frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
            visibleFrame: CGRect(x: 0, y: 70, width: 1440, height: 805),
            scale: 2
        ),
    ]

    /// A 300×200 pt capture at 2×, selected at (400, 200) in CoreGraphics points.
    private func makeController(scale: CGFloat = 2, showsUpload: Bool = false) throws -> InstantCaptureController {
        let image = try #require(TestImages.halves(width: Int(300 * scale), height: Int(200 * scale)))
        let session = EditorSession(document: EditorDocument(base: ImageRef(image: image, scale: scale)))
        return try #require(InstantCaptureController(
            session: session, captureID: UUID(), selection: CGRect(x: 400, y: 200, width: 300, height: 200),
            screens: screens, primaryHeight: 900, showsUpload: showsUpload
        ))
    }

    @Test func thePanelSitsOverTheSelectionWithTheImageAtOneToOne() throws {
        let controller = try makeController()
        #expect(controller.placement.canvasFrame == CGRect(x: 400, y: 500, width: 300, height: 200))
        #expect(controller.panel.frame == controller.placement.panelFrame)
        #expect(controller.canvas.frame.size == CGSize(width: 300, height: 200))
        #expect(controller.session.zoom == 1 && !controller.session.zoomsToFit)
        #expect(!controller.panel.isVisible && controller.panel.canBecomeKey && !controller.panel.canBecomeMain)
        #expect(controller.panel.level == .statusBar && !controller.panel.hasShadow)
        #expect(controller.session.document.background == nil)
    }

    @Test func aCaptureOfAnotherScaleIsZoomedToFillTheSelectionExactly() throws {
        let controller = try makeController(scale: 1)
        #expect(controller.session.zoom == 1)
        let image = try #require(TestImages.halves(width: 150, height: 100))
        let session = EditorSession(document: EditorDocument(base: ImageRef(image: image, scale: 1)))
        let mismatched = try #require(InstantCaptureController(
            session: session, captureID: UUID(), selection: CGRect(x: 400, y: 200, width: 300, height: 200),
            screens: screens, primaryHeight: 900, showsUpload: false
        ))
        #expect(mismatched.session.zoom == 2)
    }

    @Test func keysPickOnlyTheInstantToolsAndDrawOnTheCanvas() throws {
        let controller = try makeController()
        let session = controller.session
        #expect(controller.perform(.tool(.arrow)))
        #expect(session.tool == .arrow)
        #expect(!controller.perform(.tool(.crop)))
        #expect(!controller.perform(.tool(.spotlight)))
        #expect(session.tool == .arrow)
        session.drag(from: CGPoint(x: 20, y: 20), to: CGPoint(x: 120, y: 80))
        #expect(session.document.items.count == 1)
        #expect(controller.perform(.undo))
        #expect(session.document.items.isEmpty)
        #expect(controller.perform(.redo))
        #expect(session.document.items.count == 1)
        #expect(!controller.perform(.zoomIn))
        #expect(InstantToolbar.tools == [
            .select,
            .pen,
            .arrow,
            .line,
            .rectangle,
            .ellipse,
            .highlighter,
            .text,
            .counter,
            .blur,
            .pixelate,
        ])
    }

    @Test func escapeEndsADragFirstThenCloses() throws {
        let controller = try makeController()
        var closed = 0
        controller.onClose = { _ in closed += 1 }
        let session = controller.session
        session.selectTool(.rectangle)
        session.beginGesture(at: CGPoint(x: 10, y: 10))
        session.continueGesture(to: CGPoint(x: 80, y: 60))
        controller.perform(.cancel)
        #expect(session.document.items.isEmpty && session.gesture == nil)
        #expect(!controller.isClosed && closed == 0)
        controller.perform(.cancel)
        #expect(controller.isClosed && closed == 1)
        // Closing twice does nothing more.
        controller.run(.close)
        #expect(closed == 1)
    }

    @Test func openInEditorHandsOverTheSameSessionWithItsHistory() throws {
        let controller = try makeController()
        let session = controller.session
        session.selectTool(.counter)
        session.click(at: CGPoint(x: 50, y: 50))
        var handedOver: EditorSession?
        controller.onOpenInEditor = { handedOver = $0 }
        controller.run(.openInEditor)
        #expect(handedOver === session)
        #expect(controller.isClosed)
        #expect(session.document.items.count == 1 && session.canUndo)
        #expect(session.onChange == nil)
        // An editor window takes it from there.
        let window = EditorWindowController(session: session)
        #expect(window.session === session)
    }

    @Test func uploadAppearsOnlyWhenThereIsSomewhereToUpload() throws {
        let without = try makeController()
        let with = try makeController(showsUpload: true)
        #expect(with.toolbar.fittingSize.width > without.toolbar.fittingSize.width)
    }

    @Test func instantSessionsSkipTheDefaultBackground() throws {
        let suiteName = "com.codertapsu.oriel.tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = SettingsStore(defaults: defaults)
        settings[EditorSettings.backgroundPreset] = .ocean
        settings[EditorSettings.defaultColor] = .green
        let launcher = EditorLauncher(settings: settings)
        let capture = try CaptureResult(
            image: #require(TestImages.halves(width: 200, height: 100)), kind: .area, rect: CGRect(x: 0, y: 0, width: 100, height: 50),
            scale: 2
        )
        let session = launcher.makeInstantSession(for: capture)
        #expect(session.document.background == nil && session.document.canvasPadding == nil)
        #expect(session.color == .green)
        #expect(launcher.makeSession(for: capture).document.background != nil)
        #expect(launcher.openInstantCount == 0)
    }

    @Test func thePanelRoutesEditorKeys() throws {
        let controller = try makeController()
        let key = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
            characters: "r", charactersIgnoringModifiers: "r", isARepeat: false, keyCode: 15
        ))
        controller.panel.keyDown(with: key)
        #expect(controller.session.tool == .rectangle)
        let undo = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: .command, timestamp: 0, windowNumber: 0, context: nil,
            characters: "z", charactersIgnoringModifiers: "z", isARepeat: false, keyCode: 6
        ))
        controller.session.drag(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 60, y: 40))
        #expect(controller.session.document.items.count == 1)
        #expect(controller.panel.performKeyEquivalent(with: undo))
        #expect(controller.session.document.items.isEmpty)
    }
}
