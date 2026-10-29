import CoreGraphics
import Foundation
import Observation

/// The smart tools of one editor window (PLAN §17): Smart Redact, Simplify and Smart Move. Each looks at the image
/// when its panel opens, shows what it found (outlined on the canvas, by category with counts and switches), and
/// changes the document only when the user applies, in one undo step.
@Observable
final class SmartTools {
    let session: EditorSession
    @ObservationIgnored let analyzer: SmartAnalyzer

    // Smart Redact
    var isRedactPresented = false
    private(set) var redactPhase = SmartPhase.idle
    private(set) var redactions: [RedactionFinding] = []
    var redactCategories = RedactionCategory.defaultSelection {
        didSet { updatePreview() }
    }

    var redactEffect = RedactionEffect.blur

    // Simplify
    private(set) var simplifyPhase = SmartPhase.idle
    private(set) var simplifyPlan = SimplifyPlan.empty
    var tonesDown = true
    var toneAmount = 0.55

    // Smart Move
    private(set) var movePhase = SmartPhase.idle
    private(set) var movableObjects: [MovableObject] = []
    private(set) var objectsUnavailable = false
    var moveSources: Set<ImageLayer.Source> = [.text, .object, .region] {
        didSet { updatePreview() }
    }

    /// Which review the canvas outlines.
    private(set) var reviewing: Review?
    @ObservationIgnored private var task: Task<Void, Never>?

    enum Review: Sendable {
        case redact, simplify, move
    }

    init(session: EditorSession, analyzer: SmartAnalyzer) {
        self.session = session
        self.analyzer = analyzer
    }

    var canReadText: Bool {
        analyzer.canReadText
    }

    // MARK: - Smart Redact

    /// Reads the image and lists what could be hidden.
    func findRedactions() {
        begin(.redact)
        redactPhase = .working
        let base = session.document.base, visible = session.document.visibleImageRect
        task = Task { [weak self, analyzer] in
            do {
                let found = try await analyzer.redactions(in: base, visible: visible)
                guard !Task.isCancelled, let self else { return }
                redactions = found
                redactPhase = .ready
                updatePreview()
            } catch is CancellationError {
                return
            } catch {
                // A review that was cancelled (its panel closed, or it started again) has nothing to say.
                guard !Task.isCancelled else { return }
                self?.redactPhase = .failed(Self.message(for: error))
            }
        }
    }

    /// How many finds each category has.
    var redactionCounts: [RedactionCategory: Int] {
        RedactionPlanner.counts(redactions)
    }

    /// The regions Apply would add.
    var plannedRedactions: [AnnotationItem] {
        RedactionPlanner.regions(for: redactions, categories: redactCategories, effect: redactEffect, in: session.document.visibleImageRect)
    }

    func applyRedactions() {
        session.applyRedaction(plannedRedactions)
        endReview(.redact)
        isRedactPresented = false
    }

    // MARK: - Simplify

    func findSimplification() {
        begin(.simplify)
        simplifyPhase = .working
        let base = session.document.base, visible = session.document.visibleImageRect
        task = Task { [weak self, analyzer] in
            do {
                let plan = try await analyzer.simplification(in: base, visible: visible)
                guard !Task.isCancelled, let self else { return }
                simplifyPlan = plan
                simplifyPhase = .ready
                updatePreview()
            } catch is CancellationError {
                return
            } catch {
                // A review that was cancelled (its panel closed, or it started again) has nothing to say.
                guard !Task.isCancelled else { return }
                self?.simplifyPhase = .failed(Self.message(for: error))
            }
        }
    }

    func applySimplification() {
        // In steps of 5 %, as the panel shows it.
        session.applySimplify(simplifyPlan, tone: tonesDown ? (toneAmount * 20).rounded() / 20 : nil)
        endReview(.simplify)
    }

    // MARK: - Smart Move

    func findMovableObjects() {
        begin(.move)
        movePhase = .working
        let base = session.document.base, visible = session.document.visibleImageRect
        task = Task { [weak self, analyzer] in
            do {
                let found = try await analyzer.movableObjects(in: base, visible: visible)
                guard !Task.isCancelled, let self else { return }
                movableObjects = found.objects
                objectsUnavailable = found.objectsUnavailable
                movePhase = .ready
                updatePreview()
            } catch is CancellationError {
                return
            } catch {
                // A review that was cancelled (its panel closed, or it started again) has nothing to say.
                guard !Task.isCancelled else { return }
                self?.movePhase = .failed(Self.message(for: error))
            }
        }
    }

    func count(of source: ImageLayer.Source) -> Int {
        movableObjects.count { $0.source == source }
    }

    /// The objects Apply would lift.
    var plannedObjects: [MovableObject] {
        movableObjects.filter { moveSources.contains($0.source) }
    }

    func applySmartMove() {
        session.applySmartMove(plannedObjects)
        endReview(.move)
    }

    // MARK: - Review

    /// A review panel closed: its outlines go and its work still running stops. Nil ends whichever review is on;
    /// a review that is not the current one (its panel closed after another opened) changes nothing.
    func endReview(_ review: Review? = nil) {
        if let review, review != reviewing {
            return
        }
        task?.cancel()
        task = nil
        reviewing = nil
        session.showSmartPreview([])
    }

    private func begin(_ review: Review) {
        task?.cancel()
        reviewing = review
        session.showSmartPreview([])
    }

    private func updatePreview() {
        let boxes: [SmartPreviewBox] = switch reviewing {
        case .redact:
            redactions.map { SmartPreviewBox(rect: $0.rect, isIncluded: redactCategories.contains($0.category)) }
        case .simplify:
            simplifyPlan.bars.map { SmartPreviewBox(rect: $0.rect, isIncluded: true) }
        case .move:
            movableObjects.map { SmartPreviewBox(rect: $0.layer.rect, isIncluded: moveSources.contains($0.source)) }
        case nil:
            []
        }
        session.showSmartPreview(boxes)
    }

    private static func message(for error: any Error) -> String {
        if case SmartAnalyzer.Failure.noTextRecognition = error {
            return "Text recognition isn’t available."
        }
        return "The image couldn’t be read: \(error.localizedDescription)"
    }
}
