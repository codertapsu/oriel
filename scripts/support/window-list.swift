import Foundation

// window-list <pid>: reads `oriel windows list --json` on stdin and prints the windows of one process, one per
// line: id, minimized|visible, this-space|other-space and the title, separated by tabs (scripts/verify-windows.sh).

struct Window: Decodable {
    let id: UInt32
    let pid: Int32
    let title: String
    let isMinimized: Bool
    let isOnCurrentSpace: Bool
}

guard CommandLine.arguments.count == 2, let pid = Int32(CommandLine.arguments[1]) else {
    FileHandle.standardError.write(Data("usage: window-list <pid> < windows.json\n".utf8))
    exit(64)
}

let windows = try JSONDecoder().decode([Window].self, from: FileHandle.standardInput.readDataToEndOfFile())
for window in windows where window.pid == pid {
    let state = window.isMinimized ? "minimized" : "visible"
    let space = window.isOnCurrentSpace ? "this-space" : "other-space"
    print("\(window.id)\t\(state)\t\(space)\t\(window.title)")
}
