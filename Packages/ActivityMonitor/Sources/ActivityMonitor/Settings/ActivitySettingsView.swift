import OrielCore
import SwiftUI

/// Settings → Activity Monitor: how often it measures, the tab it opens on, whether it lists other users' processes,
/// how long the graphs reach back, and the limits that mark heavy use.
struct ActivitySettingsView: View {
    let model: ActivitySettingsModel

    var body: some View {
        if let settings = model.settings {
            form(settings)
        }
    }

    private func form(_ settings: SettingsStore) -> some View {
        Form {
            Section("Activity Monitor") {
                if !model.isActive {
                    Text("Activity Monitor is off. Turn it on in General → Tools.").font(.caption).foregroundStyle(.secondary)
                }
                LabeledContent("Window") {
                    Button(model.isWindowOpen ? "Show Activity Monitor" : "Open Activity Monitor") { model.openWindow() }
                        .disabled(!model.isActive)
                }
                Text("Also in the menu bar, and at oriel://activity. Give it a shortcut in Settings → Shortcuts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker("Update every", selection: settings.binding(ActivitySettings.interval)) {
                    ForEach(ActivitySettings.intervalChoices, id: \.self) { Text($0 == 1 ? "1 second" : "\($0) seconds").tag($0) }
                }
                Text(Self.samplingNote).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Picker("Open on", selection: settings.binding(ActivitySettings.defaultTab)) {
                    ForEach(ActivityTab.allCases, id: \.self) { Text($0.title).tag($0.rawValue) }
                }
                Picker("Keep history for", selection: settings.binding(ActivitySettings.historyMinutes)) {
                    ForEach(ActivitySettings.historyChoices, id: \.self) { Text($0 == 1 ? "1 minute" : "\($0) minutes").tag($0) }
                }
                Toggle("Show only my processes", isOn: settings.binding(ActivitySettings.onlyMyProcesses))
                Text(Self.onlyMineNote).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            thresholds(settings)
        }
        .formStyle(.grouped)
        .onAppear { model.refresh() }
    }

    private func thresholds(_ settings: SettingsStore) -> some View {
        Section("Heavy Use") {
            Picker("CPU above", selection: settings.binding(ActivitySettings.cpuThreshold)) {
                ForEach(ActivitySettings.cpuThresholdChoices, id: \.self) { Text("\($0) %").tag($0) }
            }
            Picker("Sustained for", selection: settings.binding(ActivitySettings.thresholdSeconds)) {
                ForEach(ActivitySettings.thresholdSecondsChoices, id: \.self) { Text("\($0) seconds").tag($0) }
            }
            Picker("Memory above", selection: settings.binding(ActivitySettings.memoryThresholdTenths)) {
                ForEach(ActivitySettings.memoryThresholdChoices, id: \.self) { tenths in
                    Text(ActivityFormat.bytes(UInt64(tenths) * 100_000_000)).tag(tenths)
                }
            }
            Picker("Disk above", selection: settings.binding(ActivitySettings.diskThresholdMB)) {
                ForEach(ActivitySettings.diskThresholdChoices, id: \.self) { Text("\($0) MB/s").tag($0) }
            }
            Picker("Network above", selection: settings.binding(ActivitySettings.networkThresholdMB)) {
                ForEach(ActivitySettings.networkThresholdChoices, id: \.self) { Text("\($0) MB/s").tag($0) }
            }
            Text(Self.heavyNote).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private static let samplingNote = """
    Activity Monitor measures only while its window is open, and stops when you close it.
    """

    private static let onlyMineNote = """
    Hides system processes and other users' processes. Measuring them takes /bin/ps, which then never runs.
    """

    private static let heavyNote = """
    A process over a limit gets a flame in the list and in the strip above it. CPU, disk and network must stay above \
    their limits for the chosen time; memory counts at once. macOS shares disk use only for your own processes, and \
    network use is measured on the Network tab.
    """
}
