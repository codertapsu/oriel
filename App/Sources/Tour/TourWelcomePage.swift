import AppKit
import SwiftUI

/// The feature tour's first page: where Oriel lives and how its tools start (PLAN §19).
struct TourWelcomePage: View {
    let start: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 16) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 72, height: 72)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Welcome to Oriel").font(.largeTitle.bold())
                        Text("Everyday tools for your Mac, in the menu bar.").foregroundStyle(.secondary)
                    }
                }
                tip(
                    "menubar.rectangle",
                    "In the menu bar",
                    "Every tool starts from Oriel's icon in the menu bar, or from its shortcut. While one of Oriel's "
                        + "windows is open, Oriel is in the Dock too."
                )
                tip("command", "Shortcuts", "Settings → Shortcuts lists every shortcut; click one to change it.")
                tip("gearshape", "Settings", "Each tool has a page in Settings, and Settings → General turns tools on and off.")
                tip("star.circle", "Oriel Pro", proText)
                Button("Take the Tour", action: start)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding(28)
            .frame(maxWidth: 640, alignment: .leading)
        }
    }

    private var proText: String {
        #if APP_STORE
            "Every tool works for free. Oriel Pro, one purchase with no subscription, adds what these pages mark PRO; "
                + "Settings → Oriel Pro has it."
        #else
            "This edition includes every Pro feature."
        #endif
    }

    private func tip(_ symbol: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
                .frame(width: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(text).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
