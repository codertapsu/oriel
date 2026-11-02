import OrielCore
import SharedUI
import SwiftUI

/// One feature's page in the tour (PLAN §19): what it does, its shortcut and Try It, what Oriel Pro adds, and the
/// permissions it uses in this edition.
struct FeatureTourPage: View {
    let guide: FeatureGuide
    let controller: AppController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: guide.symbol)
                        .font(.system(size: 34))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 48)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(guide.title).font(.largeTitle.bold())
                        Text(guide.summary).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                }
                actions
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(guide.highlights) { highlight in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: highlight.proFeature == nil ? "checkmark.circle" : "star.circle")
                                .foregroundStyle(highlight.proFeature == nil ? Color.secondary : Color.accentColor)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(highlight.title).font(.headline)
                                    if let feature = highlight.proFeature {
                                        ProBadge(feature)
                                    }
                                }
                                Text(highlight.detail).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                if !permissions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Permissions").font(.title3.bold())
                        PermissionList(permissions: controller.permissions, kinds: permissions)
                    }
                }
            }
            .padding(28)
            .frame(maxWidth: 680, alignment: .leading)
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            if isTurnedOff {
                Text("\(guide.title) is turned off.").foregroundStyle(.secondary)
                Button("Turn On in Settings…") { controller.showSettings(tab: "general") }
            } else if let commandID = guide.commandID {
                Button("Try It") { _ = controller.run(commandID: commandID) }
                    .buttonStyle(.borderedProminent)
                if let shortcut = controller.shortcut(of: commandID) {
                    Text(shortcut.description)
                        .font(.body.monospaced())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 5).fill(.quaternary))
                        .accessibilityLabel("Shortcut \(shortcut.description)")
                }
            }
            Button("Settings…") { controller.showSettings(tab: guide.id) }
        }
    }

    /// The permissions the feature uses that this edition can ask for.
    private var permissions: [PermissionKind] {
        PermissionKind.available.filter(guide.permissions.contains)
    }

    /// Whether the tool behind the page is turned off in Settings → General; the features are always on.
    private var isTurnedOff: Bool {
        let id = ModuleID(rawValue: guide.id)
        return controller.hub.modules.contains { type(of: $0).id == id } && !controller.registry.isEnabled(id)
    }
}
