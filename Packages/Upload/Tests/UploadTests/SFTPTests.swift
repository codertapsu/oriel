import Foundation
import Testing
@testable import Upload

struct SFTPTests {
    @Test(arguments: [
        ("/srv/files", #""/srv/files""#),
        ("a b/it's #1", #""a b/it's #1""#),
        ("Café", #""Café""#),
    ])
    func safePathsAreDoubleQuoted(path: String, quoted: String) {
        #expect(SFTPBatch.quoted(path) == quoted)
    }

    @Test(arguments: ["a\"b", "a\\b", "a*b", "a?b", "a[b", "a]b", "a\nput evil", "a\rb", ""])
    func pathsSftpWouldReadDifferentlyAreRefused(path: String) {
        #expect(SFTPBatch.quoted(path) == nil)
    }

    @Test func templateNamesLoseSftpsWildcards() {
        #expect(SFTPBatch.safeName("[Draft] Notes") == "(Draft) Notes")
    }

    @Test func theCommandLineNeverPromptsAndChecksHostKeys() {
        let plain = SFTPBatch.arguments(for: SFTPConfiguration(host: "nas.local"))
        #expect(plain == [
            "-b", "-", "-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes", "-o", "ConnectTimeout=20",
            "-o", "ServerAliveInterval=15", "-o", "ServerAliveCountMax=2", "nas.local",
        ])
        let full = SFTPBatch.arguments(for: SFTPConfiguration(
            host: "files.example.com",
            port: 2222,
            username: "marcus",
            identityFile: "/k/id_ed25519"
        ))
        #expect(Array(full.suffix(9)) == [
            "-P",
            "2222",
            "-o",
            "User=marcus",
            "-i",
            "/k/id_ed25519",
            "-o",
            "IdentitiesOnly=yes",
            "files.example.com",
        ])
        let typed = SFTPConfiguration(host: " deploy@web1 ")
        #expect(typed.trimmedHost == "web1")
        #expect(typed.effectiveUsername == "deploy")
        #expect(SFTPBatch.arguments(for: typed).suffix(3) == ["-o", "User=deploy", "web1"])
    }

    @Test func settingsThatCouldBecomeOptionsAreRefused() {
        #expect(SFTPConfiguration(host: "-oProxyCommand=evil").problem != nil)
        #expect(SFTPConfiguration(host: "two words").problem != nil)
        #expect(SFTPConfiguration(host: "h", username: "-x").problem != nil)
        #expect(SFTPConfiguration(host: "h", port: 70000).problem != nil)
        #expect(SFTPConfiguration(host: "h", remoteFolder: "up*").problem != nil)
        #expect(SFTPConfiguration(host: "h", remoteFolder: "uploads/2026").problem == nil)
        #expect(SFTPConfiguration().missingField == "a host")
    }

    @Test func theBatchGoesToTheFolderMakesFoldersAndPuts() throws {
        let script = try SFTPBatch.uploadScript(folder: "/srv/www/files", path: ["8d3f", "-x", "Safari.png"], localFile: "/tmp/o/upload")
        #expect(script == """
        cd "/srv/www/files"
        pwd
        -mkdir "./8d3f"
        -mkdir "./8d3f/-x"
        put "/tmp/o/upload" "./8d3f/-x/Safari.png"

        """)
        #expect(try SFTPBatch.uploadScript(folder: "", path: ["a.png"], localFile: "/l") == "pwd\nput \"/l\" \"./a.png\"\n")
        #expect(try SFTPBatch.testScript(folder: "~/uploads") == "cd \"./uploads\"\npwd\n")
        #expect(try SFTPBatch.testScript(folder: "~") == "pwd\n")
        #expect(try SFTPBatch.testScript(folder: "public_html") == "cd \"./public_html\"\npwd\n")
        #expect(throws: UploadError.self) { try SFTPBatch.uploadScript(folder: "a\"b", path: ["a.png"], localFile: "/l") }
    }

    @Test func pwdSaysWhereUploadsWent() {
        let output = "sftp> cd \"./uploads\"\nsftp> pwd\nRemote working directory: /home/marcus/uploads\nsftp> put …\n"
        #expect(SFTPBatch.workingDirectory(in: output) == "/home/marcus/uploads")
        #expect(SFTPBatch.workingDirectory(in: "nothing") == nil)
    }

    @Test(arguments: [
        (
            "No ED25519 host key is known for nas.local and you have requested strict checking.\n"
                + "Host key verification failed.\nConnection closed",
            UploadError.hostKeyUnknown(host: "nas.local")
        ),
        (
            "@@@@@@@@@@@\n@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @\nHost key verification failed.",
            UploadError.hostKeyChanged(host: "nas.local")
        ),
        (
            "marcus@nas.local: Permission denied (publickey).\r\nConnection closed",
            UploadError.unauthorized(SFTPFailure.authenticationAdvice(host: "nas.local"))
        ),
        (
            "Received disconnect from 10.0.0.2 port 22:2: Too many authentication failures",
            .unauthorized(SFTPFailure.authenticationAdvice(host: "nas.local"))
        ),
        (
            "ssh: Could not resolve hostname nas.local: nodename nor servname provided, or not known\r\nConnection closed",
            .unreachable("Oriel can't find the server “nas.local”. Check the host name.")
        ),
        (
            "ssh: connect to host nas.local port 22: Connection refused",
            .unreachable("The server refused the connection. Is SSH running on it, on that port?")
        ),
        ("ssh: connect to host nas.local port 22: Operation timed out", .timedOut),
        (
            "ssh: connect to host nas.local port 22: No route to host",
            .unreachable("This Mac can't reach “nas.local”. Check the network or VPN.")
        ),
        (
            "Couldn't canonicalize: No such file or directory",
            .notFound("The folder “uploads” doesn't exist on the server. Make it, or change the folder in Settings → Upload.")
        ),
        ("dest open \"/srv/uploads/a.png\": Permission denied", .forbidden("The server doesn't let you write to “uploads”.")),
        ("Couldn't write to remote file \"/x\": No space left on device", .quotaExceeded("The server has no space left.")),
        (
            "Warning: Identity file /k/id not accessible: No such file or directory.",
            .invalidSettings("The key file in Settings → Upload isn't there.")
        ),
        ("subsystem request failed on channel 0\r\nConnection closed", .unreachable("“nas.local” accepts SSH but doesn't offer SFTP.")),
        ("something odd\nthe last line", .failed("sftp stopped with status 1: the last line")),
    ])
    func stderrBecomesAnErrorThatSaysWhatToDo(standardError: String, expected: UploadError) {
        #expect(SFTPFailure.error(status: 1, standardError: standardError, host: "nas.local", folder: "uploads") == expected)
    }

    @Test func anUploadRunsSftpWithTheBatchAndMakesTheLink() async throws {
        let temporary = try TemporaryFolder()
        defer { temporary.remove() }
        let runner = FakeProcessRunner(ProcessResult(status: 0, standardOutput: Data("Remote working directory: /srv/files\n".utf8)))
        let configuration = SFTPConfiguration(host: "nas.local", port: 2222, username: "marcus", remoteFolder: "/srv/files")
        let payload = try temporary.payload(Data("PNG".utf8))
        let receipt = try await SFTPDestination(configuration: configuration, runner: runner).upload(
            payload,
            to: ["8d3f", "[x] Safari.png"]
        ) { _ in }
        #expect(receipt.link.absoluteString == "sftp://marcus@nas.local:2222/srv/files/8d3f/%28x%29%20Safari.png")
        #expect(receipt.path == ["8d3f", "(x) Safari.png"])
        let run = try #require(runner.recorded.first)
        #expect(run.executable.path == "/usr/bin/sftp")
        #expect(run.arguments.contains("BatchMode=yes"))
        #expect(run.input.contains("put \""))
        #expect(run.input.hasSuffix("\"./8d3f/(x) Safari.png\"\n"))
        // sftp was pointed at the payload itself, under a name Oriel chose.
        #expect(run.uploadedBytes == Data("PNG".utf8))

        var templated = configuration
        templated.publicURLTemplate = "https://files.example.com/{path}"
        let linked = try await SFTPDestination(configuration: templated, runner: runner).upload(payload, to: ["a b.png"]) { _ in }
        #expect(linked.link.absoluteString == "https://files.example.com/a%20b.png")
    }

    @Test func aFailedRunIsExplained() async throws {
        let temporary = try TemporaryFolder()
        defer { temporary.remove() }
        let refused = Data("marcus@nas.local: Permission denied (publickey).\nConnection closed\n".utf8)
        let runner = FakeProcessRunner(ProcessResult(status: 255, standardError: refused))
        let destination = SFTPDestination(configuration: SFTPConfiguration(host: "nas.local"), runner: runner)
        await #expect(throws: UploadError.unauthorized(SFTPFailure.authenticationAdvice(host: "nas.local"))) {
            try await destination.upload(temporary.payload(Data("x".utf8)), to: ["a.png"]) { _ in }
        }
        await #expect(throws: UploadError.invalidSettings("The host can't start with “-” or contain spaces, quotes or backslashes.")) {
            try await SFTPDestination(configuration: SFTPConfiguration(host: "-oProxyCommand=x"), runner: runner).testConnection()
        }
        #expect(runner.recorded.count == 1)
    }

    @Test func connectionSaysWhereUploadsGo() async throws {
        let runner = FakeProcessRunner(ProcessResult(status: 0, standardOutput: Data("Remote working directory: /home/marcus\n".utf8)))
        let message = try await SFTPDestination(configuration: SFTPConfiguration(host: "nas.local"), runner: runner).testConnection()
        #expect(message == "Connected to nas.local. Uploads go to /home/marcus.")
        #expect(runner.recorded.first?.input == "pwd\n")
    }
}
