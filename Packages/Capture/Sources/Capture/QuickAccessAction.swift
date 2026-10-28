/// What the Quick Access Overlay offers for a capture (PLAN §7.2, item 6).
nonisolated enum QuickAccessAction: CaseIterable, Sendable, Equatable {
    case copy
    case save
    case annotate
    case translate
    case pin
    case upload
    case copyText
    case close

    var symbol: String {
        switch self {
        case .copy: "doc.on.doc"
        case .save: "square.and.arrow.down"
        case .annotate: "pencil.tip.crop.circle"
        case .translate: "translate"
        case .pin: "pin"
        case .upload: "icloud.and.arrow.up"
        case .copyText: "text.viewfinder"
        case .close: "xmark.circle.fill"
        }
    }

    var label: String {
        switch self {
        case .copy: "Copy"
        case .save: "Save"
        case .annotate: "Annotate"
        case .translate: "Translate"
        case .pin: "Pin to Screen"
        case .upload: "Upload"
        case .copyText: "Copy Text"
        case .close: "Close"
        }
    }

    /// Whether the card goes away afterwards: it does once the capture has gone somewhere else.
    var dismissesCard: Bool {
        switch self {
        case .copy, .save, .copyText: false
        case .annotate, .translate, .pin, .upload, .close: true
        }
    }
}
