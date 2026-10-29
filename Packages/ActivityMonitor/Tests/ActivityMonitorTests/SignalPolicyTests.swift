@testable import ActivityMonitor
import Darwin
import Testing

struct SignalPolicyTests {
    let policy = SignalPolicy(ownPID: 4000, myUID: Fixtures.me)

    private func target(
        _ pid: Int32,
        command: String = "worker",
        uid: UInt32 = Fixtures.me,
        isApp: Bool = false,
        isZombie: Bool = false
    ) -> SignalTarget {
        SignalTarget(
            identity: ProcessIdentity(pid: pid, startTime: 1),
            name: command,
            command: command,
            uid: uid,
            user: uid == 0 ? "root" : "me",
            isApp: isApp,
            isZombie: isZombie
        )
    }

    @Test(arguments: [
        (Int32(0), "kernel_task", UInt32(0)),
        (1, "launchd", 0),
        (180, "WindowServer", 88),
        (390, "loginwindow", 501),
        (4000, "Oriel", 501),
        (-1, "everything", 501),
        (-4000, "group", 501),
    ])
    func protectedProcessesAreNeverSignalled(_ pid: Int32, _ command: String, _ uid: UInt32) {
        let process = target(pid, command: command, uid: uid)
        for action in [ProcessAction.quit, .forceQuit] + ProcessSignal.allCases.map(ProcessAction.signal) {
            guard case let .refuse(reason) = policy.decide(action, for: process) else {
                Issue.record("\(command) (\(pid)) was not refused \(action)")
                continue
            }
            #expect(!reason.isEmpty)
        }
    }

    @Test func refusalsSayWhy() {
        #expect(policy.refusal(for: target(390, command: "loginwindow"))?.contains("log you out") == true)
        #expect(policy.refusal(for: target(180, command: "WindowServer", uid: 88))?.contains("log you out") == true)
        #expect(policy.refusal(for: target(4000))?.contains("Oriel") == true)
        #expect(policy.refusal(for: target(77, isZombie: true))?.contains("already ended") == true)
        #expect(policy.refusal(for: target(77)) == nil)
    }

    @Test func theUsersAppsQuitThroughAppKit() {
        let app = target(500, isApp: true)
        #expect(policy.decide(.quit, for: app) == .terminateApp(force: false))
        #expect(policy.decide(.forceQuit, for: app) == .terminateApp(force: true))
        #expect(policy.decide(.signal(.hangup), for: app) == .send(.hangup))
    }

    @Test func theUsersOtherProcessesGetSignals() {
        let worker = target(600)
        #expect(policy.decide(.quit, for: worker) == .send(.terminate))
        #expect(policy.decide(.forceQuit, for: worker) == .send(.kill))
        #expect(policy.decide(.signal(.stop), for: worker) == .send(.stop))
    }

    @Test func otherUsersProcessesNeedAnAdministrator() {
        let daemon = target(700, command: "mds_stores", uid: 0)
        #expect(policy.decide(.quit, for: daemon) == .needsAdministrator(.terminate))
        #expect(policy.decide(.forceQuit, for: daemon) == .needsAdministrator(.kill))
        let otherApp = target(701, uid: 502, isApp: true)
        #expect(policy.decide(.quit, for: otherApp) == .needsAdministrator(.terminate))
    }

    @Test func signalsHaveTheirDarwinNumbers() {
        #expect(ProcessSignal.terminate.number == SIGTERM)
        #expect(ProcessSignal.kill.number == 9)
        #expect(ProcessSignal.stop.number == SIGSTOP)
        #expect(ProcessSignal.resume.number == SIGCONT)
        #expect(ProcessSignal.user2.number == SIGUSR2)
        #expect(Set(ProcessSignal.allCases.map(\.number)).count == ProcessSignal.allCases.count)
        #expect(ProcessSignal.allCases.allSatisfy { $0.title.contains($0.name) && !$0.effect.isEmpty })
    }

    @Test func theAdministratorScriptHoldsOnlyNumbers() throws {
        let script = try #require(AdministratorKill.script(signal: .terminate, pids: [1234]))
        #expect(script == "do shell script \"/bin/kill -15 1234\" with administrator privileges")
        #expect(
            AdministratorKill.arguments(signal: .kill, pids: [88, 412]) ==
                ["-e", "do shell script \"/bin/kill -9 88 412\" with administrator privileges"]
        )
        #expect(AdministratorKill.script(signal: .kill, pids: [1]) == nil)
        #expect(AdministratorKill.script(signal: .kill, pids: [0]) == nil)
        #expect(AdministratorKill.script(signal: .kill, pids: [500, -1]) == nil)
        #expect(AdministratorKill.script(signal: .kill, pids: []) == nil)
        for signal in ProcessSignal.allCases {
            let text = try #require(AdministratorKill.script(signal: signal, pids: [Int32.max, 2]))
            let command = text.replacingOccurrences(of: "do shell script \"/bin/kill -", with: "")
                .replacingOccurrences(of: "\" with administrator privileges", with: "")
            #expect(command.allSatisfy { $0.isNumber || $0 == " " })
        }
        #expect(AdministratorKill.isCancellation("execution error: User canceled. (-128)"))
        #expect(!AdministratorKill.isCancellation("Operation not permitted"))
    }
}
