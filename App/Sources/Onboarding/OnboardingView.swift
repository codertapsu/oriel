import Permissions
import SwiftUI

/// The welcome window's permissions page (PLAN §8.2). It comes before any permission request, so it only describes:
/// macOS asks for a permission when the user chooses its Continue, and Done closes it whatever was allowed (App Review
/// Guidelines 5.1.1(iv)).
struct OnboardingView: View {
    let permissions: PermissionCenter
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Before you start").font(.title2.bold())
            Text("""
            Some of Oriel's tools read the screen, and recordings can add your voice and camera. macOS asks you \
            before Oriel can use any of these: choose Continue next to one to see its request. The tools that do not \
            use a permission work either way, and you can decide later from Oriel's menu or Settings → Permissions.
            """)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            Divider()
            PermissionList(permissions: permissions, context: .welcome)
            Divider()
            Text("""
            If you allow Screen & System Audio Recording, macOS may ask you to quit and reopen Oriel, and it checks \
            with you again from time to time.
            """)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Done") { onContinue() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 560)
    }
}
