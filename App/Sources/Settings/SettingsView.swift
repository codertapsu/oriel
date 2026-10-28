import SwiftUI

/// Settings: the app's own panes plus one per feature (PLAN §10.1), in a sidebar like System Settings.
struct SettingsView: View {
    let controller: AppController
    @Bindable var navigation: SettingsNavigation

    private var panes: [SettingsPaneEntry] {
        [SettingsPaneEntry(id: "general", title: "General", symbol: "gearshape", view: AnyView(GeneralPane(controller: controller)))]
            + controller.hub.settingsPanes
            + [
                SettingsPaneEntry(
                    id: "shortcuts",
                    title: "Shortcuts",
                    symbol: "command",
                    view: AnyView(ShortcutsPane(controller: controller))
                ),
                SettingsPaneEntry(
                    id: "permissions",
                    title: "Permissions",
                    symbol: "lock.shield",
                    view: AnyView(PermissionsPane(permissions: controller.permissions))
                ),
                SettingsPaneEntry(
                    id: "advanced",
                    title: "Advanced",
                    symbol: "wrench.and.screwdriver",
                    view: AnyView(AdvancedPane(controller: controller))
                ),
                SettingsPaneEntry(id: "about", title: "About", symbol: "info.circle", view: AnyView(AboutPane())),
            ]
    }

    var body: some View {
        NavigationSplitView {
            List(panes, selection: Binding(get: { navigation.tab }, set: { navigation.tab = $0 ?? "general" })) { pane in
                Label(pane.title, systemImage: pane.symbol).tag(pane.id)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        } detail: {
            (panes.first { $0.id == navigation.tab } ?? panes[0]).view
                .navigationTitle(panes.first { $0.id == navigation.tab }?.title ?? "General")
        }
        .frame(minWidth: 820, minHeight: 540)
    }
}
