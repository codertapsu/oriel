import SwiftUI

/// A toolbar button that opens one of the smart tools' review panels.
struct SmartToolButton<Panel: View>: View {
    let symbol: String
    let title: String
    let help: String
    let isPresented: Binding<Bool>
    @ViewBuilder let panel: () -> Panel

    var body: some View {
        Button {
            isPresented.wrappedValue.toggle()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(title)
        .popover(isPresented: isPresented, arrowEdge: .bottom, content: panel)
    }
}
