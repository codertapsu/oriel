import Permissions
import SwiftUI

struct OnboardingView: View {
    let permissions: PermissionCenter
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Oriel needs a few permissions").font(.title2.bold())
            Text("""
            Each one unlocks a tool; nothing is sent anywhere. Grant what you want to use now — you can come back \
            from the status menu or Settings → Permissions at any time.
            """)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            Divider()
            PermissionList(permissions: permissions)
            Divider()
            Text("After granting Screen Recording, quit and reopen Oriel. macOS will ask again now and then whether it may still record.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Open Privacy & Security") { permissions.openSystemSettings(for: .accessibility) }
                Spacer()
                Button(permissions.allRequiredGranted ? "Done" : "Continue without") { onContinue() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 560)
    }
}
