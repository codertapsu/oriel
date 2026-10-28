# S8 — macOS 27 SDK audit

2026-10-28 · Xcode 27.1 (27A9275), macOS SDK 27.0, on macOS 27.0.1 (26A434) · **Result: works. The floor stays at macOS 26.0.**

Method: the Appendix E greps over the Objective-C headers and the arm64e `.swiftinterface` files, plus one type-check probe (`swiftc -typecheck -target arm64-apple-macos26.0`). The Carbon headers are ISO-8859-1, and grep in a UTF-8 locale silently skips them, so search them with `LC_ALL=C grep -a`.

## Names the plan could not verify (Appendix F, items 1 and 2)

| Plan | SDK | Available from |
|---|---|---|
| The "macOS 26 screenshot configuration" (§7.2, item 7) | `SCScreenshotConfiguration` (`width`, `height`, `showsCursor`, `ignoreShadows`, `includeChildWindows`, `displayIntent`, `dynamicRange`, `contentType`, `fileURL`) and `SCScreenshotOutput`, used by `+[SCScreenshotManager captureScreenshotWithFilter:configuration:completionHandler:]` and `captureScreenshotWithRect:configuration:completionHandler:`. HDR HEIC means `dynamicRange` plus `contentType`. | 26.0 |
| The Translation "preferred strategy" (§7.7.2) | `TranslationSession.Strategy` (`.highFidelity`, `.lowLatency`), `preferredStrategy`, and `TranslationSession(installedSource:target:preferredStrategy:)` | 26.4 |
| `TranslationSession(installedSource:target:)` (§7.7.3) | As named | 26.0 |
| `RecognizeDocumentsRequest`, `RecognizeTextRequest` (§7.6) | As named | 26.0, 15.0 |
| `captureMicrophone`, `microphoneCaptureDeviceID` (§7.4) | As named, on `SCStreamConfiguration` | 15.0 |
| `SCRecordingOutput` (§7.4) | As named | 15.0 |
| `NSGlassEffectView` (§7.1.10, §10.2) | `NSGlassEffectView` (`style`, `tintColor`, `cornerRadius`, `contentView`) and `NSGlassEffectContainerView` | 26.0 |
| A FoundationModels API for third-party or remote providers (Appendix F, item 2) | It exists: the `LanguageModel` and `LanguageModelExecutor` protocols, `LanguageModelCapabilities`, and `LanguageModelSession(model: some LanguageModel, …)`. `SystemLanguageModel` conforms to `LanguageModel`. | 27.0 |

## Adopt now, behind `#available(macOS 27, *)`

- **`SCRecordingOutputConfiguration.mixesAudioWithMicrophone`** (§7.4, S9). The header says that setting it to `NO` keeps system audio and the microphone as two tracks. That implies they are mixed into one track by default, and on macOS 26, where the property does not exist. S9's gate ("both audio tracks") has to check the track count on 26 and on 27. On 27, set it to `false`.
- **`SCStreamErrorInsufficientStorage`**: map it to a "disk full" message in Recording.
- **`NSGlassEffectView.effectIsInteractive`**: press and hover feedback on the glass chrome (switcher, toolbars). Cosmetic, so it needs no fallback.
- **`SCStream.isCapturing`**: read the capture state from the stream on 27, and track it ourselves on 26.

## Adopt if the floor moves to 27

- **FoundationModels custom models.** An OpenAI-compatible, Anthropic or local backend could be wrapped as a `LanguageModel` and driven through `LanguageModelSession`, with guided generation (`@Generable`) replacing the segment-JSON parsing of §7.7.4. That is not worth a 27 floor. Apple Translation, Google and DeepL do not fit the protocol, so the plan's `TranslationProvider` layer stays either way, and the JSON contract already works on 26.
- **`SCRecordingEditor`**: a system editor sheet for a finished recording (`init(url:)`, presented from a window, with a delegate for dismissal and failure). It could replace `AVPlayerView` trimming (§7.4), but with a 26 floor we would have to maintain both.

## Ignore for 1.0

- **`SCClipBufferingOutput`** keeps a rolling buffer and exports the last N seconds (`exportClipToURL:duration:`). It would make a good "save the last 30 seconds" feature after 1.0 (§17).
- **`NSStatusItem.expandedInterfaceDelegate` and `NSStatusItemExpandedInterfaceSession`**: the headers carry no documentation. Look again when Phase 1 builds the status menu.
- `SCContentFilter.isMicrophoneEnabled` (it reports the system picker's microphone toggle, and Oriel does not use the picker), `SCContentSharingPicker.isAvailable`, `SCStreamFrameInfo.videoOrientation`, `SCStreamErrorNotSupported`, `NSMenuItem.preferredImageVisibility`, `NSScreen.touchCapabilities`, and AppKit's Writing Tools and text-system additions.
- Vision's additions (`GenerateIterativeSegmentationRequest`, `DownloadableAssetsRequest`, new animal identifiers) contain nothing for text or document recognition. Translation has no macOS 27 additions.

## Deprecations

- **`AVAssetExportSession`'s callback API** (`exportAsynchronously(completionHandler:)`, `status`, `progress`, `cancelExport()`) is deprecated in 27, in favour of `export(to:as:)`, `states(updateInterval:)` and task cancellation. Both replacements type-check at the 26.0 deployment target (they need macOS 15), so Recording uses them from the start, with no `#available`.
- Nothing else the plan relies on is deprecated. I checked `CGWindowListCopyWindowInfo`, `CGEventTapCreate`, `CGEventCreateScrollWheelEvent2`, `CGPreflightScreenCaptureAccess`, `AXObserverCreate`, `AXObserverAddNotification`, `AXUIElementSetMessagingTimeout`, and Carbon's `RegisterEventHotKey`, `UnregisterEventHotKey`, `InstallEventHandler` and `GetEventDispatcherTarget`. ScreenCaptureKit, CoreGraphics, ApplicationServices, Carbon, ServiceManagement and Vision carry no 27 deprecations at all. AppKit's only one, `NSPanGestureRecognizer.numberOfTouchesRequired`, is unused.
- `_AXUIElementGetWindow` and the SkyLight symbols are not in the SDK, as expected. They stay `dlsym` lookups (S1, S2, S4).

## Recommendation

Keep the 26.0 floor and the Universal build; ADR-001 stands. Apply the "adopt now" items when their phases arrive (Recording in Phase 7, the switcher's glass in Phases 2–3), and write Recording against the async export API. Rerun this audit whenever Xcode ships a newer SDK.
