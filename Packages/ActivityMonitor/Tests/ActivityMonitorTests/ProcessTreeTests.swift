@testable import ActivityMonitor
import Testing

/// The hierarchy and the apps with their helpers.
struct ProcessTreeTests {
    let byCPU = ProcessSort(column: .cpu, ascending: false)

    /// kernel_task → launchd → { Terminal → zsh → node, mds, Chrome → helpers }.
    let processes: [ProcessMetrics] = [
        Fixtures.process(0, name: "kernel_task", parent: 0, uid: 0, start: 1),
        Fixtures.process(1, name: "launchd", parent: 0, uid: 0, start: 2),
        Fixtures.process(
            100,
            name: "Terminal",
            app: Fixtures.app("Terminal", bundle: "/System/Applications/Utilities/Terminal.app"),
            cpu: 1
        ),
        Fixtures.process(101, name: "zsh", parent: 100, path: "/bin/zsh", cpu: 0),
        Fixtures.process(102, name: "node", parent: 101, path: "/usr/local/bin/node", cpu: 50, memory: 300),
        Fixtures.process(200, name: "mds", uid: 0, path: "/System/Library/mds", cpu: 5),
        Fixtures.process(
            300,
            name: "Google Chrome",
            path: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
            app: Fixtures.app("Google Chrome", bundle: "/Applications/Google Chrome.app"),
            cpu: 2,
            memory: 1000
        ),
        Fixtures.process(
            301,
            name: "Google Chrome Helper (Renderer)",
            path: "/Applications/Google Chrome.app/Contents/Frameworks/Helpers/Google Chrome Helper (Renderer).app/Contents/MacOS/Helper",
            cpu: 30,
            memory: 400
        ),
        Fixtures.process(
            302,
            name: "chrome_crashpad_handler",
            path: "/Applications/Google Chrome.app/Contents/Frameworks/chrome_crashpad_handler",
            cpu: nil,
            memory: 10
        ),
    ]

    @Test func childrenGoUnderTheProcessThatStartedThem() throws {
        let roots = ProcessTree.hierarchy(processes, sort: byCPU) { _ in true }
        #expect(roots.map(\.metrics.pid) == [0])
        let launchd = try #require(roots.first?.children.first)
        #expect(launchd.metrics.pid == 1)
        // launchd's children by CPU, the unknown last.
        #expect(launchd.children.map(\.metrics.pid) == [301, 200, 300, 100, 302])
        let terminal = try #require(launchd.children.first { $0.metrics.pid == 100 })
        #expect(terminal.children.first?.children.first?.metrics.pid == 102)
    }

    @Test func aMatchKeepsItsAncestors() {
        let roots = ProcessTree.hierarchy(processes, sort: byCPU) { $0.name == "node" }
        #expect(roots.map(\.metrics.pid) == [0])
        #expect(roots.first?.children.map(\.metrics.pid) == [1])
        #expect(roots.first?.children.first?.children.map(\.metrics.pid) == [100])
        #expect(roots.first?.allProcesses.map(\.pid) == [0, 1, 100, 101, 102])
    }

    @Test func aParentYoungerThanItsChildIsAReusedPID() {
        let orphan = Fixtures.process(400, parent: 300, start: 1)
        let roots = ProcessTree.hierarchy(processes + [orphan], sort: byCPU) { $0.pid == 400 }
        #expect(roots.map(\.metrics.pid) == [400])
    }

    @Test func helpersAndDescendantsJoinTheirApps() {
        let owners = ProcessGrouping.owners(of: processes)
        #expect(owners[300] == 300)
        #expect(owners[301] == 300)
        #expect(owners[302] == 300)
        #expect(owners[101] == 100)
        #expect(owners[102] == 100)
        #expect(owners[200] == nil)
        #expect(owners[1] == nil)
    }

    @Test func theInnermostBundleWins() {
        let xcode = Fixtures.process(500, app: Fixtures.app("Xcode", bundle: "/Applications/Xcode.app"))
        let simulator = Fixtures.process(
            501,
            path: "/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app/Contents/MacOS/Simulator",
            app: Fixtures.app("Simulator", bundle: "/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app")
        )
        let helper = Fixtures.process(502, path: "/Applications/Xcode.app/Contents/Developer/Applications/Simulator.app/Contents/Helper")
        let owners = ProcessGrouping.owners(of: [xcode, simulator, helper])
        #expect(owners[502] == 501)
        #expect(owners[501] == 501)
    }

    @Test func appsCarryTheirGroupsTotals() throws {
        let groups = ProcessGrouping.groups(processes, sort: byCPU) { _ in true }
        // Chrome: 2 + 30 = 32 % (the unknown adds nothing); Terminal: 1 + 0 + 50 = 51 %.
        #expect(groups.map(\.metrics.pid) == [100, 300])
        let chrome = try #require(groups.last)
        #expect(chrome.isGroup)
        #expect(chrome.metrics.cpuPercent == 32)
        #expect(chrome.metrics.memory == 1410)
        #expect(chrome.metrics.name == "Google Chrome")
        #expect(chrome.children.map(\.metrics.pid) == [300, 301, 302])
        #expect(chrome.allProcesses.count == 3)
    }

    @Test func aSearchShowsTheMatchingHelpersUnderTheirApp() throws {
        let groups = ProcessGrouping.groups(processes, sort: byCPU) { $0.name.contains("Renderer") }
        #expect(groups.map(\.metrics.pid) == [300])
        #expect(try #require(groups.first).children.map(\.metrics.pid) == [300, 301])
        #expect(ProcessGrouping.groups(processes, sort: byCPU) { $0.name == "mds" }.isEmpty)
    }

    @Test func anAppWithoutHelpersIsAPlainRow() {
        let notes = Fixtures.process(700, app: Fixtures.app("Notes", bundle: "/System/Applications/Notes.app"))
        let groups = ProcessGrouping.groups([notes], sort: byCPU) { _ in true }
        #expect(groups.count == 1)
        #expect(groups.first?.isGroup == false)
        #expect(groups.first?.key == .process(notes.id))
    }
}
