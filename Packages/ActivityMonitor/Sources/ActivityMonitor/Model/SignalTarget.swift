/// The process an action is about, as the user confirmed it: kept with its identity, so that a pid the process gave up
/// while the dialog was open is never signalled.
nonisolated struct SignalTarget: Sendable, Equatable {
    let identity: ProcessIdentity
    /// What the dialog calls it.
    let name: String
    /// The kernel's short name, which the refusals check.
    let command: String
    let uid: UInt32
    let user: String
    /// A running app, which quits through `NSRunningApplication` so it can save its work.
    let isApp: Bool
    let isZombie: Bool

    var pid: Int32 {
        identity.pid
    }

    init(identity: ProcessIdentity, name: String, command: String, uid: UInt32, user: String, isApp: Bool, isZombie: Bool) {
        self.identity = identity
        self.name = name
        self.command = command
        self.uid = uid
        self.user = user
        self.isApp = isApp
        self.isZombie = isZombie
    }

    init(_ process: ProcessMetrics) {
        self.init(
            identity: process.id,
            name: process.name,
            command: process.command,
            uid: process.uid,
            user: process.user,
            isApp: process.app != nil,
            isZombie: process.status == .zombie
        )
    }
}
