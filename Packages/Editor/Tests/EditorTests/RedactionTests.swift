import CoreGraphics
@testable import Editor
import Foundation
import Testing

/// Smart Redact (PLAN §17): every category is found in realistic text, look-alikes are not, finds get boxes inside
/// their line, neighbours merge, and the review applies as one undo step. Fixtures are made up; none is a live key.
@MainActor
struct RedactionTests {
    private func categories(in text: String) -> [RedactionCategory] {
        RedactionDetector.matches(in: text).map(\.category)
    }

    private func matched(_ text: String, as category: RedactionCategory) -> [String] {
        let string = text as NSString
        return RedactionDetector.matches(in: text)
            .filter { $0.category == category }
            .map { string.substring(with: NSRange(location: $0.location, length: $0.length)) }
    }

    // MARK: - Detectors

    @Test(arguments: [
        ("Contact: jane.doe+news@example.co.uk today", "jane.doe+news@example.co.uk"),
        ("Reply to OPS@EXAMPLE.ORG", "OPS@EXAMPLE.ORG"),
    ])
    func emailAddresses(_ text: String, _ expected: String) {
        #expect(matched(text, as: .email) == [expected])
        #expect(!categories(in: text).contains(.link))
    }

    @Test(arguments: [
        "Call +1 (415) 555-0132 now",
        "Tel. 020 7946 0958",
        "Mobile: +44 7700 900123",
    ])
    func phoneNumbers(_ text: String) {
        #expect(categories(in: text).contains(.phone), "\(text)")
    }

    @Test func linksAreFoundButNotEmails() {
        #expect(matched("Docs at https://example.com/docs/setup?ref=1", as: .link) == ["https://example.com/docs/setup?ref=1"])
        #expect(categories(in: "see www.example.org for more").contains(.link))
        #expect(!RedactionCategory.link.isOnByDefault)
    }

    @Test(arguments: [
        ("Server 192.168.1.20 is down", "192.168.1.20"),
        ("peer=10.0.0.1:443", "10.0.0.1"),
        ("v6 2001:db8:85a3::8a2e:370:7334 up", "2001:db8:85a3::8a2e:370:7334"),
        ("loopback ::1", "::1"),
    ])
    func ipAddresses(_ text: String, _ expected: String) {
        #expect(matched(text, as: .ipAddress) == [expected])
    }

    @Test(arguments: ["version 1.2.3", "999.1.1.1 is not an address", "at 10:30:45 today", "ratio 16:9", "a::b::c"])
    func thingsThatOnlyLookLikeAddressesAreNot(_ text: String) {
        #expect(!categories(in: text).contains(.ipAddress), "\(text)")
    }

    @Test(arguments: [
        ("Visa 4111 1111 1111 1111 exp 12/29", "4111 1111 1111 1111"),
        ("card:5500-0055-5555-5559", "5500-0055-5555-5559"),
        ("Amex 378282246310005", "378282246310005"),
    ])
    func cardNumbersThatPassLuhn(_ text: String, _ expected: String) {
        #expect(matched(text, as: .cardNumber) == [expected])
        // Not a phone number as well.
        #expect(!categories(in: text).contains(.phone))
    }

    @Test(arguments: ["4111 1111 1111 1112", "1234 5678 9012 3456", "0000 0000 0000 0000", "order 4111111111111"])
    func digitRunsThatFailLuhnAreNotCards(_ text: String) {
        #expect(!categories(in: text).contains(.cardNumber), "\(text)")
    }

    @Test func luhnAndIBANChecksums() {
        #expect(ChecksumValidators.passesLuhn([7, 9, 9, 2, 7, 3, 9, 8, 7, 1, 3]))
        #expect(!ChecksumValidators.passesLuhn([7, 9, 9, 2, 7, 3, 9, 8, 7, 1, 4]))
        #expect(ChecksumValidators.isIBAN("GB82 WEST 1234 5698 7654 32"))
        #expect(ChecksumValidators.isIBAN("DE89370400440532013000"))
        #expect(!ChecksumValidators.isIBAN("GB82 WEST 1234 5698 7654 33"))
        #expect(!ChecksumValidators.isIBAN("XX82 WEST 1234 5698 7654 32"))
        #expect(!ChecksumValidators.isIBAN("DE8937040044053201300"))
    }

