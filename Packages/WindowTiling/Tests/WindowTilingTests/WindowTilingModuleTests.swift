import AppKit
import Foundation
import OrielCore
import Testing
@testable import WindowTiling

/// The module against stand-ins for the AX actor, the trust check, the app in front and the feedback: it never
/// touches a real window, prompts or shows anything.
@MainActor
struct WindowTilingModuleTests {
    /// One request to the stand-in AX actor.
    private struct Call: Equatable {
        let action: TilingAction
        let pid: Int32
        let displays: [DisplayGeometry]
        let options: TilingOptions
    }

    /// What the stand-in AX actor was asked to do, and what it answers. It is called off the main actor.
    private final class Calls: @unchecked Sendable {
        private let lock = NSLock()
        private var entries: [Call] = []
        private var answer: TilingOutcome = .moved

        var outcome: TilingOutcome {
            get { lock.withLock { answer } }
            set { lock.withLock { answer = newValue } }
        }

        func record(_ call: Call) -> TilingOutcome {
            lock.withLock {
                entries.append(call)
                return answer
            }
        }

        var all: [Call] {
            lock.withLock { entries }
        }
    }

    private struct Harness {
        let module: WindowTilingModule
        let calls: Calls
        let feedback: RecordingFeedback
        let settings: SettingsStore
        let permissions: FakePermissions
        let defaults: UserDefaults
        let suite: String
    }

    private func harness(
        trusted: Bool = true,
        frontmost: (pid: Int32, name: String?)? = (pid: 321, name: "Notes"),
        displays: [DisplayGeometry] = Displays.row
    ) -> Harness {
        let suite = "WindowTilingTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        let settings = SettingsStore(defaults: defaults)
        let calls = Calls()
        let feedback = RecordingFeedback()
        let module = WindowTilingModule(
            arrange: { action, pid, displays, options in
                calls.record(Call(action: action, pid: pid, displays: displays, options: options))
            },
            isTrusted: { trusted },
            frontmostApp: { frontmost },
            displays: { displays },
            feedback: feedback,
            settings: settings
        )
        return Harness(
            module: module, calls: calls, feedback: feedback, settings: settings, permissions: FakePermissions(), defaults: defaults,
            suite: suite
        )
    }

    private func activate(_ harness: Harness) async {
        let services = ServiceContainer(keychain: KeychainStore(prefix: "com.codertapsu.oriel.tests"), permissions: harness.permissions)
        await harness.module.activate(context: ModuleContext(services: services, settings: harness.settings, log: Log.logger("tests")))
    }

    private func clean(_ harness: Harness) {
        harness.defaults.removePersistentDomain(forName: harness.suite)
    }

