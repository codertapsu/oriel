import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// The apps whose copies Clipboard History never keeps, by bundle ID, shown with their names and icons.
struct IgnoredAppsEditor: View {
    private struct RunningApp: Hashable {
        let bundleID: String
        let name: String
    }

    @Binding var bundleIDs: [String]

    var body: some View {
        LabeledContent("Never keep copies from") {
            EmptyView()
        }
        ForEach(bundleIDs, id: \.self) { bundleID in
            HStack {
                Image(nsImage: icon(bundleID))
                    .resizable()
                    .frame(width: 18, height: 18)
                Text(name(bundleID))
                    .lineLimit(1)
                if name(bundleID) != bundleID {
                    Text(bundleID)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Button {
                    bundleIDs.removeAll { $0 == bundleID }
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove \(name(bundleID))")
            }
        }
        HStack {
            Button("Add App…", action: chooseApp)
            Menu("Running App") {
                ForEach(runningApps, id: \.bundleID) { app in
                    Button(app.name) { add(app.bundleID) }
                }
            }
            .fixedSize()
            Spacer()
            Button("Restore Defaults") { bundleIDs = PrivacyFilter.defaultIgnoredApps }
                .disabled(bundleIDs == PrivacyFilter.defaultIgnoredApps)
        }
    }

    private var runningApps: [RunningApp] {
        NSWorkspace.shared.runningApplications
            // Oriel is in the Dock while Settings is open (PLAN §10.1), but is not one of the apps to pick.
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            .compactMap { app in app.bundleIdentifier.map { RunningApp(bundleID: $0, name: app.localizedName ?? $0) } }
            .filter { app in !bundleIDs.contains { $0.caseInsensitiveCompare(app.bundleID) == .orderedSame } }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// The app's name; a default app that is not installed has its known name, and any other its bundle ID.
    private func name(_ bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return PrivacyFilter.defaultAppNames[bundleID] ?? bundleID
        }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    private func icon(_ bundleID: String) -> NSImage {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage()
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    private func add(_ bundleID: String) {
        guard !bundleIDs.contains(where: { $0.caseInsensitiveCompare(bundleID) == .orderedSame }) else { return }
        bundleIDs.append(bundleID)
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(filePath: "/Applications", directoryHint: .isDirectory)
        panel.message = "Choose an app whose copies Clipboard History should never keep."
        panel.prompt = "Ignore"
        if panel.runModal() == .OK, let url = panel.url, let bundleID = Bundle(url: url)?.bundleIdentifier {
            add(bundleID)
        }
    }
}
