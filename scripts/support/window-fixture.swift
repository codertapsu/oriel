import AppKit

// window-fixture: a regular app with three titled windows for scripts/verify-windows.sh. "Oriel fixture 1" and
// "Oriel fixture 2" stay open, "Oriel fixture 3" is minimized. Prints "ready <pid>" once they are on screen and
// "focused <title>" whenever one becomes key; runs until it is killed.

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    var windows: [NSWindow] = []
    for index in 1 ... 3 {
        let window = NSWindow(
            contentRect: NSRect(x: 160 + index * 60, y: 200 + index * 40, width: 420, height: 260),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Oriel fixture \(index)"
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        windows.append(window)
    }
    windows[2].miniaturize(nil)
    NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { note in
        MainActor.assumeIsolated {
            guard let window = note.object as? NSWindow else { return }
            print("focused \(window.title)")
            fflush(stdout)
        }
    }
    app.activate()
    print("ready \(ProcessInfo.processInfo.processIdentifier)")
    fflush(stdout)
    app.run()
}
