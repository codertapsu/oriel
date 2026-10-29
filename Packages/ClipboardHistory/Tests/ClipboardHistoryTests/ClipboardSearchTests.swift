@testable import ClipboardHistory
import Foundation
import Testing

struct ClipboardSearchTests {
    @Test func everyWordHasToMatchIgnoringCaseAndAccents() {
        let item = Fixtures.item("Café meeting notes for Thursday", source: "Notes")
        #expect(ClipboardSearch.matches(item, terms: ClipboardSearch.terms(in: "cafe THURSDAY")))
        #expect(ClipboardSearch.matches(item, terms: ClipboardSearch.terms(in: "  ")))
        #expect(!ClipboardSearch.matches(item, terms: ClipboardSearch.terms(in: "cafe friday")))
    }

    @Test func theSourceAppKindFileNamesAndImageTextAreSearched() {
        var image = Fixtures.item("Screenshot · 100 × 80", kind: .image, source: "Oriel")
        image.recognizedText = "Invoice total 1 280 €"
        #expect(ClipboardSearch.matches(image, terms: ["invoice"]))
        #expect(ClipboardSearch.matches(image, terms: ["oriel", "image"]))
        var files = Fixtures.item("report.pdf", kind: .files)
        files.fileURLs = [URL(filePath: "/Users/me/Desktop/report.pdf"), URL(filePath: "/Users/me/budget.numbers")]
        #expect(ClipboardSearch.matches(files, terms: ["budget"]))
    }

    @Test func typeFiltersPassTheirKinds() {
        #expect(ClipboardFilter.text.includes(.richText))
        #expect(ClipboardFilter.text.includes(.text))
        #expect(!ClipboardFilter.text.includes(.link))
        #expect(ClipboardFilter.images.includes(.image))
        #expect(ClipboardFilter.all.includes(.other))
        #expect(ClipboardFilter.pinned.includes(.files))
        #expect(!ClipboardFilter.colors.includes(.text))
    }
}
