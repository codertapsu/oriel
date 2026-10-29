import Foundation

/// What the file translation window can ask the coordinator to do.
struct FileTranslationActions {
    var chooseFile: @MainActor () -> Void
    var openFiles: @MainActor ([URL]) -> Void
    var selectProvider: @MainActor (ProviderID) -> Void
    var selectTarget: @MainActor (String) -> Void
    var selectGlossary: @MainActor (UUID?) -> Void
    var stop: @MainActor () -> Void
    /// Resume after a stop or failure, or translate everything again once finished.
    var translateAgain: @MainActor () -> Void
    var copyAll: @MainActor () -> Void
    var copyImage: @MainActor () -> Void
    var copy: @MainActor (String) -> Void
    var export: @MainActor (DocumentExportFormat) -> Void
}
