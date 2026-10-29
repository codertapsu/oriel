import AppKit
import SharedUI
import SwiftUI

struct AboutPane: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("Oriel").font(.largeTitle.bold())
            Text(version).foregroundStyle(.secondary)
            Text("Window switcher, screenshots and recording, and screenshot translation.")
            GroupBox("System requirements") {
                Text(Self.requirements)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            Button("Copy update command") {
                Pasteboard.copy("brew upgrade --cask oriel")
            }
        }
        .padding(24)
    }

    /// PLAN §3.1, shown to users verbatim.
    static let requirements = """
    macOS:         macOS 26 Tahoe or later. Developed and tested on macOS 27.
    Apple silicon: M1 or later — all features.
    Intel:         Supported on the Intel Macs that run macOS 26. Best-effort:
                   no on-device AI features; slower OCR and video encoding.
    On-device AI:  Foundation Models and Apple Translation's high-fidelity strategy
                   need Apple silicon with Apple Intelligence turned on.
    Offline use:   Apple Translation language packs or a local LLM. OCR is on-device.
    Permissions:   Accessibility (required). Screen & System Audio Recording.
                   Microphone and Camera (optional, recording only).
    Memory:        8 GB minimum. 16 GB recommended with a local LLM.
    """
}
