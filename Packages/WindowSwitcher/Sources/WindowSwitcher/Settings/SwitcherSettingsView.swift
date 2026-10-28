import AppKit
import CoreGraphics
import Hotkeys
import OrielCore
import SwiftUI

/// Settings → Window Switcher (PLAN §10.1): enable, the shortcuts table, appearance, preview, gestures,
/// Cmd-Tab takeover, exceptions, and notes on Sticky Keys and Spaces.
struct SwitcherSettingsView: View {
    let settings: SettingsStore

    @State private var isStickyKeysOn = StickyKeys.isEnabled
    @State private var switchesSpaces = SystemPreferences.switchesToSpaceWithOpenWindows
    @State private var systemSwipeInUse = SystemPreferences.systemUsesThreeFingerHorizontalSwipe
    @State private var canCapture = CGPreflightScreenCaptureAccess()

    var body: some View {
        Form {
            Section {
                Toggle("Enable the window switcher", isOn: settings.binding(SwitcherSettingKeys.enabled))
            }
            Section {
                ShortcutListEditor(shortcuts: settings.binding(SwitcherSettingKeys.shortcuts))
            } header: {
                Text("Shortcuts")
            } footer: {
                Text(SwitcherSettingsText.shortcuts)
            }
            Section("Appearance") {
                Picker("Style", selection: settings.binding(SwitcherSettingKeys.style)) {
                    ForEach(DisplayStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                LabeledContent("Thumbnail size") {
                    Slider(value: settings.binding(SwitcherSettingKeys.thumbnailWidth), in: 120 ... 400, step: 20)
                        .frame(maxWidth: 240)
                }
                Toggle("Show a full-size preview of the selected window", isOn: settings.binding(SwitcherSettingKeys.showsPreview))
                Picker("Show on", selection: settings.binding(SwitcherSettingKeys.placement)) {
                    ForEach(PanelPlacement.allCases) { placement in
                        Text(placement.title).tag(placement)
                    }
                }
                if !canCapture {
                    note(SwitcherSettingsText.needsScreenRecording)
                }
            }
            Section("Trackpad") {
                Toggle("Switch windows with a three-finger swipe", isOn: settings.binding(SwitcherSettingKeys.gesturesEnabled))
                if systemSwipeInUse {
                    note(SwitcherSettingsText.systemSwipe)
                    Button("Open Trackpad Settings…") { open(SwitcherSettingsText.trackpadSettings) }
                }
            }
            Section("Command-Tab") {
                Toggle("Take over ⌘⇥ when a shortcut uses it", isOn: settings.binding(SwitcherSettingKeys.takesOverCommandTab))
                note(SwitcherSettingsText.commandTab)
            }
            Section {
                ExceptionListEditor(exceptions: settings.binding(SwitcherSettingKeys.exceptions))
            } header: {
                Text("Exceptions")
            } footer: {
                Text(SwitcherSettingsText.exceptions)
            }
            Section("Notes") {
                note(isStickyKeysOn ? SwitcherSettingsText.stickyKeysOn : SwitcherSettingsText.stickyKeysOff)
                note(switchesSpaces ? SwitcherSettingsText.spacesOn : SwitcherSettingsText.spacesOff)
                if !switchesSpaces {
                    Button("Open Desktop & Dock Settings…") { open(SwitcherSettingsText.desktopSettings) }
                }
            }
        }
        .formStyle(.grouped)
        .task {
            refresh()
            // Coming back from System Settings: show what changed there.
            let activations = NotificationCenter.default.notifications(named: NSApplication.didBecomeActiveNotification).map { _ in () }
            for await _ in activations {
                refresh()
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func refresh() {
        isStickyKeysOn = StickyKeys.isEnabled
        switchesSpaces = SystemPreferences.switchesToSpaceWithOpenWindows
        systemSwipeInUse = SystemPreferences.systemUsesThreeFingerHorizontalSwipe
        canCapture = CGPreflightScreenCaptureAccess()
    }

    private func open(_ address: String) {
        if let url = URL(string: address) {
            NSWorkspace.shared.open(url)
        }
    }
}
