import CoreGraphics

/// Decides what Translate Under Cursor does next (PLAN §17), as a pure state machine over the pointer's movements and
/// the results of reading and translating; the controller carries out its effects. Time comes in as instants, so
/// tests run it on a clock of their own.
///
/// - The pointer is at rest once it has not moved for `restDelay`. Each movement moves that moment on; the machine
///   asks for one wake-up at a time and, woken early, asks for another (one-shot delays, never a timer).
/// - At rest, the screen under the pointer is read. Moving again before the result abandons the read.
/// - A text is translated once: results are cached by text and context (provider, language, glossary), and a text
///   already on its way to the provider is not sent again.
/// - The tooltip stays while the pointer moves within the text it translates, and when the pointer trembles by
///   less than `jitter` points; it goes when the pointer leaves, the page scrolls or something is clicked or typed.
///   A scroll reads the same spot again; a click or a key waits for the pointer to move.
struct CursorRestMachine {
    struct Configuration: Equatable, Sendable {
        var restDelay: Duration = .milliseconds(400)
        /// Movements smaller than this, from where the screen was last read, are not movements.
        var jitter: CGFloat = 3
        /// How far outside the translated text the pointer may wander before the tooltip goes.
        var keepMargin: CGFloat = 10
        var cacheLimit = 64
    }

    enum Effect: Equatable, Sendable {
        /// Call `wake(at:)` at this moment.
        case scheduleWake(at: ContinuousClock.Instant)
        case hideTooltip
        /// Abandon the read in progress (a translation already sent still finishes, into the cache).
        case cancelRead
        /// Read the screen under `point`; report with `recognized(_:job:context:)`.
        case read(job: Int, point: CGPoint)
        /// Translate `text`; report with `translated(_:key:)` or `translationFailed(_:key:)`.
        case translate(key: String, text: String)
        case showPending(region: CGRect, point: CGPoint)
        case show(CursorTranslation, region: CGRect, point: CGPoint)
        case showFailure(String, region: CGRect, point: CGPoint)
    }

    private struct Pending {
        let job: Int
        var key: String?
        var region: CGRect?
        let point: CGPoint
    }

    let configuration: Configuration
    private(set) var pointer = CGPoint.zero
    private(set) var job = 0
    private var lastActivity: ContinuousClock.Instant?
    private var wake: ContinuousClock.Instant?
    /// Where the screen was last read.
    private var restPoint: CGPoint?
    /// The text the tooltip is about, showing a translation, a failure or the wait for one.
    private var shownRegion: CGRect?
    private var pending: Pending?
    private var inFlight = Set<String>()
    private var cache: CursorCache

    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        cache = CursorCache(limit: configuration.cacheLimit)
    }

    /// The cache key of a text in a context.
    static func key(_ text: String, context: String) -> String {
        "\(context)\u{1}\(text)"
    }

    // MARK: - Inputs

    mutating func pointerMoved(to point: CGPoint, at now: ContinuousClock.Instant) -> [Effect] {
        pointer = point
        if let shownRegion, shownRegion.insetBy(dx: -configuration.keepMargin, dy: -configuration.keepMargin).contains(point) {
            return []
        }
        if let restPoint, hypot(point.x - restPoint.x, point.y - restPoint.y) < configuration.jitter {
            return []
        }
        return becameActive(at: now)
    }

    /// The content moved under a still pointer (a scroll): the same spot is read again once things settle.
    mutating func contentChanged(at now: ContinuousClock.Instant) -> [Effect] {
        becameActive(at: now)
    }

    /// A click or a key press: the user is doing something rather than reading. The tooltip goes and nothing is read
    /// until the pointer moves on, so typing never brings the same tooltip back.
    mutating func dismissed() -> [Effect] {
        var effects: [Effect] = []
        if shownRegion != nil || pending != nil {
            effects.append(.hideTooltip)
            shownRegion = nil
        }
        if pending != nil {
            pending = nil
            job += 1
            effects.append(.cancelRead)
        }
        restPoint = pointer
        lastActivity = nil
        return effects
    }

    /// The moment asked for in `.scheduleWake` has come.
    mutating func wake(at now: ContinuousClock.Instant) -> [Effect] {
        wake = nil
        guard let lastActivity else { return [] }
        let deadline = lastActivity + configuration.restDelay
        guard now >= deadline else {
            wake = deadline
            return [.scheduleWake(at: deadline)]
        }
        self.lastActivity = nil
        job += 1
        restPoint = pointer
        pending = Pending(job: job, key: nil, region: nil, point: pointer)
        return [.read(job: job, point: pointer)]
    }

    /// What the read found under the pointer; nil for nothing.
    mutating func recognized(_ recognition: CursorRecognition?, job: Int, context: String) -> [Effect] {
        guard var pending, pending.job == job, pending.key == nil else { return [] }
        guard let recognition, !recognition.text.isEmpty else {
            self.pending = nil
            return [.hideTooltip]
        }
        let key = Self.key(recognition.text, context: context)
        if let cached = cache.use(key) {
            self.pending = nil
            shownRegion = recognition.region
            return [.show(cached, region: recognition.region, point: pending.point)]
        }
        pending.key = key
        pending.region = recognition.region
        self.pending = pending
        shownRegion = recognition.region
        var effects: [Effect] = [.showPending(region: recognition.region, point: pending.point)]
        if inFlight.insert(key).inserted {
            effects.append(.translate(key: key, text: recognition.text))
        }
        return effects
    }

    /// Reading the screen failed; the tooltip says why.
    mutating func readFailed(_ message: String, job: Int) -> [Effect] {
        guard let pending, pending.job == job, pending.key == nil else { return [] }
        self.pending = nil
        let region = CGRect(origin: pending.point, size: .zero)
        shownRegion = region
        return [.showFailure(message, region: region, point: pending.point)]
    }

    mutating func translated(_ result: CursorTranslation, key: String) -> [Effect] {
        inFlight.remove(key)
        cache[key] = result
        guard let pending, pending.key == key, let region = pending.region else { return [] }
        self.pending = nil
        return [.show(result, region: region, point: pending.point)]
    }

    mutating func translationFailed(_ message: String, key: String) -> [Effect] {
        inFlight.remove(key)
        guard let pending, pending.key == key, let region = pending.region else { return [] }
        self.pending = nil
        return [.showFailure(message, region: region, point: pending.point)]
    }

    /// Whether `text` in `context` is cached, for tests and diagnostics.
    func isCached(_ text: String, context: String) -> Bool {
        cache[Self.key(text, context: context)] != nil
    }

    // MARK: - Moving on

    /// The pointer moved for real, or the content changed: the tooltip goes, a read in progress is abandoned, and
    /// the wait for rest starts again.
    private mutating func becameActive(at now: ContinuousClock.Instant) -> [Effect] {
        var effects: [Effect] = []
        if shownRegion != nil || pending != nil {
            effects.append(.hideTooltip)
            shownRegion = nil
        }
        if pending != nil {
            pending = nil
            job += 1
            effects.append(.cancelRead)
        }
        restPoint = nil
        lastActivity = now
        if wake == nil {
            let deadline = now + configuration.restDelay
            wake = deadline
            effects.append(.scheduleWake(at: deadline))
        }
        return effects
    }
}
