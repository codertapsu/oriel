@testable import ActivityMonitor
import Testing

/// Filtering, searching and sorting the list.
struct ProcessListTests {
    @Test func viewFiltersPickTheirProcesses() {
        let mine = Fixtures.process(10)
        let root = Fixtures.process(11, uid: 0)
        let service = Fixtures.process(12, uid: 88)
        let app = Fixtures.process(13, app: Fixtures.app("Notes", bundle: "/System/Applications/Notes.app"))
        let agent = Fixtures.process(14, app: Fixtures.app("Agent", bundle: "/Applications/Agent.app", regular: false))
        let all = [mine, root, service, app, agent]
        func shown(_ filter: ViewFilter) -> [Int32] {
            all.filter { filter.includes($0, myUID: Fixtures.me) }.map(\.pid)
        }
        #expect(shown(.all) == [10, 11, 12, 13, 14])
        #expect(shown(.mine) == [10, 13, 14])
        #expect(shown(.system) == [11])
        #expect(shown(.otherUsers) == [12])
        #expect(shown(.apps) == [13])
        #expect(ViewFilter.mine.includesOtherUsers == false)
        #expect(ViewFilter.hierarchy.isTree)
        #expect(ViewFilter.system.isAboutOtherUsers)
    }

    @Test func activeMeansItDidSomethingLastInterval() {
        var busy = Fixtures.process(1, cpu: 0.4)
        let idle = Fixtures.process(2, cpu: 0.0)
        var writing = Fixtures.process(3, cpu: 0)
        writing.diskWrittenPerSecond = 4096
        var talking = Fixtures.process(4)
        talking.network = TrafficRate(received: 10, sent: 0)
        #expect(ViewFilter.active.includes(busy, myUID: Fixtures.me))
        #expect(!ViewFilter.active.includes(idle, myUID: Fixtures.me))
        #expect(ViewFilter.active.includes(writing, myUID: Fixtures.me))
        #expect(ViewFilter.active.includes(talking, myUID: Fixtures.me))
        busy.cpuPercent = nil
        busy.status = .running
        #expect(ViewFilter.active.includes(busy, myUID: Fixtures.me))
    }

    @Test func searchMatchesEveryWordAnywhereIgnoringCaseAndAccents() {
        var process = Fixtures.process(4242, name: "Café Helper", path: "/Applications/Café.app/Contents/MacOS/Café Helper")
        process.app = Fixtures.app("Café", bundle: "/Applications/Café.app")
        #expect(ProcessSearch.matches(process, terms: ProcessSearch.terms(in: "cafe HELPER")))
        #expect(ProcessSearch.matches(process, terms: ProcessSearch.terms(in: "com.example")))
        #expect(ProcessSearch.matches(process, terms: ProcessSearch.terms(in: "424")))
        #expect(ProcessSearch.matches(process, terms: ProcessSearch.terms(in: "me")))
        #expect(ProcessSearch.matches(process, terms: []))
        #expect(!ProcessSearch.matches(process, terms: ProcessSearch.terms(in: "cafe renderer")))
        #expect(!ProcessSearch.matches(process, terms: ProcessSearch.terms(in: "99")))
    }

    @Test func sortingPutsUnknownsLastEitherWayAndTiesInPIDOrder() {
        let processes = [
            Fixtures.process(5, cpu: 10),
            Fixtures.process(3, cpu: nil),
            Fixtures.process(4, cpu: 50),
            Fixtures.process(2, cpu: 10),
            Fixtures.process(1, cpu: nil),
        ]
        #expect(ProcessSort(column: .cpu, ascending: false).sorted(processes).map(\.pid) == [4, 2, 5, 1, 3])
        #expect(ProcessSort(column: .cpu, ascending: true).sorted(processes).map(\.pid) == [2, 5, 4, 1, 3])
        #expect(ProcessSort(column: .pid, ascending: true).sorted(processes).map(\.pid) == [1, 2, 3, 4, 5])
    }

    @Test func tiesFallToTheCompanionMeasure() {
        var reader = Fixtures.process(9)
        reader.diskWrittenPerSecond = 0
        reader.diskReadPerSecond = 8_000_000
        var writer = Fixtures.process(8)
        writer.diskWrittenPerSecond = 100
        var idle = Fixtures.process(1)
        idle.diskWrittenPerSecond = 0
        idle.diskReadPerSecond = 0
        // Written/s ties at zero for the reader and the idle one; the reader's reads put it first.
        #expect(ProcessSort(column: .diskWrittenRate, ascending: false).sorted([idle, reader, writer]).map(\.pid) == [8, 9, 1])
        var old = Fixtures.process(3, cpu: 0)
        old.cpuTime = 9_000_000_000
        let young = Fixtures.process(2, cpu: 0)
        #expect(ProcessSort(column: .cpu, ascending: false).sorted([young, old]).map(\.pid) == [3, 2])
        #expect(ProcessSort.companion(of: .name) == nil)
    }

    @Test func namesSortAsFinderDoes() {
        let processes = [
            Fixtures.process(1, name: "helper 10"),
            Fixtures.process(2, name: "Helper 9"),
            Fixtures.process(3, name: "alpha"),
        ]
        #expect(ProcessSort(column: .name, ascending: true).sorted(processes).map(\.pid) == [3, 2, 1])
        #expect(ProcessSort(column: .name, ascending: false).sorted(processes).map(\.pid) == [1, 2, 3])
    }

    @Test func memorySortsByFootprintElseRealMemory() {
        let processes = [
            Fixtures.process(1, memory: 100),
            Fixtures.process(2, uid: 0, realMemory: 300),
            Fixtures.process(3, memory: 200, realMemory: 900),
        ]
        #expect(ProcessSort(column: .memory, ascending: false).sorted(processes).map(\.pid) == [2, 3, 1])
        #expect(ProcessSort(column: .realMemory, ascending: false).sorted(processes).map(\.pid) == [3, 2, 1])
    }

    @Test func everyColumnSorts() {
        let processes = (1 ... 4).map { Fixtures.process(Int32($0), cpu: Double($0)) }
        for column in ActivityColumn.allCases {
            let sorted = ProcessSort(column: column, ascending: column.sortsAscendingFirst).sorted(processes)
            #expect(Set(sorted.map(\.pid)) == [1, 2, 3, 4])
        }
        for tab in ActivityTab.allCases {
            #expect(tab.columns.first == .name)
            #expect(tab.columns.contains(tab.defaultSort.column))
        }
    }
}
