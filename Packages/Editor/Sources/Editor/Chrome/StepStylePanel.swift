import SwiftUI

/// The popover of `StepStyleButton`: shape, label style, pointer, and the next number with Restart and Continue.
struct StepStylePanel: View {
    let session: EditorSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Numbered Steps").font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    Text("Shape").foregroundStyle(.secondary).gridColumnAlignment(.trailing)
                    Picker("Shape", selection: Binding(get: { session.stepStyle.shape }, set: { session.setStepShape($0) })) {
                        ForEach(StepShape.allCases) { shape in
                            Label(shape.title, systemImage: shape.symbolName).tag(shape)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                GridRow {
                    Text("Labels").foregroundStyle(.secondary).gridColumnAlignment(.trailing)
                    Picker("Labels", selection: Binding(get: { session.stepStyle.label }, set: { session.setStepLabel($0) })) {
                        ForEach(StepLabel.allCases) { label in
                            Text(label.title).tag(label).accessibilityLabel(label.accessibilityName)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                GridRow {
                    Text("Pointer").foregroundStyle(.secondary).gridColumnAlignment(.trailing)
                    Toggle("Point at something", isOn: Binding(get: { session.stepStyle.pointer }, set: { session.setStepPointer($0) }))
                        .toggleStyle(.checkbox)
                }
                GridRow {
                    Text("Next").foregroundStyle(.secondary).gridColumnAlignment(.trailing)
                    HStack(spacing: 8) {
                        Stepper(value: nextNumber, in: 1 ... 999) {
                            Text(session.nextStepLabel)
                                .font(.body.monospacedDigit().weight(.semibold))
                                .frame(minWidth: 28, alignment: .leading)
                        }
                        .accessibilityLabel("Next step")
                        .accessibilityValue(session.nextStepLabel)
                        if session.pendingStepStart == nil {
                            Button("Restart at 1") { session.restartStepNumbering() }
                        } else {
                            Button("Continue") { session.continueStepNumbering() }
                        }
                    }
                    .controlSize(.small)
                }
            }
            Text(session.stepStyle.pointer
                ? "Drag from what the step points at to where it goes. Drag the tip of a selected step to aim it."
                : "Click to add the next step. Deleting a step renumbers the rest.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(width: 330)
    }

    /// The next step's number: stepping it starts a new sequence there; back to the natural next number goes on.
    private var nextNumber: Binding<Int> {
        Binding(
            get: { session.nextStepPlacement.number },
            set: { value in
                let natural = session.document.nextStepNumber(inSequence: session.document.latestStepSequence)
                if value == natural {
                    session.continueStepNumbering()
                } else {
                    session.restartStepNumbering(at: value)
                }
            }
        )
    }
}
