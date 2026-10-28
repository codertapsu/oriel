import SwiftUI

// Translation is built in Swift 5 mode, so `TranslationSession` is not marked Sendable, and calling its nonisolated
// `prepareTranslation()` from the main-actor `translationTask` closure reads as sending it. The session SwiftUI hands
// in is used only inside that one task, so there is no concurrent access to diagnose.
@preconcurrency import Translation

/// Downloads an Apple Translation language pack with the user's consent (PLAN §7.7.3). Only SwiftUI's
/// `translationTask` with `prepareTranslation()` can trigger a download, and it shows the system's own prompt.
/// Used as a sheet in Settings and in a small window when a translation needs a pack.
struct LanguagePackDownloadView: View {
    private enum Phase: Equatable {
        case idle
        case downloading
        case failed(String)
    }

    /// Settings lets the user choose the pair; the translation flow fixes it.
    let allowsChoosingLanguages: Bool
    let onFinish: @MainActor (Bool) -> Void

    @State private var source: String
    @State private var target: String
    @State private var configuration: TranslationSession.Configuration?
    @State private var phase = Phase.idle

    init(source: String, target: String, allowsChoosingLanguages: Bool, onFinish: @escaping @MainActor (Bool) -> Void) {
        _source = State(initialValue: source)
        _target = State(initialValue: target)
        self.allowsChoosingLanguages = allowsChoosingLanguages
        self.onFinish = onFinish
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Download Language Pack", systemImage: "arrow.down.circle")
                .font(.headline)
            if allowsChoosingLanguages {
                HStack {
                    languagePicker("From", selection: $source)
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    languagePicker("To", selection: $target)
                }
            }
            Text(
                "Apple Translation needs the \(LanguageCatalog.name(of: source)) → \(LanguageCatalog.name(of: target)) language pack."
                    + " It downloads once, then translation works offline."
            )
            .fixedSize(horizontal: false, vertical: true)
            if case let .failed(message) = phase {
                Text(message).foregroundStyle(.red).font(.callout)
            }
            HStack {
                if phase == .downloading {
                    ProgressView().controlSize(.small)
                    Text("Downloading…").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Cancel") { onFinish(false) }
                    .keyboardShortcut(.cancelAction)
                Button("Download", action: download)
                    .keyboardShortcut(.defaultAction)
                    .disabled(phase == .downloading || source == target)
            }
        }
        .padding(20)
        .frame(width: 420)
        .translationTask(configuration) { session in
            do {
                try await session.prepareTranslation()
                phase = .idle
                onFinish(true)
            } catch {
                phase = .failed("The download didn't finish: \(error.localizedDescription)")
            }
        }
    }

    private func download() {
        phase = .downloading
        let wanted = TranslationSession.Configuration(
            source: Locale.Language(identifier: source),
            target: Locale.Language(identifier: target)
        )
        if configuration?.source == wanted.source, configuration?.target == wanted.target {
            configuration?.invalidate() // runs the task again for the same pair
        } else {
            configuration = wanted
        }
    }

    private func languagePicker(_ title: String, selection: Binding<String>) -> some View {
        Picker(title, selection: selection) {
            ForEach(LanguageCatalog.targets, id: \.self) { code in
                Text(LanguageCatalog.name(of: code)).tag(code)
            }
        }
        .labelsHidden()
    }
}
