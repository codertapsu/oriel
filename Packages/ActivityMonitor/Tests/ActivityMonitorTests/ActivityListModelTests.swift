@testable import ActivityMonitor
import Foundation
import Testing

@MainActor
struct ActivityListModelTests {
    private func snapshot(_ processes: [ProcessMetrics]) -> ActivitySnapshot {
        ActivitySnapshot(
            date: Date(),
            interval: 2,
            processes: processes,
            system: SystemMetrics(),
            history: .empty,
            selectedHistory: nil,
            sources: []
        )
    }

    private var processes: [ProcessMetrics] {
        var chrome = Fixtures.process(
            300,
            name: "Google Chrome",
            path: "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
            app: Fixtures.app("Google Chrome", bundle: "/Applications/Google Chrome.app"),
            cpu: 12,
            memory: 900_000_000
        )
        chrome.heavy = .memory
        return [
            Fixtures.process(1, name: "launchd", parent: 0, uid: 0, cpu: 0.2, realMemory: 20_000_000),
            Fixtures.process(88, name: "WindowServer", uid: 88, cpu: 30, realMemory: 400_000_000),
            chrome,
            Fixtures.process(
                301,
                name: "Google Chrome Helper",
                path: "/Applications/Google Chrome.app/Contents/Helper",
                cpu: 45,
                memory: 300
            ),
            Fixtures.process(400, name: "zsh", cpu: 0, memory: 2_000_000),
        ]
    }

    @Test func theListFollowsTheViewTheSearchAndTheOrder() {
        let model = ActivityListModel(myUID: Fixtures.me)
        model.update(snapshot(processes))
        #expect(model.roots.map(\.metrics.pid) == [301, 88, 300, 1, 400])
        model.filter = .mine
        #expect(model.roots.map(\.metrics.pid) == [301, 300, 400])
        model.query = "chrome"
        #expect(model.roots.map(\.metrics.pid) == [301, 300])
        model.sorts[.cpu] = ProcessSort(column: .name, ascending: true)
        #expect(model.roots.map(\.metrics.pid) == [300, 301])
        model.query = "nothing like this"
        #expect(model.roots.isEmpty)
        #expect(model.isSearching)
        model.query = ""
        model.filter = .appsWithHelpers
        #expect(model.roots.count == 1)
        #expect(model.roots.first?.isGroup == true)
        #expect(model.shownCount == 2)
    }

    @Test func onlyMyProcessesHidesTheRestAndTheViewsAboutThem() {
        let model = ActivityListModel(myUID: Fixtures.me)
        model.update(snapshot(processes))
        model.filter = .system
        #expect(model.roots.map(\.metrics.pid) == [1])
        model.onlyMine = true
        #expect(model.effectiveFilter == .all)
        #expect(model.roots.map(\.metrics.pid) == [301, 300, 400])
        #expect(!model.sources.contains(.otherUsers))
    }

    @Test func theSampleReadsOnlyWhatTheTabAndViewShow() {
        let model = ActivityListModel(myUID: Fixtures.me)
        #expect(model.sources == [.devices, .otherUsers])
        model.tab = .network
        #expect(model.sources == [.devices, .network])
        model.tab = .energy
        #expect(model.sources == [.devices, .otherUsers, .sleepAssertions])
        model.tab = .disk
        #expect(model.sources == [.devices])
        model.tab = .memory
        model.filter = .mine
        #expect(model.sources == [.devices])
        model.filter = .appsWithHelpers
        #expect(model.sources.contains(.otherUsers))
    }

    @Test func topConsumersRankTheTabsMeasureWhateverTheView() {
        let model = ActivityListModel(myUID: Fixtures.me)
        model.update(snapshot(processes))
        model.filter = .apps
        #expect(model.topConsumers().map(\.pid) == [301, 88, 300])
        model.tab = .memory
        #expect(model.topConsumers(limit: 2).map(\.pid) == [300, 88])
        model.tab = .disk
        #expect(model.topConsumers().isEmpty)
    }

    @Test func columnsShowTheirValues() {
        var process = Fixtures.process(42, name: "node", uid: 0, cpu: 12.34, realMemory: 1_073_741_824)
        process.cpuTime = 723_270_000_000
        process.network = TrafficRate(received: 2_000_000, sent: 0)
        process.sleepAssertions = ["PreventUserIdleSystemSleep"]
        process.heavy = [.cpu]
        #expect(ActivityColumn.cpu.text(for: process) == ActivityFormat.percent(12.34))
        #expect(ActivityColumn.cpuTime.text(for: process) == ActivityFormat.cpuTime(723_270_000_000))
        #expect(ActivityColumn.pid.text(for: process) == "42")
        #expect(ActivityColumn.user.text(for: process) == "root")
        #expect(ActivityColumn.threads.text(for: process) == ActivityFormat.dash)
        #expect(ActivityColumn.preventingSleep.text(for: process) == "Yes")
        #expect(ActivityColumn.sentRate.text(for: process) == "0")
        #expect(ActivityColumn.receivedRate.text(for: process).hasSuffix("/s"))
        #expect(ActivityColumn.memory.isStandIn(for: process))
        #expect(!ActivityColumn.realMemory.isStandIn(for: process))
        #expect(ActivityColumn.memory.text(for: process) == ActivityColumn.realMemory.text(for: process))
        #expect(ActivityColumn.cpu.heavyFlag == .cpu)
        #expect(ActivityColumn.realMemory.heavyFlag == nil)
        #expect(ActivityColumn.name.heavyFlag == nil)
        #expect(ActivityColumn.sentRate.isQuiet(for: process))
        #expect(!ActivityColumn.receivedRate.isQuiet(for: process))
        #expect(!ActivityColumn.cpu.isQuiet(for: process))
        #expect(!ActivityColumn.preventingSleep.isQuiet(for: process))
        for column in ActivityColumn.allCases {
            #expect(!column.text(for: process).isEmpty)
            #expect(!column.title.isEmpty)
        }
    }

    @Test func iconsComeFromTheInnermostBundle() {
        let helper = "/Applications/Google Chrome.app/Contents/Frameworks/Helpers/Google Chrome Helper (Renderer).app/Contents/MacOS/Helper"
        #expect(
            ProcessIconCache.bundlePath(containing: helper) ==
                "/Applications/Google Chrome.app/Contents/Frameworks/Helpers/Google Chrome Helper (Renderer).app"
        )
        #expect(ProcessIconCache.bundlePath(containing: "/System/Library/Frameworks/X.framework/XPCServices/S.xpc/Contents/MacOS/S")?
            .hasSuffix(".xpc") == true)
        #expect(ProcessIconCache.bundlePath(containing: "/usr/libexec/logd") == nil)
    }
}
