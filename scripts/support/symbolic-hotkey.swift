import CoreGraphics
import Darwin
import Foundation

// symbolic-hotkey <id> [on]: prints whether a system symbolic hot key is enabled (1 is ⌘⇥, 2 is ⌘⇧⇥), or turns
// it back on (scripts/verify-cmdtab-restore.sh). The functions are resolved with dlsym, as Packages/PrivateAPIs
// resolves them (docs/provenance.md); CoreGraphics brings in SkyLight, which exports them.

typealias IsEnabled = @convention(c) (Int32) -> Bool
typealias SetEnabled = @convention(c) (Int32, Bool) -> CGError

func resolve<T>(_ name: String, as _: T.Type) -> T? {
    guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) else { return nil } // RTLD_DEFAULT
    return unsafeBitCast(symbol, to: T.self)
}

let arguments = CommandLine.arguments
guard arguments.count >= 2, let id = Int32(arguments[1]) else {
    FileHandle.standardError.write(Data("usage: symbolic-hotkey <id> [on]\n".utf8))
    exit(64)
}

guard let isEnabled = resolve("CGSIsSymbolicHotKeyEnabled", as: IsEnabled.self),
      let setEnabled = resolve("CGSSetSymbolicHotKeyEnabled", as: SetEnabled.self)
else {
    FileHandle.standardError.write(Data("This macOS does not export the symbolic hot key functions.\n".utf8))
    exit(69)
}

if arguments.count == 3, arguments[2] == "on" {
    _ = setEnabled(id, true)
}

print(isEnabled(id) ? "enabled" : "disabled")
