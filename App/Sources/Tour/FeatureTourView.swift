import OrielCore
import SwiftUI

/// The feature tour (PLAN §19): a welcome page, then a page for each feature and for each tool of this edition, which
/// each declares itself (`FeatureGuide`). It opens once after onboarding, and from the menu bar's menu and Help.
struct FeatureTourView: View {
    static let welcomeID = "welcome"

    let controller: AppController
    @State private var selection = Self.welcomeID

    var body: some View {
        let guides = controller.hub.guides
        NavigationSplitView {
            List(selection: Binding(get: { selection }, set: { selection = $0 ?? Self.welcomeID })) {
                Label("Welcome", systemImage: "hand.wave").tag(Self.welcomeID)
                Section("Features") {
                    ForEach(guides.features) { Label($0.title, systemImage: $0.symbol).tag($0.id) }
                }
                Section("Tools") {
                    ForEach(guides.tools) { Label($0.title, systemImage: $0.symbol).tag($0.id) }
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210)
        } detail: {
            if let guide = (guides.features + guides.tools).first(where: { $0.id == selection }) {
                FeatureTourPage(guide: guide, controller: controller)
                    .id(guide.id)
            } else {
                TourWelcomePage { selection = guides.features.first?.id ?? Self.welcomeID }
            }
        }
        .frame(minWidth: 780, minHeight: 520)
    }
}
