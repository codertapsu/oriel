import OrielCore
import SwiftUI

/// The mark next to a Pro feature in Settings and the feature tour while Oriel Pro is locked (PLAN §19); clicking it shows
/// what Pro adds. It disappears once Pro is unlocked, and never shows in the Developer ID edition.
public struct ProBadge: View {
    private let feature: ProFeature
    private let access: ProAccess

    public init(_ feature: ProFeature, access: ProAccess = .shared) {
        self.feature = feature
        self.access = access
    }

    public var body: some View {
        if !access.isUnlocked {
            Button {
                access.check(feature)
            } label: {
                Text("PRO")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .foregroundStyle(.white)
                    .background(Capsule().fill(Color.accentColor))
            }
            .buttonStyle(.plain)
            .help("\(feature.title) is part of Oriel Pro")
            .accessibilityLabel("\(feature.title) needs Oriel Pro")
        }
    }
}

public extension Binding<Bool> {
    /// Turning the setting on asks for `feature` first and stays off while Pro is locked; turning it off always works.
    func gated(by feature: ProFeature, access: ProAccess = .shared) -> Binding<Bool> {
        Binding(
            get: { wrappedValue && access.allows(feature) },
            set: { isOn in
                if !isOn || access.check(feature) {
                    wrappedValue = isOn
                }
            }
        )
    }
}
