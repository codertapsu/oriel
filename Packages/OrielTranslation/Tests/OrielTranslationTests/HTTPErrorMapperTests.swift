import Foundation
@testable import OrielTranslation
import Testing

struct HTTPErrorMapperTests {
    @Test(arguments: [
        (#"{"error":{"message":"from OpenAI"}}"#, "from OpenAI"),
        (#"{"error":"from llama.cpp"}"#, "from llama.cpp"),
        (#"{"message":"from DeepL"}"#, "from DeepL"),
        ("plain words", "plain words"),
    ])
    func findsTheMessageInErrorBodies(_ body: String, _ message: String) {
        #expect(HTTPErrorMapper.message(in: Data(body.utf8)) == message)
    }

    @Test func ignoresHTMLErrorPages() {
        #expect(HTTPErrorMapper.message(in: Data("<html><body>502 Bad Gateway</body></html>".utf8)) == nil)
        let failure = HTTPErrorMapper.failure(status: 502, body: Data("<html></html>".utf8), response: nil, kind: .openAICompatible)
        #expect(failure == .server(status: 502, message: "Bad Gateway"))
    }
}
