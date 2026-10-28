/// Which Vision request to use (PLAN §7.6).
public enum OCRMode: String, Codable, Sendable {
    /// `RecognizeDocumentsRequest`: paragraphs, lists and tables. For the translation overlay and history.
    case document
    /// `RecognizeTextRequest`: lines, lowest latency. For "Copy Text".
    case fast
}
