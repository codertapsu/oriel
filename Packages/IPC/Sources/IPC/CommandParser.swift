import Foundation
import OrielCore

/// Turns `oriel` arguments into an `IPCRequest` (PLAN §7.1.8), by hand: no swift-argument-parser.
///
/// `oriel <noun> <verb> [arguments] [--option value] [--flag]` becomes the verb `noun.verb`; a command that is one word,
/// such as `oriel top`, is its own verb.
public enum CommandParser {
    public enum Outcome: Equatable, Sendable {
        case request(IPCRequest, timeout: TimeInterval)
        case help
        case version
    }

    public struct ParseError: Error, Equatable, Sendable {
        public let message: String
    }

    /// The commands the app answers, by noun.
    public static let commands: [String: Set<String>] = [
        "windows": ["list", "focus", "close", "minimize"],
        "capture": ["area", "window", "screen", "text"],
        "translate": ["area"],
        "debug": ["capabilities", "open-switcher", "capture", "record", "perf-capture", "clipboard"],
        "disk": ["volumes", "scan"],
    ]

    /// Commands without a verb.
    public static let singleWordCommands: Set<String> = ["top"]

    static let valueOptions: Set<String> = [
        "space", "app", "title", "rect", "to", "path", "provider", "shortcut", "fixture", "timeout",
        "seconds", "pause-at", "resume-at", "runs", "delay", "sort", "limit", "top",
    ]
    static let flagOptions: Set<String> = ["json"]

    public static func parse(_ arguments: [String]) throws -> Outcome {
        guard let noun = arguments.first, noun != "--help", noun != "-h", noun != "help" else { return .help }
        if noun == "--version" || noun == "-v" {
            return .version
        }
        let isSingleWord = singleWordCommands.contains(noun)
        guard isSingleWord || commands[noun] != nil else { throw ParseError(message: "unknown command '\(noun)'") }
        let verbs = commands[noun] ?? []
        guard isSingleWord || (arguments.count > 1 && verbs.contains(arguments[1])) else {
            let expected = verbs.sorted().joined(separator: "|")
            throw ParseError(message: "'\(noun)' needs one of: \(expected)")
        }
        let verb = isSingleWord ? noun : "\(noun).\(arguments[1])"
        var positional: [String] = []
        var options: [String: String] = [:]
        var index = isSingleWord ? 1 : 2
        while index < arguments.count {
            let argument = arguments[index]
            if argument.hasPrefix("--") {
                let name = String(argument.dropFirst(2))
                if flagOptions.contains(name) {
                    options[name] = "true"
                } else if valueOptions.contains(name) {
                    guard index + 1 < arguments.count else { throw ParseError(message: "--\(name) needs a value") }
                    options[name] = arguments[index + 1]
                    index += 1
                } else {
                    throw ParseError(message: "unknown option --\(name)")
                }
            } else {
                positional.append(argument)
            }
            index += 1
        }
        if let rect = options["rect"], parseRect(rect) == nil {
            throw ParseError(message: "--rect must be x,y,width,height in points, e.g. 100,100,400,300")
        }
        if let delay = options["delay"], Int(delay).map(delayRange.contains) != true {
            throw ParseError(message: "--delay must be whole seconds from \(delayRange.lowerBound) to \(delayRange.upperBound)")
        }
        let request = IPCRequest(verb: verb, arguments: positional, options: options)
        return .request(request, timeout: timeout(for: request))
    }

    /// `--delay`, in whole seconds: the countdown before a capture.
    public static let delayRange = 1 ... 60

    /// `x,y,w,h` in global points.
    public static func parseRect(_ text: String) -> CGRect? {
        let numbers = text.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard numbers.count == 4, numbers[2] > 0, numbers[3] > 0 else { return nil }
        return CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
    }

    /// Interactive commands wait for the user to select something, so they get ten minutes; a scripted recording
    /// gets its length plus a minute to save the movie; a capture's `--delay` is added to its time. A disk scan reads
    /// a whole folder or volume, which can take minutes, so it gets ten too.
    static func timeout(for request: IPCRequest) -> TimeInterval {
        if let explicit = request.options["timeout"].flatMap(TimeInterval.init) {
            return explicit
        }
        if request.verb == "debug.record", let seconds = request.options["seconds"].flatMap(TimeInterval.init) {
            return seconds + 60
        }
        if request.verb == "disk.scan" {
            return 600
        }
        let interactive = (request.verb.hasPrefix("capture.") || request.verb == "translate.area") && request.options["rect"] == nil
        let delay = request.options["delay"].flatMap(TimeInterval.init) ?? 0
        return (interactive ? 600 : 30) + delay
    }
}
