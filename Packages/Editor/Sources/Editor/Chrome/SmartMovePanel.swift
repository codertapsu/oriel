import SwiftUI

/// Smart Move's review (PLAN §17): the blocks of text, objects and regions found, a switch for each kind, and Lift,
/// which turns them into layers the user can drag or delete, with their holes filled, as one undo step.
struct SmartMovePanel: View {
    @Bindable var tools: SmartTools
    let isPresented: Binding<Bool>

    var body: some View {
        SmartPanelChrome(
            title: "Smart Move",
            summary: "Lifts text and objects out of the screenshot so you can drag or delete them, and fills in where "
                + "they were. It works best on flat backgrounds, such as app windows.",
            phase: tools.movePhase,
            working: "Looking for text and objects…",
            actionTitle: tools.plannedObjects.count == 1 ? "Lift 1 Object" : "Lift \(tools.plannedObjects.count) Objects",
            canApply: !tools.plannedObjects.isEmpty,
            onCancel: { isPresented.wrappedValue = false },
            onApply: {
                tools.applySmartMove()
                isPresented.wrappedValue = false
            },
            content: { review }
        )
        .onAppear { tools.findMovableObjects() }
        .onDisappear { tools.endReview(.move) }
    }

    @ViewBuilder private var review: some View {
        let sources = [ImageLayer.Source.text, .object, .region].filter { tools.count(of: $0) > 0 }
        if sources.isEmpty {
            Text("Nothing to lift was found.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(sources, id: \.self) { source in
                    Toggle(isOn: binding(for: source)) {
                        HStack {
                            Label(Self.title(of: source), systemImage: Self.symbol(of: source))
                            Spacer()
                            Text("\(tools.count(of: source))")
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .toggleStyle(.checkbox)
                }
            }
        }
        if tools.objectsUnavailable {
            Text("Separate objects can’t be found on this Mac; text and regions still can.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        if !tools.canReadText {
            Text("Blocks of text need text recognition, which isn’t available.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    static func title(of source: ImageLayer.Source) -> String {
        switch source {
        case .text: "Blocks of text"
        case .object: "Objects"
        case .region: "Regions"
        }
    }

    static func symbol(of source: ImageLayer.Source) -> String {
        switch source {
        case .text: "text.alignleft"
        case .object: "cube"
        case .region: "square.dashed"
        }
    }

    private func binding(for source: ImageLayer.Source) -> Binding<Bool> {
        Binding(
            get: { tools.moveSources.contains(source) },
            set: { isOn in
                if isOn {
                    tools.moveSources.insert(source)
                } else {
                    tools.moveSources.remove(source)
                }
            }
        )
    }
}