    /// Waits for the action's task to reach the stand-in AX actor and bring the outcome back, for at most a second.
    private func waitForResponses(_ count: Int, in harness: Harness) async {
        for _ in 0 ..< 100 where harness.feedback.responses.count < count {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test func theModuleDescribesItself() {
        let harness = harness()
        defer { clean(harness) }
        #expect(WindowTilingModule.id == .windowTiling)
        #expect(harness.module.displayName == "Window Tiling")
        #expect(harness.module.requiredPermissions == [.accessibility])
        #expect(harness.module.settingsSymbol == "rectangle.split.2x1")
        #expect(harness.module.settingsPane != nil)
        #expect(harness.module.ipcCommands.isEmpty)
        #expect(harness.module.commands.map(\.id) == TilingAction.allCases.map(\.commandID))
    }

    @Test func aShortcutArrangesTheFrontAppsWindowWithTheSettings() async {
        let harness = harness()
        defer { clean(harness) }
        await activate(harness)
        harness.settings[TilingSettings.gap] = 12
        harness.settings[TilingSettings.cyclesSizes] = false
        harness.module.commands.first { $0.id == "tileLeftHalf" }?.perform()
        await waitForResponses(1, in: harness)
        let expected = Call(action: .leftHalf, pid: 321, displays: Displays.row, options: TilingOptions(gap: 12, cyclesSizes: false))
        #expect(harness.calls.all == [expected])
        #expect(harness.feedback.responses == [.announcement("Left Half")])
    }

    @Test func outcomesComeBackAsFeedback() async {
        let harness = harness()
        defer { clean(harness) }
        await activate(harness)
        harness.calls.outcome = .appDidNotRespond
        harness.module.perform(.center)
        await waitForResponses(1, in: harness)
        harness.calls.outcome = .unchanged
        harness.module.perform(.restore)
        await waitForResponses(2, in: harness)
        #expect(harness.feedback.responses == [.toast("Notes didn't respond", symbol: "hourglass"), .beep])
    }

    @Test func withoutAccessibilityItOffersThePaneAndMovesNothing() async {
        let harness = harness(trusted: false)
        defer { clean(harness) }
        await activate(harness)
        // Decided on the main actor, before anything is sent to the AX actor.
        harness.module.perform(.maximize)
        #expect(harness.calls.all.isEmpty)
        #expect(harness.feedback.accessibilityRequests == [PermissionKind.accessibility.settingsPaneName()])
        harness.feedback.pressOpenSettings()
        #expect(harness.permissions.openedPanes == [.accessibility])
    }

    @Test func losingAccessibilityMidwayShowsTheNoticeRatherThanATimeout() async {
        // Accessibility as macOS reports it; revoked while the action is on the AX actor.
        final class Trust: @unchecked Sendable {
            private let lock = NSLock()
            private var granted = true
            var isGranted: Bool {
                get { lock.withLock { granted } }
                set { lock.withLock { granted = newValue } }
            }
        }
        let trust = Trust()
        let feedback = RecordingFeedback()
        let suite = "WindowTilingTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defer { defaults.removePersistentDomain(forName: suite) }
        let module = WindowTilingModule(
            arrange: { _, _, _, _ in
                trust.isGranted = false
                return .appDidNotRespond
            },
            isTrusted: { trust.isGranted },
            frontmostApp: { (pid: 7, name: "Xcode") },
            displays: { [Displays.laptop] },
            feedback: feedback,
            settings: SettingsStore(defaults: defaults)
        )
        let services = ServiceContainer(keychain: KeychainStore(prefix: "com.codertapsu.oriel.tests"), permissions: FakePermissions())
        await module.activate(context: ModuleContext(
            services: services,
            settings: SettingsStore(defaults: defaults),
            log: Log.logger("tests")
        ))
        module.perform(.leftHalf)
        for _ in 0 ..< 100 where feedback.accessibilityRequests.isEmpty {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(feedback.accessibilityRequests.count == 1)
        #expect(feedback.responses.isEmpty)
    }

    @Test func withNoAppInFrontItBeeps() async {
        let harness = harness(frontmost: nil)
        defer { clean(harness) }
        await activate(harness)
        harness.module.perform(.leftHalf)
        #expect(harness.calls.all.isEmpty)
        #expect(harness.feedback.responses == [.beep])
    }

    @Test func whileOffShortcutsDoNothingAndTheMenuIsEmpty() async {
        let harness = harness()
        defer { clean(harness) }
        #expect(harness.module.menuItems.isEmpty)
        harness.module.perform(.leftHalf)
        #expect(harness.calls.all.isEmpty && harness.feedback.responses.isEmpty)
        await activate(harness)
        await harness.module.deactivate()
        #expect(harness.feedback.dismissals == 1)
        #expect(!harness.module.isActive && harness.module.menuItems.isEmpty)
    }

    @Test func theMenuListsEveryLayoutWithItsShortcut() async throws {
        let harness = harness()
        defer { clean(harness) }
        await activate(harness)
        harness.settings[TilingAction.center.shortcutKey] = KeyCombo(keyCode: KeyCode.ansiC, modifiers: [.control, .command])
        let root = try #require(harness.module.menuItems.first)
        #expect(root.title == "Window Tiling")
        let items = try #require(root.submenu?.items)
        let actions = items.filter { !$0.isSeparatorItem }
        #expect(actions.map(\.title) == TilingAction.menuSections.flatMap(\.self).map(\.title))
        #expect(items.count(where: \.isSeparatorItem) == TilingAction.menuSections.count - 1)
        let left = try #require(actions.first { $0.title == "Left Half" })
        #expect(left.keyEquivalent == String(utf16CodeUnits: [unichar(NSLeftArrowFunctionKey)], count: 1))
        #expect(left.keyEquivalentModifierMask == [.control, .option])
        #expect(left.image != nil)
        // The user's own shortcut, and none for Almost Maximize.
        #expect(actions.first { $0.title == "Center" }?.keyEquivalentModifierMask == [.control, .command])
        #expect(actions.first { $0.title == "Almost Maximize" }?.keyEquivalent == "")
        // Three displays: the display moves are on.
        #expect(actions.filter(\.isEnabled).count == actions.count)
    }

    @Test func withOneDisplayTheDisplayMovesAreDimmed() async throws {
        let harness = harness(displays: [Displays.laptop])
        defer { clean(harness) }
        await activate(harness)
        let items = try #require(harness.module.menuItems.first?.submenu?.items)
        let dimmed = items.filter { !$0.isSeparatorItem && !$0.isEnabled }.map(\.title)
        #expect(dimmed == ["Next Display", "Previous Display"])
    }

    @Test func theSettingsTextsSayWhatTheValuesAre() {
        #expect(TilingSettingsView.gapText(0) == "None")
        #expect(TilingSettingsView.gapText(12) == "12 pt")
        #expect(TilingSettingsView.percentText(0.9) == "90 %")
    }
}
