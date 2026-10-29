@testable import ActivityMonitor
import Testing

struct NettopParserTests {
    /// What `nettop -L 1 -n -x -t external -J bytes_in,bytes_out` printed on this Mac, trimmed.
    static let output = """
    ,bytes_in,bytes_out,
    apsd.371,6132,44282,
    tcp4 192.168.2.197:52167<->17.57.145.54:443,6132,44282,
    mDNSResponder.472,175244,117509,
    udp6 *.5353<->*.*,81172,52408,
    udp4 *:5353<->*:*,94072,65101,
    com.apple.WebKi.5135,2091966,2324,
    tcp4 10.14.0.2:57094<->142.251.223.37:443,2091966,2324,
    Code Helper (Pl.3285,0,0,
    """

    @Test func processesAndTheirConnections() {
        let processes = NettopParser.parse(Self.output)
        #expect(Set(processes.keys) == [371, 472, 5135, 3285])
        #expect(processes[371]?.total == TrafficBytes(received: 6132, sent: 44282))
        #expect(processes[371]?.connections["tcp4 192.168.2.197:52167<->17.57.145.54:443"] == TrafficBytes(received: 6132, sent: 44282))
        #expect(processes[472]?.connections.count == 2)
        #expect(processes[3285]?.connections.isEmpty == true)
    }

    @Test func namesWithDotsSpacesAndCommasKeepTheirPID() {
        let output = """
        ,bytes_in,bytes_out,
        com.apple.geod.489,5922,3828,
        Odd, Name 2.0.77,10,20,
        tcp4 1.2.3.4:1<->5.6.7.8:2,10,20,
        """
        let processes = NettopParser.parse(output)
        #expect(processes[489]?.total == TrafficBytes(received: 5922, sent: 3828))
        #expect(processes[77]?.total == TrafficBytes(received: 10, sent: 20))
        #expect(processes[77]?.connections.count == 1)
        #expect(NettopParser.pid(of: "launchd.1") == 1)
        #expect(NettopParser.pid(of: "no-pid") == nil)
        #expect(NettopParser.pid(of: "name.x1") == nil)
    }

    @Test func theHeaderDecidesWhichColumnIsWhich() {
        let output = """
        ,packets_in,bytes_in,packets_out,bytes_out,
        apsd.371,58,6108,93,44140,
        """
        #expect(NettopParser.parse(output)[371]?.total == TrafficBytes(received: 6108, sent: 44140))
    }

    @Test func repeatedConnectionsAreKeptApart() {
        let output = """
        ,bytes_in,bytes_out,
        mDNSResponder.472,30,0,
        udp4 *:5353<->*:*,10,0,
        udp4 *:5353<->*:*,20,0,
        """
        let connections = NettopParser.parse(output)[472]?.connections
        #expect(connections?["udp4 *:5353<->*:*"] == TrafficBytes(received: 10, sent: 0))
        #expect(connections?["udp4 *:5353<->*:*#2"] == TrafficBytes(received: 20, sent: 0))
    }

    @Test func malformedLinesAndOrphanConnectionsAreSkipped() {
        let output = """
        tcp4 1.2.3.4:1<->5.6.7.8:2,10,20,
        ,bytes_in,bytes_out,
        broken line
        apsd.371,1 KiB,20,
        nopid,1,2,
        tcp4 9.9.9.9:1<->8.8.8.8:2,10,20,
        """
        #expect(NettopParser.parse(output).isEmpty)
    }

    @Test func connectionsAddWhatTheyCarriedSinceTheLastRun() {
        let earlier = ProcessNetwork(
            connections: ["a": TrafficBytes(received: 100, sent: 10), "closed": TrafficBytes(received: 900, sent: 900)],
            total: TrafficBytes(received: 1000, sent: 910)
        )
        let now = ProcessNetwork(
            connections: ["a": TrafficBytes(received: 150, sent: 15), "new": TrafficBytes(received: 40, sent: 4)],
            total: TrafficBytes(received: 190, sent: 19)
        )
        // The closed connection's bytes leave nettop's total, which would read as a drop; per connection it adds 50 + 40.
        #expect(now.added(since: earlier) == TrafficBytes(received: 90, sent: 9))
        #expect(now.added(since: nil) == TrafficBytes(received: 190, sent: 19))
        let restarted = ProcessNetwork(connections: ["a": TrafficBytes(received: 5, sent: 1)], total: TrafficBytes(received: 5, sent: 1))
        #expect(restarted.added(since: earlier) == .zero)
    }
}
