import OrielCore
import Permissions
import SwiftUI

/// Each permission with what it unlocks, its live state and the way to grant it (PLAN §8.2). Used by the
/// onboarding window, Settings → Permissions and, for the permissions a feature uses, the feature tour.
struct PermissionList: View {
    let permissions: PermissionCenter
    var kinds = PermissionKind.available

    var body: some View {
        ForEach(kinds) { kind in
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon(for: kind))
                    .foregroundStyle(color(for: kind))
                    .font(.title2)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(kind.displayName).font(.headline)
                        if kind.isRequired {
                            Text("required").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Text(kind.purpose).font(.callout).foregroundStyle(.secondary)
                    if permissions.status(of: kind) != .granted {
                        Text(kind.grantHint())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                if permissions.status(of: kind) == .granted {
                    Text("Granted").foregroundStyle(.secondary)
                } else {
                    Button("Grant…") {
                        Task {
                            let status = await permissions.request(kind)
                            if status != .granted {
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

    private func icon(for kind: PermissionKind) -> String {
        permissions.status(of: kind) == .granted ? "checkmark.circle.fill" : "exclamationmark.circle"
    }

    private func color(for kind: PermissionKind) -> Color {
        if permissions.status(of: kind) == .granted {
            return .green
        }
        return kind.isRequired ? .orange : .secondary
    }
}
