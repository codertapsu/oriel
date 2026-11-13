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
                macOS checks from time to time whether Oriel may still record the screen; only a management profile can \
                switch that off. After a change to Screen & System Audio Recording, macOS may ask you to quit and \
                reopen Oriel.
                """)
            }
            Section {
                Button("Check again") { permissions.refresh() }
            }
        }
        .formStyle(.grouped)
    }
}
