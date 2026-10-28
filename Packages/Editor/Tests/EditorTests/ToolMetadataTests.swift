import AppKit
@testable import Editor
import Testing

/// Toolbar metadata: every tool button is labelled, has a tooltip with its key and an existing symbol.
@MainActor
struct ToolMetadataTests {
    @Test(arguments: EditorTool.allCases)
    func toolButtonsAreLabelledAndHaveSymbols(_ tool: EditorTool) {
        #expect(!tool.title.isEmpty)
        #expect(tool.help == "\(tool.title) (\(String(tool.shortcut).uppercased()))")
        #expect(NSImage(systemSymbolName: tool.symbolName, accessibilityDescription: tool.title) != nil)
    }

    @Test func drawingToolsDrawEveryKind() {
        let drawn = Set(EditorTool.allCases.compactMap(\.drawsKind))
        #expect(drawn == Set(AnnotationKind.allCases))
        #expect(EditorTool.select.drawsKind == nil && EditorTool.crop.drawsKind == nil)
    }

    @Test func paletteColoursHaveNames() {
        for entry in RGBAColor.palette {
            #expect(entry.color.paletteName == entry.name)
        }
        #expect(RGBAColor(red: 0.5, green: 0.5, blue: 0.5).paletteName == nil)
    }
}
