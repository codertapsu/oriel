import OrielCore
import Permissions
import SwiftUI

/// Each permission with what it is for and its live state (PLAN §8.2). Used by the welcome window, Settings →
/// Permissions and, for the permissions a feature uses, the feature tour. Nothing here pushes the user to allow
/// anything (App Review Guidelines 5.1.1(iv)): the button that leads to macOS's request says Continue, no permission
/// is marked as required, and where it can be changed is said only in Settings.
struct PermissionList: View {
    /// The welcome window comes before any request, so it describes and asks only on Continue; Settings also says
    /// where a permission that is off can be changed.
    enum Context {
        case welcome, settings
    }

    let permissions: PermissionCenter
    var kinds = PermissionKind.available
    var context = Context.settings

    var body: some View {
        ForEach(kinds) { kind in
            let status = permissions.status(of: kind)
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: status == .granted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(status == .granted ? Color.green : Color.secondary)
                    .font(.title2)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(kind.displayName).font(.headline)
                    Text(kind.purpose).font(.callout).foregroundStyle(.secondary)
                    if context == .settings, status != .granted {
                        Text(kind.settingsHint())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                if status == .granted {
                    Text("Allowed").foregroundStyle(.secondary)
                } else {
                    Button(Self.buttonTitle(for: status)) {
                        Task {
                            if await permissions.request(kind) != .granted {
                                permissions.openSystemSettings(for: kind)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
        }
    }

    /// Continue leads to macOS's own request; a permission the user has turned down can only change in System
    /// Settings, so its button says so.
    static func buttonTitle(for status: PermissionStatus) -> String {
        status == .denied ? "Open System Settings…" : "Continue"
    }
}
