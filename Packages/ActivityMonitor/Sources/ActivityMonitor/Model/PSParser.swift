import Foundation

/// Reads `/bin/ps -o pid=,time=,rss=,state= -p <pids>`: the CPU time, resident memory and state of other users'
/// processes, which only the setuid `ps` can see. Without a command column no field holds spaces, so splitting on
/// whitespace is exact. It works on the bytes: a few hundred lines parse in a few dozen microseconds.
nonisolated enum PSParser {
    struct Record: Sendable, Equatable {
        /// Nanoseconds of user plus system time, to `ps`'s hundredth of a second.
        let cpuTime: UInt64
        let residentSize: UInt64
        let status: ProcessStatus?
    }

    /// The `-o` argument the parser expects.
    static let columns = "pid=,time=,rss=,state="

    static func parse(_ text: String) -> [Int32: Record] {
        parse(Data(text.utf8))
    }

    static func parse(_ data: Data) -> [Int32: Record] {
        var records: [Int32: Record] = [:]
        data.withUnsafeBytes { raw in
            let bytes = raw.bindMemory(to: UInt8.self)
            var fields: [Range<Int>] = []
            fields.reserveCapacity(5)
            var start = 0
            while start < bytes.count {
                var end = start
                while end < bytes.count, bytes[end] != 0x0A {
                    end += 1
                }
                fields.removeAll(keepingCapacity: true)
                var index = start
                while index < end, fields.count < 5 {
                    while index < end, bytes[index] == 0x20 || bytes[index] == 0x09 {
                        index += 1
                    }
                    let fieldStart = index
                    while index < end, bytes[index] != 0x20, bytes[index] != 0x09 {
                        index += 1
                    }
                    if index > fieldStart {
                        fields.append(fieldStart ..< index)
                    }
                }
                if let (pid, record) = record(fields, in: bytes) {
                    records[pid] = record
                }
                start = end + 1
            }
        }
        return records
    }

    private static func record(_ fields: [Range<Int>], in bytes: UnsafeBufferPointer<UInt8>) -> (Int32, Record)? {
        guard fields.count >= 3,
              let pid = number(bytes, fields[0]).flatMap({ Int32(exactly: $0) }), pid > 0,
              let time = cpuTime(bytes, fields[1]),
              let kilobytes = number(bytes, fields[2])
        else { return nil }
        let status = fields.count > 3 ? ProcessStatus(psState: Substring(UnicodeScalar(bytes[fields[3].lowerBound]).description)) : nil
        return (pid, Record(cpuTime: time, residentSize: kilobytes &* 1024, status: status))
    }

    /// A field of decimal digits; nil when empty or when anything else is in it.
    private static func number(_ bytes: UnsafeBufferPointer<UInt8>, _ range: Range<Int>) -> UInt64? {
        guard !range.isEmpty else { return nil }
        var value: UInt64 = 0
        for index in range {
            let byte = bytes[index]
            guard byte >= 0x30, byte <= 0x39 else { return nil }
            let (product, overflow) = value.multipliedReportingOverflow(by: 10)
            guard !overflow else { return nil }
            value = product + UInt64(byte - 0x30)
        }
        return value
    }

    /// `ps`'s `time`: `M:SS.hh` with minutes past 59 (`125:03.27`), `H:MM:SS.hh`, or with days, `D-HH:MM:SS.hh`. The
    /// decimal point is the locale's, so a comma is accepted too. Nanoseconds.
    static func cpuTime(_ text: Substring) -> UInt64? {
        let bytes = Array(text.utf8)
        return bytes.withUnsafeBufferPointer { cpuTime($0, 0 ..< $0.count) }
    }

    static func cpuTime(_ bytes: UnsafeBufferPointer<UInt8>, _ range: Range<Int>) -> UInt64? {
        var start = range.lowerBound
        var days: UInt64 = 0
        if let dash = range.first(where: { bytes[$0] == 0x2D }) {
            guard let value = number(bytes, start ..< dash) else { return nil }
            days = value
            start = dash + 1
        }
        // Whole minutes, or hours and minutes, before the seconds.
        var seconds: UInt64 = 0
        var parts = 0
        var partStart = start
        for index in start ..< range.upperBound where bytes[index] == 0x3A {
            guard parts < 2, let value = number(bytes, partStart ..< index) else { return nil }
            seconds = seconds * 60 + value
            parts += 1
            partStart = index + 1
        }
        let last = partStart ..< range.upperBound
        let point = last.first { bytes[$0] == 0x2E || bytes[$0] == 0x2C } ?? last.upperBound
        guard let whole = number(bytes, last.lowerBound ..< point) else { return nil }
        var fraction: UInt64 = 0
        if point < last.upperBound {
            let digits = point + 1 ..< min(last.upperBound, point + 10)
            guard last.upperBound - point - 1 <= 9 else { return nil }
            if !digits.isEmpty {
                guard let value = number(bytes, digits) else { return nil }
                fraction = value
                for _ in digits.count ..< 9 {
                    fraction *= 10
                }
            }
        }
        seconds = seconds * 60 + whole
        return (days * 86400 + seconds) * 1_000_000_000 + fraction
    }
}
