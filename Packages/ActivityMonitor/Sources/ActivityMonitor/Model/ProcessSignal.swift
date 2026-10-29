import Darwin

/// The signals Send Signal offers, with what each usually does.
nonisolated enum ProcessSignal: String, CaseIterable, Sendable, Codable {
    case terminate
    case interrupt
    case hangup
    case kill
    case stop
    case resume
    case user1
    case user2

    var number: Int32 {
        switch self {
        case .terminate: SIGTERM
        case .interrupt: SIGINT
        case .hangup: SIGHUP
        case .kill: SIGKILL
        case .stop: SIGSTOP
        case .resume: SIGCONT
        case .user1: SIGUSR1
        case .user2: SIGUSR2
        }
    }

    /// "SIGTERM".
    var name: String {
        switch self {
        case .terminate: "SIGTERM"
        case .interrupt: "SIGINT"
        case .hangup: "SIGHUP"
        case .kill: "SIGKILL"
        case .stop: "SIGSTOP"
        case .resume: "SIGCONT"
        case .user1: "SIGUSR1"
        case .user2: "SIGUSR2"
        }
    }

    /// The menu item.
    var title: String {
        switch self {
        case .terminate: "Terminate (SIGTERM)"
        case .interrupt: "Interrupt (SIGINT)"
        case .hangup: "Hang Up (SIGHUP)"
        case .kill: "Kill (SIGKILL)"
        case .stop: "Pause (SIGSTOP)"
        case .resume: "Continue (SIGCONT)"
        case .user1: "User 1 (SIGUSR1)"
        case .user2: "User 2 (SIGUSR2)"
        }
    }

    /// What the confirmation says will happen.
    var effect: String {
        switch self {
        case .terminate: "asks the process to quit; it can save its work first, or ignore the request."
        case .interrupt: "interrupts the process, as Control-C does in Terminal; most programs quit."
        case .hangup: "tells the process its terminal went away; many servers reload their settings, others quit."
        case .kill: "ends the process at once. It cannot save anything or refuse."
        case .stop: "pauses the process until it gets Continue. A paused app does not respond."
        case .resume: "lets a paused process run again."
        case .user1, .user2: "means whatever the program defines; a program that defines nothing quits."
        }
    }
}
