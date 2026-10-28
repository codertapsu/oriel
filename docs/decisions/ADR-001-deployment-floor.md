# ADR-001: Deployment floor

**Status:** Accepted · **Date:** 2026-10-28

**Context.** The requirement is to use the latest frameworks, with older versions supported only when free. macOS 27 runs on Apple silicon only; macOS 26 is the last release for Intel Macs. The dev machine runs macOS 27.

**Options.**

| Option | Intel | Framework access | Cost |
|---|---|---|---|
| A: floor 27.0, arm64 only | None | Everything, including anything 27-only | Simplest build; drops all Intel Macs |
| B: floor 26.0, Universal, 27 SDK | Yes (four Intel models) | Everything that matters; 27-only APIs behind `#available(macOS 27, *)` | Two build settings, one Rosetta smoke test, a few availability checks |
| C: floor 15 or 14 | More Intel models | Loses headless `TranslationSession`, Foundation Models, `RecognizeDocumentsRequest`, `NSGlassEffectView` | A second code path for several features |

**Decision: B.** Every framework the app leans on arrived by macOS 26: `NSGlassEffectView`, the headless `TranslationSession(installedSource:target:)` initializer, FoundationModels, `RecognizeDocumentsRequest`, the richer `SCScreenshotManager` configuration, plus `SCRecordingOutput` and ScreenCaptureKit microphone capture (15) and the Swift Vision API (15). The 27-specific changes known so far are toolchain-level: Swift 6.4, removal of the ld64 linker (`-ld_classic` no longer accepted), `ARCHS_STANDARD` dropping x86_64 for 27.0+ deployment targets, and apps losing direct access to the TCC database. A 27 floor would drop every Intel Mac for no API gain.

**Consequences.** Any 27-only API goes behind `#available(macOS 27, *)` with the 26 behaviour as the fallback. If the Phase 0 SDK audit (Appendix E) finds a 27-only API that is worth more than Intel support, raise `deploymentTarget` to 27.0 and drop `x86_64`; that is a two-line change in `project.yml` plus removing the Rosetta job. Intel verification is Rosetta-only unless a physical Intel Mac is available.
