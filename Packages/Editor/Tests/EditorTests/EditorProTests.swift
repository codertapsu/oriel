@testable import Editor
import OrielCore
import Testing

/// The editor's Pro tools and export formats (PLAN §19); every other tool and format is free.
struct EditorProTests {
    @Test func numberedStepsAndSpotlightAreTheProTools() {
        #expect(Set(EditorTool.allCases.compactMap(\.proFeature)) == [.numberedSteps, .spotlight])
    }

    @Test func heicAndPDFAreTheProFormats() {
        #expect(Set(EditorExportFormat.allCases.filter(\.isPro)) == [.heic, .pdf])
    }
}
