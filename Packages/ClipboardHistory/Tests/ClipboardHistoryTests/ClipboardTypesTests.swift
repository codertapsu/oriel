@testable import ClipboardHistory
import Foundation
import SharedUI
import Testing

struct ClipboardTypesTests {
    @Test func filesKeepOnlyTheirURLAndName() {
        let kept = ClipboardTypes.kept([ClipboardTypes.fileURL, "com.apple.icns", ClipboardTypes.plainText, "com.apple.finder.node"])
        #expect(kept == [ClipboardTypes.fileURL, ClipboardTypes.plainText])
    }

    @Test func aPNGMakesTheTIFFRedundant() {
        #expect(ClipboardTypes.kept([ClipboardTypes.png, ClipboardTypes.tiff]) == [ClipboardTypes.png])
        #expect(ClipboardTypes.kept([ClipboardTypes.tiff]) == [ClipboardTypes.tiff])
    }

    @Test func promisesArchivesAndMarkersGo() {
        let kept = ClipboardTypes.kept([
            ClipboardTypes.plainText, "com.apple.webarchive", "com.apple.pasteboard.promised-file-url",
            "org.nspasteboard.TransientType", "com.example.private",
        ])
        #expect(kept == [ClipboardTypes.plainText, "com.example.private"])
    }

    @Test func keptSnapshotsDropEmptiedItems() {
        let snapshot = PasteboardSnapshot(items: [
            [.init(type: "com.apple.webarchive", data: Data([1]))],
            [.init(type: ClipboardTypes.png, data: Data([2])), .init(type: ClipboardTypes.tiff, data: Data([3]))],
        ])
        let kept = ClipboardTypes.kept(snapshot)
        #expect(kept.items.count == 1)
        #expect(kept.types == [ClipboardTypes.png])
    }

    @Test func passwordManagersAreKeptOut() {
        #expect(PrivacyFilter.isMarkedPrivate([ClipboardTypes.plainText, "org.nspasteboard.ConcealedType"]))
        #expect(PrivacyFilter.isMarkedPrivate(["com.agilebits.onepassword"]))
        #expect(!PrivacyFilter.isMarkedPrivate([ClipboardTypes.plainText, ClipboardTypes.rtf]))
        #expect(PrivacyFilter.ignores(bundleID: "COM.APPLE.Passwords", in: PrivacyFilter.defaultIgnoredApps))
        #expect(!PrivacyFilter.ignores(bundleID: "com.apple.Safari", in: PrivacyFilter.defaultIgnoredApps))
        #expect(!PrivacyFilter.ignores(bundleID: nil, in: PrivacyFilter.defaultIgnoredApps))
    }

    @Test func accessFollowsThePasteboardBehavior() {
        #expect(ClipboardAccess(.alwaysAllow) == .allowed)
        #expect(ClipboardAccess(.default) == .notAsked)
        #expect(ClipboardAccess(.ask) == .asks)
        #expect(ClipboardAccess(.alwaysDeny) == .denied)
        #expect(ClipboardAccess.allowed.readsOtherApps && ClipboardAccess.notAsked.readsOtherApps)
        #expect(!ClipboardAccess.asks.readsOtherApps && !ClipboardAccess.denied.readsOtherApps)
    }
}
