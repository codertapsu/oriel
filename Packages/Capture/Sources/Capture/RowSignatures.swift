/// Each row of a grey frame reduced to `bins` column means: the row mean plus a coarse downsample (PLAN §7.3,
/// item 5). Prefix sums give the sums of any band of rows in constant time, so only the cross term of the
/// correlation needs a pass over the data.
nonisolated struct RowSignatures: Sendable {
    let rows: Int
    let bins: Int
    /// `rows × bins` values, row-major.
    let values: [Double]
    private let prefixSums: [Double]
    private let prefixSquares: [Double]

    init(_ gray: GrayFrame, bins requested: Int = 32) {
        let bins = max(1, min(requested, gray.usableWidth))
        var values = [Double](repeating: 0, count: gray.height * bins)
        var sums = [Double](repeating: 0, count: gray.height + 1)
        var squares = [Double](repeating: 0, count: gray.height + 1)
        let edges = (0 ... bins).map { $0 * gray.usableWidth / bins }
        gray.values.withUnsafeBufferPointer { source in
            for row in 0 ..< gray.height {
                var rowSum = 0.0
                var rowSquares = 0.0
                let base = row * gray.width
                for bin in 0 ..< bins {
                    var total = 0
                    for column in edges[bin] ..< edges[bin + 1] {
                        total += Int(source[base + column])
                    }
                    let mean = Double(total) / Double(max(edges[bin + 1] - edges[bin], 1))
                    values[row * bins + bin] = mean
                    rowSum += mean
                    rowSquares += mean * mean
                }
                sums[row + 1] = sums[row] + rowSum
                squares[row + 1] = squares[row] + rowSquares
            }
        }
        rows = gray.height
        self.bins = bins
        self.values = values
        prefixSums = sums
        prefixSquares = squares
    }

    func sum(rows range: Range<Int>) -> Double {
        prefixSums[range.upperBound] - prefixSums[range.lowerBound]
    }

    func sumOfSquares(rows range: Range<Int>) -> Double {
        prefixSquares[range.upperBound] - prefixSquares[range.lowerBound]
    }
}
