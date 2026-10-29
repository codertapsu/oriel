@testable import DiskAnalyzer
import Foundation
import Testing

/// Duplicate grouping: size, then partial hash, then full hash; clones count once; keep the newest or the oldest.
struct DuplicateGrouperTests {
    private func candidate(_ node: Int32, size: Int64, path: String, clone: UInt64? = nil) -> DuplicateGrouper.Candidate {
        DuplicateGrouper.Candidate(node: node, size: size, allocated: size, path: path, cloneID: clone)
    }

    @Test func onlySizesSharedByTwoOrMoreFilesAreKept() {
        let groups = DuplicateGrouper.sizeGroups(
            [
                candidate(1, size: 5_000_000, path: "/a"), candidate(2, size: 5_000_000, path: "/b"),
                candidate(3, size: 7_000_000, path: "/c"), candidate(4, size: 9_000_000, path: "/d"),
                candidate(5, size: 9_000_000, path: "/e"), candidate(6, size: 9_000_000, path: "/f"),
                candidate(7, size: 100, path: "/tiny1"), candidate(8, size: 100, path: "/tiny2"),
            ],
            minimumSize: 1_000_000
        )
        #expect(groups.map { $0.map(\.node) } == [[4, 5, 6], [1, 2]])
    }

    @Test func eachStageSplitsGroupsAndDropsLoneFiles() {
        let groups = [[candidate(1, size: 9, path: "/a"), candidate(2, size: 9, path: "/b"), candidate(3, size: 9, path: "/c")]]
        let partial = DuplicateGrouper.split(groups) { $0.node == 3 ? "different" : "same" }
        #expect(partial.map { $0.map(\.node) } == [[1, 2]])
        let unreadable = DuplicateGrouper.split(groups) { $0.node == 1 ? nil : "same" }
        #expect(unreadable.map { $0.map(\.node) } == [[2, 3]])
    }

    @Test func reclaimableSpaceCountsClonesOnce() {
        let plain = [candidate(1, size: 100, path: "/a"), candidate(2, size: 100, path: "/b"), candidate(3, size: 100, path: "/c")]
        #expect(DuplicateGrouper.reclaimable(plain) == 200)
        let cloned = [
            candidate(1, size: 100, path: "/a", clone: 77), candidate(2, size: 100, path: "/b", clone: 77),
            candidate(3, size: 100, path: "/c"),
        ]
        #expect(DuplicateGrouper.reclaimable(cloned) == 100)
        let allClones = [candidate(1, size: 100, path: "/a", clone: 5), candidate(2, size: 100, path: "/b", clone: 5)]
        #expect(DuplicateGrouper.reclaimable(allClones) == 0)
    }

    @Test func groupsComeLargestWasteFirst() {
        let parts = [
            [candidate(1, size: 10, path: "/a"), candidate(2, size: 10, path: "/b")],
            [candidate(3, size: 50, path: "/c"), candidate(4, size: 50, path: "/d"), candidate(5, size: 50, path: "/e")],
        ]
        let groups = DuplicateGrouper.groups(parts) { "hash-\($0[0].node)" }
        #expect(groups.map(\.id) == ["hash-3", "hash-1"])
        #expect(groups.first?.reclaimable == 100)
    }

    @Test func selectingAllButOneKeepsTheNewestOrTheOldest() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let dates: [Int32: Date] = [1: base, 2: base.addingTimeInterval(100), 3: base.addingTimeInterval(-100), 4: base, 5: base]
        let paths: [Int32: String] = [1: "/x/a", 2: "/x/b", 3: "/x/c", 4: "/long/path/d", 5: "/d"]
        let groups = [
            DuplicateGroup(id: "one", size: 1, files: [1, 2, 3], reclaimable: 2),
            DuplicateGroup(id: "two", size: 1, files: [4, 5], reclaimable: 1),
        ]
        let newest = DuplicateSelection.allButOne(groups, keep: .newest, modified: { dates[$0] }, path: { paths[$0] ?? "" })
        #expect(newest == [1, 3, 4])
        let oldest = DuplicateSelection.allButOne(groups, keep: .oldest, modified: { dates[$0] }, path: { paths[$0] ?? "" })
        #expect(oldest == [1, 2, 4])
    }
}
