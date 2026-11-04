# Changelog

## 1.2.0 — 2026-11-04

Updated both skills from Setapp-framework 5.3.6 to **5.5.5**, covering 5.4.0 through 5.5.5. Signatures were checked against the shipped `.swiftinterface` files, not just the release notes — 5.5.4 contains breaking changes the notes don't mention.

### Breaking changes now documented

- **v1 transcription and video endpoints are deprecated (5.5.4) and due for removal around 20 November 2026.** `setapp-ai` now teaches the v2 APIs (`transcribeV2` and siblings, `generateV2` / `retrieveV2` / `contentV2`) with migration notes. v2 video has no progress, expiry, thumbnail, or spritesheet.
- **`SetappError.ErrorCode` renumbering (5.4.0, iOS):** `.blocked` / `.blockedAfterTrial` → `.inactiveLicense` / `.trialAlreadyUsed`, 1708/1709 → 1710/1711. Numeric comparisons fail silently.
- **Integrity check rejects `com.apple.security.cs.disable-library-validation`** for non-Electron apps (5.5.4). Added to Step 8, the Step 14 compliance scan, and the Step 15 checklist.
- **Not in the release notes (5.5.4):** minimum macOS raised from 11.5 to **12.0**. `SetappManager` is no longer an `NSObject`, so KVO on `subscription` stops compiling; use `publisher(for: \.subscription)`, the delegate, or the notification instead. Objective-C moves to the deprecated `STPManager` shims.
- `LicenseValidationStatus` removed from `Setapp-Swift.h` (5.5.4).

### Added

- **Links API** (5.4.0): `ai.links.all()` and `ai.links.purchaseURL()`, plus `purchaseURL(clientID:returnURL:)` (5.5.1) to return the user to the app after buying credits.
- **Text-to-speech** (5.5.2): `ai.audio.voices(parameters:)` and streaming `ai.audio.speech(parameters:)`.
- **`Model.params`** (5.5.4): per-model supported durations, aspect ratios, resolutions, and so on, for building option UIs without hardcoding.
- **ElevenLabs transcription** and **streaming transcription** via the v2 audio API.
- **`requestPendingUpdate` / `applyPendingUpdate`** (5.5.0, macOS) for app-driven updates, and **`openWithAuth(url:)`** (5.4.0).
- The live-guidelines step now says to diff `.swiftinterface` files when a bump breaks the build, since release notes aren't exhaustive.

### Changed

- SPM pins and version tables bumped to 5.5.5.
- The video sample's poll loop is now bounded and cancellable in the code itself, and treats unknown statuses as terminal.
- Transcription samples select the model with `mode == .audioTranscription` instead of a hardcoded id.

## 1.1.0 — 2026-08-18

Audited both skills against Setapp-framework 5.3.6 and the current docs. Several items were wrong in ways that fail at submission or compile time.

### Fixed

- **Archive icon filename.** The skill said the standalone icon must be named `<AppName>.png`. Setapp's uploader accepts only **`AppIcon.png`** — the old instruction fails the upload.
- **Icon size.** Was "at least 512×512, 1024 recommended". The requirement is exactly **1024 × 1024**, with a 100px margin around an 824 × 824 design frame.
- **`set(errorPresenter:)` does not exist.** Setapp AI error handling is the `mode:` field on the configuration object (`.autoPresent` / `.propagate`), set in the same call as `authConfiguration`.
- **Dead review-guidelines URL.** `/docs/setapp-review-guidelines` 404s; the page is `/docs/review-guidelines`.
- **Dead model-list endpoint.** `vendor-api.setapp.com/resource/v1/ai/openai/supported-models` 404s — that proxy is deprecated. Replaced with `https://api.macpaw.com/ai/api/v1/model/info` and the [supported models](https://docs.setapp.com/docs/supported-ai-models) page.
- **Unverifiable rate limits.** The per-minute/per-day table and per-plan token caps appear in no current Setapp source. Removed, and replaced with the documented gateway error-code contract.
- **Step ordering.** `setapp-ai` printed Step 11 before Step 10.

### Added

- SDK version floors for every feature, and the **5.3.6 breaking change**: `requestAuthorizationCode` no longer takes a `scope` argument.
- **Credit balance caching (5.3.6)** — `balances()` is now cached; `balances(forceUpdate: true)` for a live read. A usage delta that ignores this reports zero forever.
- Coverage for SDK capabilities the skills omitted entirely: **image generation and editing** (5.1.0), **audio transcription** (5.2.0), **video generation** (5.3.0), plus structured outputs, function calling, and reasoning models.
- Model selection by `mode` and `capabilities` instead of substring-matching `id`.
- `SetappFramework-Resources.bundle` requirement for manual and Carthage installs from 5.0.0.
- Archive verification with `ditto -x -k`, and the `ASSETCATALOG_COMPILER_STANDALONE_ICON_BEHAVIOR = all` setting Xcode needs to export a 1024px icon.
- Bundle ID pattern for additional executables, required `Info.plist` keys, and the Fastlane/API automated upload paths.
- Where OAuth client credentials come from, and the rule that each app and platform needs its own client.
- `llms.txt` and the `.md` URL suffix, so the live-guidelines check can discover pages these skills don't know about.

## 1.0.0 — 2026-08-18

Initial publication of `setapp-framework` and `setapp-ai`, with plugin and marketplace manifests.
