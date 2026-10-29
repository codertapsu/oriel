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

    /// Every kind is drawn by a tool, except the ones only the smart tools make.
    @Test func drawingToolsDrawEveryKindButTheSmartToolsOwn() {
        let drawn = Set(EditorTool.allCases.compactMap(\.drawsKind))
        #expect(drawn == Set(AnnotationKind.allCases).subtracting(AnnotationKind.madeBySmartTools))
        #expect(drawn.isDisjoint(with: AnnotationKind.madeBySmartTools))
        #expect(EditorTool.select.drawsKind == nil && EditorTool.crop.drawsKind == nil)
    }

    /// The symbols of the new chrome exist on this system.
    @Test(arguments: [
        "eye.slash", "text.redaction", "wand.and.stars", "photo.on.rectangle", "menubar.dock.rectangle", "photo.badge.plus",
        "arrow.up.forward.app", "icloud.and.arrow.up", "square.and.arrow.down", "doc.on.doc", "xmark", "text.alignleft", "cube",
        "square.dashed", "1.circle.fill", "1.square.fill", "slash.circle",
    ])
    func chromeSymbolsExist(_ name: String) {
        #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil)
    }

    @Test func categorySymbolsExist() {
        for category in RedactionCategory.allCases {
            #expect(NSImage(systemSymbolName: category.symbolName, accessibilityDescription: nil) != nil, "\(category)")
        }
    }

    @Test func paletteColoursHaveNames() {
        for entry in RGBAColor.palette {
            #expect(entry.color.paletteName == entry.name)
        }
        #expect(RGBAColor(red: 0.5, green: 0.5, blue: 0.5).paletteName == nil)
    }
}
