import AppKit
import SwiftUI

/// The application exceptions (PLAN §1.2): bundle IDs (a trailing `*` matches a prefix) whose windows are
/// hidden, or whose own shortcuts win while they are frontmost.
struct ExceptionListEditor: View {
    @Binding var exceptions: [AppException]
    @State private var newBundleID = ""

    var body: some View {
        ForEach(exceptions) { rule in
            HStack {
                Text(rule.bundleID)
                    .font(.body.monospaced())
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Toggle("Hide windows", isOn: flag(\.hidesWindows, of: rule))
                    .toggleStyle(.checkbox)
                Toggle("Pass shortcuts through", isOn: flag(\.ignoresShortcuts, of: rule))
                    .toggleStyle(.checkbox)
                    .help("While this app is frontmost, the switcher's shortcuts reach the app (virtual machines, remote desktops).")
                Button {
                    exceptions.removeAll { $0.bundleID == rule.bundleID }
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove \(rule.bundleID)")
            }
        }
        HStack {
            TextField("Bundle ID", text: $newBundleID, prompt: Text("com.example.App or com.example.*"))
                .onSubmit { add(newBundleID) }
            Button("Add") { add(newBundleID) }
                .disabled(newBundleID.trimmingCharacters(in: .whitespaces).isEmpty)
            Menu("Running App") {
                ForEach(runningApps, id: \.self) { bundleID in
                    Button(bundleID) { add(bundleID) }
                }
            }
            .fixedSize()
        }
        Button("Restore Defaults") {
            exceptions = AppException.defaults
        }
    }

    private var runningApps: [String] {
        let known = Set(exceptions.map { $0.bundleID.lowercased() })
        return NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap(\.bundleIdentifier)
            .filter { !known.contains($0.lowercased()) }
            .sorted()
    }

    private func add(_ bundleID: String) {
        let trimmed = bundleID.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !exceptions.contains(where: { $0.bundleID.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        exceptions.append(AppException(bundleID: trimmed, hidesWindows: true, ignoresShortcuts: false))
        newBundleID = ""
    }

    private func flag(_ keyPath: WritableKeyPath<AppException, Bool>, of rule: AppException) -> Binding<Bool> {
        Binding(
            get: { exceptions.first { $0.bundleID == rule.bundleID }?[keyPath: keyPath] ?? false },
            set: { newValue in
                guard let index = exceptions.firstIndex(where: { $0.bundleID == rule.bundleID }) else { return }
                exceptions[index][keyPath: keyPath] = newValue
            }
        )
    }
}
