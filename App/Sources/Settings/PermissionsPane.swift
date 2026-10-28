import Permissions
import SwiftUI

struct PermissionsPane: View {
    let permissions: PermissionCenter

    var body: some View {
        Form {
            Section {
                PermissionList(permissions: permissions)
            } footer: {
                Text("""
                macOS asks again from time to time whether Oriel may still record the screen; that prompt cannot be \
                switched off except by a management profile. After granting Screen Recording, quit and reopen Oriel.
                """)
            }
            Section {
                Button("Check again") { permissions.refresh() }
            }
        }
        .formStyle(.grouped)
    }
}
