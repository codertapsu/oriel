import Foundation

/// Reads one run of `nettop -L 1 -n -x -t external -J bytes_in,bytes_out`: a header, then for each process with
/// traffic a line `name.pid,in,out,` followed by one line per connection, `tcp4 local<->remote,in,out,`.
///
/// nettop writes plain CSV without quoting, and a process name may hold dots, commas or spaces, so the counts are taken
/// from the right and the pid from after the last dot. The columns are found by the header's names, because nettop
/// orders them its own way whatever `-J` asks.
nonisolated enum NettopParser {
    /// One sample, no name lookups, exact numbers, without loopback traffic.
    static let arguments = ["-L", "1", "-n", "-x", "-t", "external", "-J", "bytes_in,bytes_out"]

    static func parse(_ text: String) -> [Int32: ProcessNetwork] {
        var columns = ["bytes_in", "bytes_out"]
        var processes: [Int32: ProcessNetwork] = [:]
        var current: Int32?
        for line in text.split(whereSeparator: \.isNewline) {
            var fields = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            if fields.last?.isEmpty == true {
                fields.removeLast()
            }
            if fields.first?.isEmpty == true {
                columns = Array(fields.dropFirst())
                continue
            }
            let hasCounts = fields.count > columns.count
            let label = hasCounts ? fields.dropLast(columns.count).joined(separator: ",") : fields.joined(separator: ",")
            let traffic = hasCounts ? traffic(in: fields.suffix(columns.count), columns: columns) : nil
            if label.contains("<->") {
                guard let pid = current, let traffic else { continue }
                processes[pid, default: ProcessNetwork()].connections[uniqueKey(label, in: processes[pid])] = traffic
            } else if let traffic, let pid = pid(of: label) {
                current = pid
                processes[pid, default: ProcessNetwork()].total = traffic
            } else {
                // A process line that cannot be read: its connections must not land on the process before it.
                current = nil
            }
        }
        return processes
    }

    /// The pid after the last dot of `name.pid`.
    static func pid(of label: String) -> Int32? {
        guard let dot = label.lastIndex(of: "."), let pid = Int32(label[label.index(after: dot)...]), pid >= 0 else { return nil }
        return pid
    }

    private static func traffic(in values: ArraySlice<String>, columns: [String]) -> TrafficBytes? {
        var counts: [String: UInt64] = [:]
        for (name, value) in zip(columns, values) {
            guard let number = UInt64(value.trimmingCharacters(in: .whitespaces)) else { return nil }
            counts[name] = number
        }
        guard let received = counts["bytes_in"], let sent = counts["bytes_out"] else { return nil }
        return TrafficBytes(received: received, sent: sent)
    }

    /// Two sockets can share a description (two listeners on `*:5353`): the later ones get `#2`, `#3`…
    private static func uniqueKey(_ label: String, in process: ProcessNetwork?) -> String {
        guard let connections = process?.connections, connections[label] != nil else { return label }
        var number = 2
        while connections["\(label)#\(number)"] != nil {
            number += 1
        }
        return "\(label)#\(number)"
    }
}
