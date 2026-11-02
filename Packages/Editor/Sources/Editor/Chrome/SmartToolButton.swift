import OrielCore
import SharedUI
import SwiftUI

/// A toolbar button that opens one of the smart tools' review panels; each is a Pro feature (PLAN §19).
struct SmartToolButton<Panel: View>: View {
    let symbol: String
    let title: String
    let help: String
    let isPresented: Binding<Bool>
    let proFeature: ProFeature
    @ViewBuilder let panel: () -> Panel

    var body: some View {
        let isPresented = isPresented.gated(by: proFeature)
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
        .overlay(alignment: .topTrailing) { ProBadge(proFeature).scaleEffect(0.7).offset(x: 8, y: -6) }
        .popover(isPresented: isPresented, arrowEdge: .bottom, content: panel)
    }
}
