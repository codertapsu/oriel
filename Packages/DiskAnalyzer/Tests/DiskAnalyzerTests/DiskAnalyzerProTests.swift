@testable import DiskAnalyzer
import OrielCore
import Testing

/// Old Files and Duplicates are the Pro views (PLAN §19); every other view is free.
struct DiskAnalyzerProTests {
    @Test func oldFilesAndDuplicatesAreTheProViews() {
        #expect(Set(DiskView.allCases.compactMap(\.proFeature)) == [.oldFiles, .duplicates])
    }
}
