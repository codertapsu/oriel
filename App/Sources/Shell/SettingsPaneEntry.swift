import SwiftUI

/// One tab of the Settings window contributed by a feature.
struct SettingsPaneEntry: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let view: AnyView
}
