import SwiftUI

/// Smart Redact's review (PLAN §17): what was found, by category with a count and a switch each, blur or pixelate,
/// and Redact, which adds the regions as one undo step. The finds are outlined on the canvas meanwhile.
struct SmartRedactPanel: View {
    @Bindable var tools: SmartTools

    var body: some View {
        SmartPanelChrome(
            title: "Smart Redact",
            summary: "Finds private details in the text — keys, card numbers, accounts, emails, phone numbers, IP addresses — "
                + "and hides them. It reads the image on this Mac only.",
            phase: tools.redactPhase,
            working: "Reading the text…",
            actionTitle: applyTitle,
            canApply: !tools.plannedRedactions.isEmpty,
            onCancel: { tools.isRedactPresented = false },
            onApply: { tools.applyRedactions() },
            content: { review }
        )
        .onAppear { tools.findRedactions() }
        .onDisappear { tools.endReview(.redact) }
    }

    @ViewBuilder private var review: some View {
        let counts = tools.redactionCounts
        let found = RedactionCategory.allCases.filter { (counts[$0] ?? 0) > 0 }
        if found.isEmpty {
            Text("Nothing private was found in the text.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(found) { category in
                    Toggle(isOn: binding(for: category)) {
                        HStack {
                            Label(category.title, systemImage: category.symbolName)
                            Spacer()
                            Text("\(counts[category] ?? 0)")
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)
                    .accessibilityValue("\(counts[category] ?? 0) found")
                }
            }
            Picker("Hide with", selection: $tools.redactEffect) {
                ForEach(RedactionEffect.allCases) { effect in
                    Text(effect.title).tag(effect)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var applyTitle: String {
        let count = tools.plannedRedactions.count
        return count == 1 ? "Redact 1 Area" : "Redact \(count) Areas"
    }

    private func binding(for category: RedactionCategory) -> Binding<Bool> {
        Binding(
            get: { tools.redactCategories.contains(category) },
            set: { isOn in
                if isOn {
                    tools.redactCategories.insert(category)
                } else {
                    tools.redactCategories.remove(category)
                }
            }
        )
    }
}
