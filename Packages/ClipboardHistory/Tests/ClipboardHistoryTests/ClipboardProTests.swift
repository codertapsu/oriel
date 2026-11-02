@testable import ClipboardHistory
import Foundation
import OrielCore
import Testing

/// What the panel shows without Oriel Pro: the last hundred items from the past week, no search through text read from
/// images, no ⌘-numbers and five pins (PLAN §19). The history itself keeps everything.
@MainActor
struct ClipboardProTests {
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func model(pro: Bool, history: [ClipboardItem], pinned: [ClipboardItem] = []) -> ClipboardPanelModel {
        var index = ClipboardIndex()
        index.pinned = pinned
        index.history = history
        let model = ClipboardPanelModel()
        model.allows = { _ in pro }
        model.now = { [now] in now }
        model.update(index)
        return model
    }

    private func items(_ count: Int, daysAgo days: Double = 0) -> [ClipboardItem] {
        (0 ..< count).map { Fixtures.item("item \(days) \($0)", date: now.addingTimeInterval(-days * 86400 - Double($0))) }
    }

    @Test func withoutProTheLastHundredFromThePastWeekShow() {
        let history = items(120) + items(3, daysAgo: 8)
        #expect(model(pro: false, history: history).rows.count == ClipboardPanelModel.freeCount)
        #expect(model(pro: false, history: items(3, daysAgo: 8)).rows.isEmpty, "older than a week")
        #expect(model(pro: true, history: history).rows.count == 123)
    }

    @Test func textReadFromImagesIsSearchedWithPro() {
        var screenshot = Fixtures.item("Screenshot", kind: .image, date: now)
        screenshot.recognizedText = "Invoice 2048"
        for pro in [false, true] {
            let model = model(pro: pro, history: [screenshot])
            model.query = "invoice"
            #expect(model.rows.count == (pro ? 1 : 0))
        }
    }

    @Test func quickPasteNumbersComeWithPro() {
        #expect(model(pro: false, history: items(3)).quickPasteNumber(forRow: 0) == nil)
        let model = model(pro: true, history: items(12))
        #expect(model.quickPasteNumber(forRow: 0) == 1)
        #expect(model.quickPasteNumber(forRow: 8) == 9)
        #expect(model.quickPasteNumber(forRow: 9) == nil)
    }

    @Test func fivePinsFitWithoutPro() {
        let model = model(pro: false, history: [], pinned: items(4))
        #expect(model.fitsFreePins(adding: 1))
        #expect(!model.fitsFreePins(adding: 2))
    }
}
