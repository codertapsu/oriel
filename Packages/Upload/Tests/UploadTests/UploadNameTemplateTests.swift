import Foundation
import Testing
@testable import Upload

struct UploadNameTemplateTests {
    private let utc = TimeZone(identifier: "UTC") ?? .current

    private func context(_ name: String = "Safari") -> UploadNameTemplate.Context {
        // 2026-10-29 10:15:30 UTC.
        UploadNameTemplate.Context(name: name, date: Date(timeIntervalSince1970: 1_793_268_930), random: "8d3f6c0b9a7e4f21b5c2d9e0a1f3b4c5")
    }

    @Test func theDefaultsAreARandomFolderOrAReadableName() {
        #expect(UploadNameTemplate.render(UploadNameTemplate.unguessable, context: context(), fileExtension: "png", timeZone: utc)
            == ["8d3f6c0b9a7e4f21b5c2d9e0a1f3b4c5", "Safari.png"])
        #expect(UploadNameTemplate.render(UploadNameTemplate.readable, context: context(), fileExtension: ".mov", timeZone: utc)
            == ["Safari 2026-10-29 at 10.15.30.mov"])
        let token = UploadNameTemplate.randomToken()
        #expect(token.count == 32 && token.allSatisfy(\.isHexDigit))
        #expect(token != UploadNameTemplate.randomToken())
    }

    @Test func aSlashInTheNameNeverMakesAFolder() {
        #expect(UploadNameTemplate.render("{date}/{name}", context: context("a/b: c"), fileExtension: "png", timeZone: utc)
            == ["2026-10-29", "a-b- c.png"])
    }

    @Test func templatesThatLeaveNothingFallBackToTheName() {
        #expect(UploadNameTemplate.render("", context: context(), fileExtension: "png") == ["Safari.png"])
        #expect(UploadNameTemplate.render("../../{name}", context: context(), fileExtension: "png") == ["Safari.png"])
        #expect(UploadNameTemplate.render("{name}", context: context("  "), fileExtension: "png") == ["Oriel.png"])
        #expect(UploadNameTemplate
            .render("{random}/", context: context(), fileExtension: "png") == ["8d3f6c0b9a7e4f21b5c2d9e0a1f3b4c5.png"])
    }

    @Test(arguments: [
        ("a\\b:c*d?e\"f<g>h|i", "a-b-c-d-e-f-g-h-i"),
        ("  spaced \t out  ", "spaced out"),
        ("..hidden", "hidden"),
        ("trailing. . ", "trailing"),
        ("line\nbreak", "line break"),
        ("...", ""),
    ])
    func segmentsAreSafeEverywhere(input: String, expected: String) {
        #expect(UploadNameTemplate.sanitize(input) == expected)
    }

    @Test func longNamesAreCut() {
        #expect(UploadNameTemplate.sanitize(String(repeating: "x", count: 500)).count == UploadNameTemplate.maxSegmentLength)
    }

    @Test func templatesSayWhetherTheyRepeatOrCanBeGuessed() {
        #expect(UploadNameTemplate.namesAreUnique("{name} {time}"))
        #expect(!UploadNameTemplate.namesAreUnique("{name} {date}"))
        #expect(UploadNameTemplate.isUnguessable("{random}/{name}"))
        #expect(!UploadNameTemplate.isUnguessable("{name} {time}"))
    }

    @Test func aNameInUseIsNumbered() {
        #expect(UploadRename.numbered(["a", "Shot.png"], 1) == ["a", "Shot.png"])
        #expect(UploadRename.numbered(["a", "Shot.png"], 2) == ["a", "Shot 2.png"])
        #expect(UploadRename.numbered(["README"], 3) == ["README 3"])
        #expect(UploadRename.numbered([".env"], 2) == [".env 2"])
    }
}
