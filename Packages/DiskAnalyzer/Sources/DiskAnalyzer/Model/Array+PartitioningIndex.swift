nonisolated extension Array {
    /// The first index whose element satisfies `belongs`, for an array partitioned so that every element that does
    /// comes after every one that does not.
    func partitioningIndex(where belongs: (Element) -> Bool) -> Int {
        var low = 0
        var high = count
        while low < high {
            let middle = (low + high) / 2
            if belongs(self[middle]) {
                high = middle
            } else {
                low = middle + 1
            }
        }
        return low
    }
}