    @Test(arguments: [
        ("IBAN: GB82 WEST 1234 5698 7654 32", "GB82 WEST 1234 5698 7654 32"),
        ("Pay to DE89370400440532013000.", "DE89370400440532013000"),
        ("FR14 2004 1010 0505 0001 3M02 606", "FR14 2004 1010 0505 0001 3M02 606"),
    ])
    func ibans(_ text: String, _ expected: String) {
        #expect(matched(text, as: .iban) == [expected])
    }

    @Test(arguments: [
        ("aws_access_key_id = AKIAIOSFODNN7EXAMPLE", "AKIAIOSFODNN7EXAMPLE"),
        ("session ASIAY34FZKBOKMUTVV7A expires", "ASIAY34FZKBOKMUTVV7A"),
        ("token ghp_16C7e42F292c6912E7710c838347Ae178B4a in use", "ghp_16C7e42F292c6912E7710c838347Ae178B4a"),
        ("pat github_pat_11ABCDEFG0123456789abc_defghijklmnopqrstuvwxyz0123456789ABCDEFGHIJKLMNOPQRSTUVW", nil),
        ("SLACK=xoxb-123456789012-1234567890123-AbCdEfGhIjKlMnOpQrStUvWx", nil),
        ("key: sk_live_4eC39HqLyjWDarjtT1zdp7dc", nil),
        ("publishable pk_live_51H8abcDEF234ghiJKL567mno", nil),
        ("maps AIzaSyD-9tSrke72PouQMnMX-a7eZSW0jkFMBWY", nil),
        ("Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U", nil),
        ("-----BEGIN RSA PRIVATE KEY-----", nil),
        ("-----BEGIN OPENSSH PRIVATE KEY-----", nil),
        ("password: hunter22", "hunter22"),
        ("API_KEY=\"q8F3bX9zR2mT7vL1pW4kD6yH0sJ5nC\"", "q8F3bX9zR2mT7vL1pW4kD6yH0sJ5nC"),
        ("secret wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY here", "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"),
        (
            "digest 9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08",
            "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"
        ),
    ] as [(String, String?)])
    func keysAndTokens(_ text: String, _ expected: String?) {
        let found = matched(text, as: .secret)
        #expect(!found.isEmpty, "\(text)")
        if let expected {
            #expect(found.contains(expected), "\(found)")
        }
    }

    @Test(arguments: [
        "commit a1b2c3d fixed it",
        "colour #FF8800 and deadbeef",
        "NSPersistentCloudKitContainerOptions",
        "getUserAccountSettings2ViewController",
        "id 550e8400-e29b-41d4-a716-446655440000",
        "/Users/marcus/Library/Application Support/Oriel",
        "com.codertapsu.oriel.editor",
        "The quick brown fox jumps over the lazy dog 2026",
        "Screenshot 2026-10-29 at 10.15.02",
        "build 26A434 on macOS 27.0.1",
    ])
    func ordinaryTextIsNotASecret(_ text: String) {
        #expect(!categories(in: text).contains(.secret), "\(text): \(matched(text, as: .secret))")
    }

    @Test func secretsHeuristicsMeasureRandomness() {
        #expect(SecretHeuristics.entropy(of: "aaaa") == 0)
        #expect(abs(SecretHeuristics.entropy(of: "abcd") - 2) < 0.0001)
        #expect(SecretHeuristics.classChangeRatio("aAaA") == 1)
        #expect(SecretHeuristics.classChangeRatio("abcd") == 0)
        #expect(SecretHeuristics.isUUID("550E8400-E29B-41D4-A716-446655440000"))
        #expect(SecretHeuristics.isPath("Users/marcus/Library"))
        #expect(!SecretHeuristics.isPath("wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"))
    }

