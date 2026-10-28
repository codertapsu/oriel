/// Splits segments into requests that respect a provider's limits: at most `maxCount` segments and `maxCost` cost
/// (characters, estimated tokens) each. A segment that alone exceeds `maxCost` gets a batch of its own, because a
/// segment is never split.
enum SegmentBatcher {
    static func batches(
        _ segments: [TranslationSegment],
        maxCount: Int,
        maxCost: Int,
        cost: (TranslationSegment) -> Int = { $0.text.count }
    ) -> [[TranslationSegment]] {
        var batches: [[TranslationSegment]] = []
        var current: [TranslationSegment] = []
        var currentCost = 0
        for segment in segments {
            let segmentCost = cost(segment)
            if !current.isEmpty, current.count >= maxCount || currentCost + segmentCost > maxCost {
                batches.append(current)
                current = []
                currentCost = 0
            }
            current.append(segment)
            currentCost += segmentCost
        }
        if !current.isEmpty {
            batches.append(current)
        }
        return batches
    }

    /// A deliberately high token estimate for on-device models: about 3.5 Latin characters per token, one token per
    /// character for everything else (CJK is close to that), plus the JSON around each segment.
    static func estimatedTokens(_ segment: TranslationSegment) -> Int {
        var ascii = 0
        var other = 0
        for scalar in segment.text.unicodeScalars {
            if scalar.isASCII {
                ascii += 1
            } else {
                other += 1
            }
        }
        return ascii * 2 / 7 + other + 8
    }
}
