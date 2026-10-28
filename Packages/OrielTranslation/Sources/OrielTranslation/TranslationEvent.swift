/// What a provider's translation stream delivers: segments as they are ready, and usage once at the end.
public enum TranslationEvent: Sendable, Equatable {
    case segment(TranslatedSegment)
    /// What the request cost, for the per-provider usage counter and monthly cap.
    case usage(TranslationUsage)
}
