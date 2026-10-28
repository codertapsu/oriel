import AppKit
import ApplicationServices

// focused-window: prints the frontmost app's pid and the title of its focused window, read through
// Accessibility, separated by a tab (scripts/verify-windows.sh). Exits 3 when this process is not trusted.

guard AXIsProcessTrusted() else { exit(3) }
guard let app = NSWorkspace.shared.frontmostApplication else { exit(1) }
let element = AXUIElementCreateApplication(app.processIdentifier)
var focused: CFTypeRef?
guard AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &focused) == .success,
      let focused, CFGetTypeID(focused) == AXUIElementGetTypeID()
else {
    print("\(app.processIdentifier)\t")
    exit(0)
}

var title: CFTypeRef?
_ = AXUIElementCopyAttributeValue(unsafeDowncast(focused, to: AXUIElement.self), kAXTitleAttribute as CFString, &title)
print("\(app.processIdentifier)\t\(title as? String ?? "")")
