@testable import Capture
import CoreGraphics
import Foundation
import OrielCore
import Testing

/// Without Oriel Pro the history window shows the latest captures, unsearched; it keeps every capture, so unlocking
/// Pro shows them all (PLAN §19).
@MainActor
struct HistoryProTests {
    @Test func withoutProTheLatestCapturesShowUnsearched() async throws {
        let directory = try TestImages.temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = HistoryStore(directory: directory)
        for index in (0 ..< HistoryModel.freeCount + 5).reversed() {
            _ = try await store.add(CaptureResult(
                image: TestImages.quadrants(width: 20, height: 20),
                kind: .area,
                rect: CGRect(x: 0, y: 0, width: 10, height: 10),
                scale: 2,
                date: Date().addingTimeInterval(-Double(index) * 60),
                windowTitle: "Capture \(index)",
                appName: "Preview"
            ))
        }
        let access = ProAccess(isUnlocked: false)
        let model = HistoryModel(store: store, access: access)
        await model.reload()
        model.query = "Capture 24"
        #expect(model.filtered.count == HistoryModel.freeCount, "the search waits for Pro")
        #expect(model.filtered.first?.windowTitle == "Capture 0", "newest first")

        access.setUnlocked(true)
        #expect(model.filtered.map(\.windowTitle) == ["Capture 24"])
        model.query = ""
        #expect(model.filtered.count == HistoryModel.freeCount + 5)
    }
}
