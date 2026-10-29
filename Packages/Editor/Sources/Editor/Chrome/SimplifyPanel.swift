import SwiftUI

/// Simplify's review (PLAN §17): how many lines of text become bars, whether the rest of the image is toned down
/// and by how much, and Simplify, which applies it as one undo step.
struct SimplifyPanel: View {
    @Bindable var tools: SmartTools
    let isPresented: Binding<Bool>

    var body: some View {
        SmartPanelChrome(
            title: "Simplify",
            summary: "Replaces each line of text with a bar in its colour, for a clean diagram of the screenshot. "
                + "It works best on flat backgrounds, such as app windows.",
            phase: tools.simplifyPhase,
            working: "Reading the text…",
            actionTitle: "Simplify",
            canApply: !tools.simplifyPlan.bars.isEmpty || tools.tonesDown,
            onCancel: { isPresented.wrappedValue = false },
            onApply: {
                tools.applySimplification()
                isPresented.wrappedValue = false
            },
            content: { review }
        )
        .onAppear { tools.findSimplification() }
        .onDisappear { tools.endReview(.simplify) }
    }

    @ViewBuilder private var review: some View {
        let count = tools.simplifyPlan.bars.count
        Text(count == 0 ? "No text was found." : count == 1 ? "1 line of text becomes a bar." : "\(count) lines of text become bars.")
        Toggle("Tone down the rest", isOn: $tools.tonesDown)
            .toggleStyle(.checkbox)
        if tools.tonesDown {
            Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                SliderRow(title: "Amount", value: $tools.toneAmount, range: 0.1 ... 1, format: { "\(Int(($0 * 100).rounded())) %" })
            }
        }
    }
}