    @Test func overlappingFindsKeepTheMostSpecificCategory() {
        let card = RedactionMatch(category: .cardNumber, location: 0, length: 19)
        let phone = RedactionMatch(category: .phone, location: 5, length: 14)
        let link = RedactionMatch(category: .link, location: 30, length: 10)
        #expect(RedactionDetector.resolveOverlaps([phone, link, card]) == [card, link])
        #expect(RedactionDetector.resolveOverlaps([card, card]) == [card])
    }

    @Test func thePatternsAllCompile() {
        #expect(RedactionDetector.Patterns.keys.count == 8)
        #expect(RedactionDetector.Patterns.dataDetector != nil)
    }

    // MARK: - Boxes

    @Test func aFindsBoxSitsWhereItsTextIsInTheLine() {
        let line = CGRect(x: 100, y: 50, width: 400, height: 20)
        let text = "Email: jane@example.com"
        let range = (text as NSString).range(of: "jane@example.com")
        let box = TextSpanEstimator.box(location: range.location, length: range.length, in: text, lineBox: line, padding: 3)
        // The address is the last 16 of 23 characters: in the right part of the line, the whole line's height and more.
        #expect(box.minX > line.minX + 40 && box.minX < line.minX + 160)
        #expect(box.maxX >= line.maxX && box.maxX <= line.maxX + 3)
        #expect(box.minY == line.minY - 3 && box.maxY == line.maxY + 3)
        // Never outside the padded line, whatever the range.
        let whole = TextSpanEstimator.box(location: 0, length: (text as NSString).length, in: text, lineBox: line, padding: 3)
        #expect(whole == line.insetBy(dx: -3, dy: -3))
    }

