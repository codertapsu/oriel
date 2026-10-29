import CoreGraphics
import Foundation
import ImageIO
import OrielCore
@testable import Recording
import Testing

@MainActor
struct VideoEditorSessionTests {
    private func session(clicks: [ClickRecord]? = nil) -> VideoEditorSession {
        let info = MovieInfo(
            url: URL(filePath: "/tmp/movie.mp4"),
            duration: 30,
            videoTrackID: 1,
            size: CGSize(width: 1920, height: 1080),
            orientation: .up,
            frameRate: 30,
            hasAudio: false,
            codec: .h264
        )
        let sidecar = clicks.map { ClickSidecar(width: 1920, height: 1080, duration: 30, clicks: $0) }
        return VideoEditorSession(info: info, clicks: sidecar)
    }

    @Test func undoesAndRedoesWholeSteps() {
        let session = session()
        session.setTrimStart(at: 5)
        session.addChapter(at: 10)
        #expect(session.edit.trimStart == 5)
        #expect(session.edit.chapters.count == 1)
        #expect(session.canUndo)

        session.undo()
        #expect(session.edit.chapters.isEmpty)
        #expect(session.edit.trimStart == 5)
        session.undo()
        #expect(session.edit.trimStart == nil)
        #expect(!session.canUndo)

        session.redo()
        session.redo()
        #expect(session.edit.chapters.count == 1)
        #expect(session.undoManager.undoActionName == "Add Chapter")
    }

    @Test func coalescesASliderDragIntoOneStep() throws {
        let session = session()
        let id = try #require(session.addZoom(at: 2))
        for scale in [1.6, 1.8, 2.2, 2.6] {
            session.setZoomScale(id, scale: scale)
        }
        #expect(session.selectedZoom?.scale == 2.6)

        session.undo()
        #expect(session.selectedZoom?.scale == 2)
    }

    @Test func aDragIsOneStepFromWhereItBegan() throws {
        let session = session()
        let id = try #require(session.addZoom(at: 2))
        let snapshot = session.edit
        for start in [3.0, 4.0, 6.0] {
            var moved = snapshot
            moved.moveZoom(id, toStart: start, duration: 30)
            session.preview(moved)
        }
        session.finish(from: snapshot, actionName: "Move Zoom")
        #expect(session.edit.zoomSegment(id)?.start == 6)

        session.undo()
        #expect(session.edit.zoomSegment(id)?.start == 2)
    }

    @Test func undoingAnAddLeavesNothingSelected() {
        let session = session()
        session.addChapter(at: 4)
        #expect(session.selectedChapter != nil)
        session.undo()
        #expect(session.selection == nil)
    }

    @Test func deletesTheSelection() {
        let session = session()
        session.addZoom(at: 3)
        session.addChapter(at: 8)
        session.deleteSelection()
        #expect(session.edit.chapters.isEmpty)
        #expect(session.edit.zoomSegments.count == 1)
        #expect(session.selection == nil)
        session.deleteSelection()
        #expect(session.edit.zoomSegments.count == 1)
    }

    @Test func knowsWhenClosingWouldLoseEdits() {
        let session = session()
        #expect(!session.hasUnexportedChanges)
        session.addChapter(at: 4)
        #expect(session.hasUnexportedChanges)
        session.markExported()
        #expect(!session.hasUnexportedChanges)
        session.setTrimEnd(at: 20)
        #expect(session.hasUnexportedChanges)
        session.undo()
        #expect(!session.hasUnexportedChanges)
    }

    @Test func autoZoomUsesTheSavedClicks() {
        let session = session(clicks: [ClickRecord(time: 5, x: 0.2, y: 0.2), ClickRecord(time: 20, x: 0.8, y: 0.8)])
        session.autoZoom = AutoZoomSettings(level: 2.5, hold: 1)

        #expect(session.applyAutoZoom() == 2)
        #expect(session.edit.zoomSegments.map(\.scale) == [2.5, 2.5])
        session.undo()
        #expect(session.edit.zoomSegments.isEmpty)

        let plain = self.session()
        #expect(plain.clicks == nil)
        #expect(plain.applyAutoZoom() == 0)
    }

    @Test func treatsAnEmptySidecarAsNoClicks() {
        #expect(session(clicks: []).clicks == nil)
    }

    @Test func notifiesTheViews() {
        let session = session()
        var changes = 0
        session.onChange = { changes += 1 }
        session.addChapter(at: 1)
        session.select(nil)
        #expect(changes >= 2)
    }
}

struct VideoEditorShortcutsTests {
    private func command(_ characters: String, _ keyCode: UInt16, _ modifiers: KeyCombo.Modifiers = []) -> VideoEditorCommand? {
        VideoEditorShortcuts.command(characters: characters, keyCode: keyCode, modifiers: modifiers)
    }

    @Test func mapsTheEditingKeys() {
        #expect(command(" ", KeyCode.space) == .playPause)
        #expect(command("j", KeyCode.ansiJ) == .reverse)
        #expect(command("k", KeyCode.ansiK) == .stop)
        #expect(command("l", 37) == .forward)
        #expect(command("i", KeyCode.ansiI) == .setTrimStart)
        #expect(command("o", KeyCode.ansiO) == .setTrimEnd)
        #expect(command("m", KeyCode.ansiM) == .addChapter)
        #expect(command("z", 6) == .addZoom)
        #expect(command("", KeyCode.leftArrow) == .stepFrames(-1))
        #expect(command("", KeyCode.rightArrow, .shift) == .stepSeconds(1))
        #expect(command("", KeyCode.upArrow) == .previousChapter)
        #expect(command("", KeyCode.downArrow) == .nextChapter)
        #expect(command("", KeyCode.delete) == .delete)
        #expect(command("", KeyCode.escape) == .deselect)
        #expect(command("", 115) == .goToStart)
        #expect(command("", 119) == .goToEnd)
    }

    @Test func optionClearsTheTrim() {
        // ⌥I types "ˆ" on a US layout; the key code still says I.
        #expect(command("ˆ", KeyCode.ansiI, .option) == .clearTrimStart)
        #expect(command("ø", KeyCode.ansiO, .option) == .clearTrimEnd)
    }

    @Test func mapsTheCommandKeys() {
        #expect(command("z", 6, .command) == .undo)
        #expect(command("Z", 6, [.command, .shift]) == .redo)
        #expect(command("c", KeyCode.ansiC, [.command, .shift]) == .copyFrameText)
        #expect(command("e", KeyCode.ansiE, .command) == .export)
        #expect(command("o", KeyCode.ansiO, .command) == .open)
        #expect(command("w", KeyCode.ansiW, .command) == .close)
        #expect(command("=", KeyCode.ansiEqual, .command) == .zoomTimelineIn)
        #expect(command("-", KeyCode.ansiMinus, .command) == .zoomTimelineOut)
        #expect(command("0", 29, .command) == .fitTimeline)
    }

    @Test func leavesOtherKeysAlone() {
        #expect(command("c", KeyCode.ansiC, .command) == nil)
        #expect(command("q", KeyCode.ansiQ) == nil)
        #expect(command("m", KeyCode.ansiM, .control) == nil)
        #expect(command("M", KeyCode.ansiM, .shift) == nil)
        #expect(command("e", KeyCode.ansiE, [.command, .option]) == nil)
    }

    @Test func knowsWhichCommandsAreArrows() {
        #expect(VideoEditorCommand.stepFrames(1).usesArrowKeys)
        #expect(VideoEditorCommand.nextChapter.usesArrowKeys)
        #expect(!VideoEditorCommand.playPause.usesArrowKeys)
    }
}
