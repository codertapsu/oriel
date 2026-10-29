import Foundation

/// How a command-line tool ended.
public nonisolated struct ProcessResult: Sendable, Equatable {
    public let status: Int32
    public let standardOutput: Data
    public let standardError: Data

    public init(status: Int32, standardOutput: Data = Data(), standardError: Data = Data()) {
        self.status = status
        self.standardOutput = standardOutput
        self.standardError = standardError
    }

    public var outputText: String {
        standardOutput.utf8Text
    }

    public var errorText: String {
        standardError.utf8Text
    }
}
