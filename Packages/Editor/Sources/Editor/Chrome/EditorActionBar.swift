import SwiftUI

/// The strip below the canvas: drag-out and the output size, undo and redo, zoom, and the output actions.
struct EditorActionBar: View {
    let session: EditorSession
    let actions: EditorActions

    var body: some View {
        HStack(spacing: 6) {
            DragOutHandle(makePayload: actions.dragPayload, onDelivered: actions.dragDelivered)
                .frame(width: 28, height: 28)
            Text("\(Int(session.outputPixelSize.width)) × \(Int(session.outputPixelSize.height))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityLabel("Image size \(Int(session.outputPixelSize.width)) by \(Int(session.outputPixelSize.height)) pixels")
            Spacer(minLength: 8)
            iconButton("arrow.uturn.backward", label: "Undo", help: session.canUndo ? session.undoManager.undoMenuItemTitle : "Undo (⌘Z)") {
                session.undo()
            }
            .disabled(!session.canUndo)
            iconButton("arrow.uturn.forward", label: "Redo", help: session.canRedo ? session.undoManager.redoMenuItemTitle : "Redo (⇧⌘Z)") {
                session.redo()
            }
            .disabled(!session.canRedo)
            Divider().frame(height: 18).padding(.horizontal, 4)
            iconButton("minus.magnifyingglass", label: "Zoom Out", help: "Zoom Out (⌘-)", action: actions.zoomOut)
            Button(action: actions.actualSize) {
                Text("\(Int((session.zoom * 100).rounded())) %")
                    .font(.caption.monospacedDigit())
                    .frame(minWidth: 42)
            }
            .buttonStyle(.borderless)
            .help("Actual Size (⌘0)")
            .accessibilityLabel("Zoom \(Int((session.zoom * 100).rounded())) percent, actual size")
            iconButton("plus.magnifyingglass", label: "Zoom In", help: "Zoom In (⌘=)", action: actions.zoomIn)
            iconButton(
                "arrow.up.left.and.down.right.magnifyingglass",
                label: "Zoom to Fit",
                help: "Zoom to Fit (⌘9)",
                action: actions.zoomToFit
            )
            Divider().frame(height: 18).padding(.horizontal, 4)
            iconButton("eye", label: "Quick Look", help: "Quick Look (⌘Y)", action: actions.quickLook)
            Button("Copy", systemImage: "doc.on.doc", action: actions.copy).help("Copy Image (⌘C)")
            Button("Save", systemImage: "square.and.arrow.down", action: actions.save).help("Save Editable Copy (⌘S)")
            Button("Export…", systemImage: "square.and.arrow.up", action: actions.export).help("Export (⌘E)")
            if session.uploadAvailable {
                Button("Upload", systemImage: "icloud.and.arrow.up", action: actions.upload).help("Upload")
            }
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func iconButton(_ symbol: String, label: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).frame(width: 24, height: 24).contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(help)
        .accessibilityLabel(label)
    }
}