    @Test func touchingBoxesMerge() {
        let merged = BoxMerger.merge([
            CGRect(x: 0, y: 0, width: 10, height: 10),
            CGRect(x: 10.5, y: 0, width: 10, height: 10),
            CGRect(x: 100, y: 0, width: 10, height: 10),
            CGRect(x: 5, y: 9, width: 4, height: 4),
        ], tolerance: 1)
        #expect(merged == [CGRect(x: 0, y: 0, width: 20.5, height: 13), CGRect(x: 100, y: 0, width: 10, height: 10)])
        #expect(BoxMerger.merge([CGRect(x: 0, y: 0, width: 10, height: 10), CGRect(x: 20, y: 0, width: 10, height: 10)], tolerance: 1)
            .count == 2)
        #expect(BoxMerger.merge([], tolerance: 1).isEmpty)
    }

    @Test func aPrivateKeyHidesItsWholeBlock() throws {
        let lines = [
            TextLine(text: "config.pem", rect: CGRect(x: 10, y: 0, width: 80, height: 12)),
            TextLine(text: "-----BEGIN RSA PRIVATE KEY-----", rect: CGRect(x: 10, y: 20, width: 220, height: 12)),
            TextLine(
                text: "MIIEowIBAAKCAQEAuZ1fFp2Kx8n7Q6ZbXYcN0wqk5H3jUe9sR2tLmV8pO4iA6dGh",
                rect: CGRect(x: 10, y: 34, width: 400, height: 12)
            ),
            TextLine(text: "wJxk3Ld0bP9qZr+e/T7mN2c=", rect: CGRect(x: 10, y: 48, width: 160, height: 12)),
            TextLine(text: "-----END RSA PRIVATE KEY-----", rect: CGRect(x: 10, y: 62, width: 210, height: 12)),
            TextLine(text: "Thanks!", rect: CGRect(x: 10, y: 80, width: 50, height: 12)),
        ]
        let findings = RedactionPlanner.findings(in: lines)
        #expect(findings.map(\.category) == [.secret])
        let block = try #require(findings.first?.rect)
        #expect(block.minY < 20 && block.maxY > 74)
        #expect(!block.contains(CGPoint(x: 30, y: 86)))
    }

    @Test func regionsAreStrongEnoughForTheirTextAndClippedToTheImage() {
        let findings = [
            RedactionFinding(category: .email, rect: CGRect(x: 10, y: 10, width: 100, height: 20)),
            RedactionFinding(category: .email, rect: CGRect(x: 105, y: 10, width: 50, height: 20)),
            RedactionFinding(category: .link, rect: CGRect(x: 10, y: 50, width: 80, height: 20)),
            RedactionFinding(category: .phone, rect: CGRect(x: 190, y: 90, width: 40, height: 20)),
        ]
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 150)
        let regions = RedactionPlanner.regions(for: findings, categories: [.email, .phone], effect: .pixelate, in: bounds)
        #expect(regions.map(\.kind) == [.pixelate, .pixelate])
        #expect(regions.map(\.frame) == [CGRect(x: 10, y: 10, width: 145, height: 20), CGRect(x: 190, y: 90, width: 10, height: 20)])
        let blur = RedactionPlanner.regions(for: findings, categories: [.link], effect: .blur, in: bounds)
        guard case let .blur(region) = blur.first else {
            Issue.record("no blur region")
            return
        }
        #expect(region.amount >= ToolStyle.effectAmount(ToolStyle.defaultWidth))
        #expect(RedactionPlanner.counts(findings) == [.email: 2, .link: 1, .phone: 1])
    }

    // MARK: - The review

    @Test func theReviewFindsByCategoryAndAppliesAsOneUndoStep() async throws {
        let session = try EditorDocumentTests.makeSession()
        let recognizer = FakeRecognizer(lines: [
            ("Signed in as jane@example.com", CGRect(x: 10, y: 10, width: 180, height: 14)),
            ("Card 4111 1111 1111 1111", CGRect(x: 10, y: 40, width: 150, height: 14)),
            ("Docs: https://example.com/help", CGRect(x: 10, y: 70, width: 170, height: 14)),
            ("Nothing to see here", CGRect(x: 10, y: 100, width: 120, height: 14)),
        ], scale: 2)
        let tools = SmartTools(session: session, analyzer: SmartAnalyzer(recognizer: recognizer))
        let before = session.document
        tools.findRedactions()
        try await waitUntil { tools.redactPhase == .ready }
        #expect(tools.redactionCounts == [.email: 1, .cardNumber: 1, .link: 1])
        // Links are off by default: their find is outlined but not included.
        #expect(session.smartPreview.count == 3)
        #expect(session.smartPreview.count { !$0.isIncluded } == 1)
        #expect(tools.plannedRedactions.count == 2)
        tools.redactCategories.insert(.link)
        let allIncluded = session.smartPreview.allSatisfy(\.isIncluded)
        #expect(allIncluded)
        tools.redactEffect = .pixelate
        tools.applyRedactions()
        #expect(session.document.items.map(\.kind) == [.pixelate, .pixelate, .pixelate])
        #expect(session.undoManager.undoActionName == "Smart Redact")
        #expect(session.smartPreview.isEmpty)
        session.undo()
        #expect(session.document == before)
        // The text was read once; finding again uses what was read.
        tools.findRedactions()
        try await waitUntil { tools.redactPhase == .ready }
        #expect(await recognizer.calls == 1)
    }

    @Test func withoutTextRecognitionTheReviewSaysSo() async throws {
        let session = try EditorDocumentTests.makeSession()
        let tools = SmartTools(session: session, analyzer: SmartAnalyzer(recognizer: nil))
        #expect(!tools.canReadText)
        tools.findRedactions()
        try await waitUntil { tools.redactPhase != .working }
        #expect(tools.redactPhase == .failed("Text recognition isn’t available."))
    }
}
