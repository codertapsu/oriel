import Foundation
@testable import OrielTranslation
import Testing

struct GlossaryCSVTests {
    @Test func readsQuotedFieldsLineBreaksAndDoubledQuotes() throws {
        let csv = "\u{FEFF}source,target,note,case_sensitive\r\n"
            + "capture,キャプチャ,\"The noun, not the verb\",false\r\n"
            + "\"Say \"\"hi\"\"\",\"Dis \"\"salut\"\"\",\"two\nlines\",yes\r\n"
        let rows = try GlossaryCSV.parse(csv)
        #expect(rows.map(\.term.source) == ["capture", "Say \"hi\""])
        #expect(rows.map(\.term.target) == ["キャプチャ", "Dis \"salut\""])
        #expect(rows.map(\.term.note) == ["The noun, not the verb", "two\nlines"])
        #expect(rows.map(\.term.isCaseSensitive) == [false, true])
        #expect(rows.allSatisfy { $0.sourceLanguage == nil && $0.targetLanguage == nil })
    }

    @Test func readsTSVHeadersUnderOtherNamesAndInAnyOrder() throws {
        let tsv = "Translation\tTerm\tMatch case\nパネル\tpanel\tx\nウィンドウ\twindow\t\n"
        let rows = try GlossaryCSV.parse(tsv)
        #expect(rows.map { "\($0.term.source)=\($0.term.target)" } == ["panel=パネル", "window=ウィンドウ"])
        #expect(rows.map(\.term.isCaseSensitive) == [true, false])
    }

    @Test func withoutAHeaderTheColumnsAreSourceTargetNoteCase() throws {
        let rows = try GlossaryCSV.parse("Oriel,Oriel,brand,true\npin,épingle\n,,\n")
        #expect(rows.count == 2)
        #expect(rows[0].term.note == "brand" && rows[0].term.isCaseSensitive)
        #expect(rows[1].term.target == "épingle" && rows[1].term.note.isEmpty)
    }

    @Test func languageColumnsSendRowsToTheirPairs() throws {
        let csv = "source_language,target_language,source,target\nen,ja,pin,ピン\nen,fr,pin,épingle\n*,any,Oriel,Oriel\n"
        let rows = try GlossaryCSV.parse(csv)
        #expect(rows.map(\.sourceLanguage) == ["en", "en", ""])
        #expect(rows.map(\.targetLanguage) == ["ja", "fr", ""])
    }

    @Test func refusesFilesWithoutTerms() {
        #expect(throws: GlossaryCSV.ImportError.empty) { try GlossaryCSV.parse(" \n\n") }
        #expect(throws: GlossaryCSV.ImportError.noTerms) { try GlossaryCSV.parse("source,target\nonly-a-source,\n") }
    }

    @Test func exportsEachFormat() {
        let terms = [
            GlossaryTerm(source: "capture", target: "キャプチャ", note: "noun, UI"),
            GlossaryTerm(source: "Oriel", target: "Oriel", note: "tab\there", isCaseSensitive: true),
            GlossaryTerm(source: "empty", target: " "),
        ]
        #expect(GlossaryCSV.export(terms, format: .csv) == """
        source,target,note,case_sensitive
        capture,キャプチャ,"noun, UI",false
        Oriel,Oriel,tab\there,true

        """)
        #expect(GlossaryCSV.export(terms, format: .tsv) == """
        source\ttarget\tnote\tcase_sensitive
        capture\tキャプチャ\tnoun, UI\tfalse
        Oriel\tOriel\ttab here\ttrue

        """)
        #expect(GlossaryCSV.export(terms, format: .googleCloud) == "capture,キャプチャ\nOriel,Oriel\n")
    }

    @Test func exportedFilesImportAgain() throws {
        let terms = [
            GlossaryTerm(source: "a \"quoted\" term", target: "un terme, \"cité\"", note: "line\nbreak", isCaseSensitive: true),
            GlossaryTerm(source: "plain", target: "simple"),
        ]
        for format in [GlossaryFileFormat.csv, .tsv] {
            let rows = try GlossaryCSV.parse(GlossaryCSV.export(terms, format: format))
            #expect(rows.map(\.term.source) == terms.map(\.source))
            #expect(rows.map(\.term.target) == terms.map(\.target))
            #expect(rows.map(\.term.isCaseSensitive) == [true, false])
        }
    }

    @Test func decodesSpreadsheetEncodings() throws {
        let latin1 = try #require("café,cafe".data(using: .windowsCP1252))
        #expect(GlossaryCSV.decode(latin1) == "café,cafe")
        let utf16 = try #require("pin,ピン".data(using: .utf16))
        #expect(GlossaryCSV.decode(utf16) == "pin,ピン")
        #expect(GlossaryCSV.decode(Data("naïve".utf8)) == "naïve")
    }
}
