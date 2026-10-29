import Foundation
import Testing
@testable import Upload

struct UploadLinkTemplateTests {
    @Test func thePathIsEncodedIntoTheTemplate() {
        #expect(UploadLinkTemplate.link("https://files.example.com/{path}", path: ["8d3f", "Café (1).png"])?.absoluteString
            == "https://files.example.com/8d3f/Caf%C3%A9%20%281%29.png")
        #expect(UploadLinkTemplate.link("https://files.example.com/view?f={path}", path: ["a b.png"])?.absoluteString
            == "https://files.example.com/view?f=a%20b.png")
    }

    @Test func aBaseGetsThePathAdded() {
        #expect(UploadLinkTemplate.link("https://files.example.com/oriel", path: ["a.png"])?
            .absoluteString == "https://files.example.com/oriel/a.png")
        #expect(UploadLinkTemplate.link("https://files.example.com/oriel/", path: ["a.png"])?
            .absoluteString == "https://files.example.com/oriel/a.png")
    }

    @Test func templatesThatMakeNoLinkAreCaught() {
        #expect(UploadLinkTemplate.link("", path: ["a.png"]) == nil)
        #expect(UploadLinkTemplate.link("files.example.com/{path}", path: ["a.png"]) == nil)
        #expect(UploadLinkTemplate.problem("files.example.com") != nil)
        #expect(UploadLinkTemplate.problem("https://files.example.com/{path}") == nil)
        #expect(UploadLinkTemplate.problem("") == nil)
    }

    @Test func linksAreCopiedInTheChosenFormat() throws {
        let link = try #require(URL(string: "https://files.example.com/a/Shot%20(1).png"))
        #expect(UploadLinkFormat.url.text(for: link, name: "Shot", isImage: true) == "https://files.example.com/a/Shot%20(1).png")
        #expect(UploadLinkFormat.markdown.text(for: link, name: "My [best] shot", isImage: true)
            == "![My \\[best\\] shot](https://files.example.com/a/Shot%20%281%29.png)")
        #expect(UploadLinkFormat.markdown.text(for: link, name: "Recording", isImage: false)
            == "[Recording](https://files.example.com/a/Shot%20%281%29.png)")
        #expect(UploadLinkFormat.html.text(for: link, name: "A & \"B\"", isImage: true)
            == "<img src=\"https://files.example.com/a/Shot%20(1).png\" alt=\"A &amp; &quot;B&quot;\">")
        #expect(UploadLinkFormat.html
            .text(for: link, name: "<b>", isImage: false) == "<a href=\"https://files.example.com/a/Shot%20(1).png\">&lt;b&gt;</a>")
    }
}
