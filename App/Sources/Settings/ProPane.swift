import OrielCore
import SharedUI
import SwiftUI
#if APP_STORE
    import Licensing
    import StoreKit
#endif

/// Settings → Oriel Pro (PLAN §19): what Pro adds, tool by tool, and in the App Store edition the one-time purchase and
/// Restore Purchases. The Developer ID edition includes all of it.
struct ProPane: View {
    static let id = "pro"

    let controller: AppController
    @Bindable var navigation: SettingsNavigation
    private let access = ProAccess.shared
    #if APP_STORE
        @Environment(\.purchase) private var purchase
    #endif

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Oriel Pro").font(.title2.bold())
                    Text(headline).foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                if let feature = navigation.proFeature, !access.isUnlocked {
                    Label("\(feature.title) is part of Oriel Pro.", systemImage: "lock.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            #if APP_STORE
                purchaseSection
            #endif
            ForEach(groups, id: \.title) { group in
                Section(group.title) {
                    ForEach(group.features) { feature in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Image(systemName: access.isUnlocked ? "checkmark.circle.fill" : "star.circle")
                                .foregroundStyle(access.isUnlocked ? Color.green : Color.accentColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(feature.title)
                                Text(feature.summary).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .listRowBackground(feature == navigation.proFeature ? Color.accentColor.opacity(0.08) : nil)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var headline: String {
        #if APP_STORE
            access.isUnlocked
                ? "Unlocked. Thank you for supporting Oriel."
                : "Everything Oriel can do, with one purchase. Every tool works without it; Pro adds what is below."
        #else
            "This edition of Oriel includes every Pro feature."
        #endif
    }

    #if APP_STORE
        @ViewBuilder private var purchaseSection: some View {
            let store = controller.proStore
            Section {
                if !access.isUnlocked {
                    HStack {
                        Button {
                            Task { await store.purchase { product in try await purchase(product) } }
                        } label: {
                            Text(store.product.map { "Unlock Oriel Pro — \($0.displayPrice)" } ?? "Unlock Oriel Pro")
                                .frame(minWidth: 220)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(store.isPurchasing)
                        if store.isPurchasing {
                            ProgressView().controlSize(.small)
                        }
                    }
                    if store.isPending {
                        Text("Waiting for approval. Pro unlocks as soon as the purchase is approved.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                if let error = store.lastError {
                    Text(error).font(.callout).foregroundStyle(.orange)
                }
                Button("Restore Purchases") {
                    Task { await store.restore() }
                }
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("One payment, no subscription. Pro stays unlocked on every Mac where you use the same Apple Account.")
                    HStack(spacing: 12) {
                        Link("Terms of Use", destination: OrielLinks.terms)
                        Link("Privacy Policy", destination: OrielLinks.privacy)
                    }
                }
            }
            .task { await store.loadProduct() }
        }
    #endif

    /// The Pro features grouped by tool, in the order of the tools in Settings.
    private var groups: [(title: String, features: [ProFeature])] {
        let features = controller.hub.proFeatures
        var order: [String] = []
        var byTitle: [String: [ProFeature]] = [:]
        for feature in features {
            let title = Self.groupTitle(of: feature.module)
            if byTitle[title] == nil {
                order.append(title)
            }
            byTitle[title, default: []].append(feature)
        }
        return order.map { ($0, byTitle[$0] ?? []) }
    }

    private static func groupTitle(of module: ModuleID?) -> String {
        switch module {
        case .capture: "Screenshots"
        case .editor: "Editor"
        case .recording: "Screen Recording"
        case .translation: "Translation"
        case .clipboardHistory: "Clipboard History"
        case .colorPicker: "Color Picker"
        case .screenRuler: "Screen Ruler"
        case .diskAnalyzer: "Disk Space Analyzer"
        default: "Oriel"
        }
    }
}
