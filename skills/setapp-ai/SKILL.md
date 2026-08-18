---
name: setapp-ai
description: Use when adding Setapp AI+ capabilities to a macOS or iOS app. Triggers on mentions of "Setapp AI", "SetappAI", "AI+", "Setapp AI integration", the Setapp AI Swift SDK, or adding AI features through Setapp — text streaming, model discovery, conversation context, structured output, function calling, image generation and editing, audio transcription, video generation, or AI credit balances. Requires the Setapp Framework to be integrated first (use setapp-framework skill if not done).
---

# Setapp AI+ Integration

## Overview

Add AI capabilities to your app through Setapp's unified AI platform. Setapp routes requests to multiple AI providers (OpenAI, Anthropic, Google Gemini) — no per-user API keys needed. Users get AI access through their Setapp subscription, and Setapp handles credit metering and billing.

The Swift SDK covers: model discovery, text streaming, multi-turn conversation context, structured outputs, function calling, reasoning models, image generation and editing, audio transcription, video generation, and credit balances. Every model declares what it supports via `mode` and `capabilities` — check those before calling.

> **macOS and iOS use this SDK. Web apps and browser extensions do not** — they call the [AI Gateway](https://docs.setapp.com/docs/ai-gateway) HTTP API directly (OpenAI-compatible, `https://api.macpaw.com/ai`), or the [TypeScript SDK](https://docs.setapp.com/docs/typescript-sdk).

## Prerequisites

The Setapp Framework must be integrated first. Check for:

```
Search for: "import Setapp", "Setapp-framework" in Package.resolved, and "com.setapp.ProvisioningService" in entitlements
```

If not found, tell the user: **"The Setapp Framework isn't integrated yet. Use the `setapp-framework` skill first."**

> **Note:** On macOS, do NOT search for `SetappManager.shared.start` — that method doesn't exist on macOS v5.1.0+. The framework auto-initializes. Its absence does NOT mean the framework isn't integrated.

**Check the pinned version too.** Much of this skill needs a floor newer than 5.1.0:

| Feature | Minimum |
|---|---|
| Text streaming, models, image generation & editing | 5.1.0 |
| Audio transcription | 5.2.0 |
| Video generation | 5.3.0 |
| `Images.Edit.Parameters` public initializer | 5.3.1 |
| Credit balances (`ai.credits`) | 5.3.3 |
| Cached balances / `balances(forceUpdate:)` | 5.3.6 |

Latest is **5.3.6** (2026-08-14). If `Package.resolved` pins something older, bump it before writing against these APIs — the failure mode is a "no member" compile error that reads like a typo.

## Checklist

### Step 1: Detect Current State

Search the codebase:

```
Search for: "import SetappAI", "SetappManager.shared.ai", "AuthConfiguration"
```

Skip steps that are already done.

### Step 2: Import SetappAI

SetappAI is a **separate module** from Setapp. You need BOTH imports:

```swift
import Setapp    // Core framework — SetappManager
import SetappAI  // AI types — SetappAIAPI.Model, AuthConfiguration, etc.
```

> **Common error:** If you only `import Setapp`, you'll get errors like "cannot find type 'AuthConfiguration'" or "value of type has no member 'ai'". The AI types live in the `SetappAI` module.

### Step 3: Configure OAuth

Get the app's `OAuth Client ID` and `OAuth Client Secret` from the developer account: **Apps > OAuth Clients > Add new**, select the app, enter permitted redirect URLs, then View to copy the values. Create a **separate OAuth client per app and per platform** — sharing one across apps breaks Setapp's usage attribution and payout calculation. See https://docs.setapp.com/docs/oauth-clients.

OAuth credentials should be stored securely, not hardcoded. The recommended pattern is:

1. Create a gitignored `.xcconfig` file with the credentials:

```
// SetappAI.xcconfig (add to .gitignore!)
SETAPP_AI_OAUTH_CLIENT_ID = your_client_id_here
SETAPP_AI_OAUTH_SECRET = your_secret_here
```

2. Reference them as build variables in `Info-Setapp.plist`:

```xml
<key>SetappAIOAuthClientID</key>
<string>$(SETAPP_AI_OAUTH_CLIENT_ID)</string>
<key>SetappAIOAuthSecret</key>
<string>$(SETAPP_AI_OAUTH_SECRET)</string>
```

3. Read them at runtime from the bundle:

```swift
private func configureAuth() {
    let clientId = Bundle.main.object(forInfoDictionaryKey: "SetappAIOAuthClientID") as? String ?? ""
    let secret = Bundle.main.object(forInfoDictionaryKey: "SetappAIOAuthSecret") as? String ?? ""
    guard !clientId.isEmpty, !secret.isEmpty else { return }
    SetappManager.shared.ai.set(configuration: .init(
        authConfiguration: AuthConfiguration(
            oauthClientId: clientId,
            oauthSecret: secret
        )
    ))
}
```

If using xcodegen, reference the xcconfig via `configFiles`:

```yaml
configFiles:
  Debug: SetappAI.xcconfig
  Release: SetappAI.xcconfig
```

> **Important:** Call `configureAuth()` once before the first AI request, not necessarily at app launch. It's idempotent — safe to call multiple times.

### Step 4: Error Presentation Mode

Error presentation is a **field on the same configuration object** as auth — not a separate setter:

```swift
SetappManager.shared.ai.set(configuration: .init(
    authConfiguration: AuthConfiguration(
        oauthClientId: clientId,
        oauthSecret: secret
    ),
    mode: .propagate          // default is .autoPresent
))
```

- `.autoPresent` (default) — the SDK shows its own error UI with recovery options, including a "Buy Credits" prompt that (from 5.3.4) links straight to the purchase page. No error handling needed.
- `.propagate` — errors surface as thrown `SetappAIError`s for your own UI to handle. Pick this if the app has its own error presentation.

> **There is no `set(errorPresenter:)`.** Older guidance showed `SetappManager.shared.ai.set(errorPresenter: .propagate)`; that API does not exist. Set `mode:` on the configuration instead — and set it in the *same* call as `authConfiguration`, since a second `set(configuration:)` replaces the whole object rather than merging.

### Step 5: Model Discovery

Fetch available models before making AI requests:

```swift
let ai = SetappManager.shared.ai
let models = try await ai.models.list()

// Each model exposes:
// - id:           String — provider-prefixed, e.g. "openai/gpt-4.1-mini", "anthropic/claude-sonnet-4"
// - mode:         what it does — .chat, .embedding, .imageGeneration, .videoGeneration, ...
// - capabilities: what it supports — .vision, .functionCalling, and so on
```

**Select on `mode` and `capabilities`, not on substrings of `id`.** Model ids get renamed and re-versioned; capability flags are the stable contract, and they're the only way to know a model can actually do what you're about to ask:

```swift
// A chat model that can accept images
let visionModel = models.first { $0.mode == .chat && $0.capabilities.contains(.vision) }

// A model for the image-generation API
let imageModel = models.first { $0.mode == .imageGeneration }
```

Keep a fallback chain — a user's plan may not include your first choice:

```swift
let model = models.first(where: { $0.id.contains("claude-sonnet") })
    ?? models.first(where: { $0.mode == .chat })
    ?? models.first
```

> **Available models change.** Always call `ai.models.list()` at runtime rather than hardcoding an id. Current providers span OpenAI, Anthropic, and Google Gemini.
>
> - Browsable table, filterable by provider/mode/capability: https://docs.setapp.com/docs/supported-ai-models
> - Live JSON: https://api.macpaw.com/ai/api/v1/model/info
>
> From 5.3.2 the model info endpoint also reports each model's **context window**.
>
> ⚠️ The old proxy at `vendor-api.setapp.com/resource/v1/ai/openai` is **deprecated and now returns 404**. The gateway is `https://api.macpaw.com/ai/v1/...`.

### Step 6: Streaming Responses

Create streaming AI requests:

```swift
let stream = try await SetappManager.shared.ai.responses.createStream(
    model: model,
    input: [.message("Your prompt here")],
    instructions: "System instructions here",  // optional
    maxOutputTokens: 256                        // optional
)

// Collect the response text
var collected = ""
for try await event in stream {
    if case let .response(.outputText(.delta(delta))) = event {
        collected += delta.delta
    }
}
// `collected` now contains the full response text
```

### Step 7: Conversation Context (Multi-Turn)

For multi-turn conversations, use `previousResponseID`:

```swift
var conversationResponseId: String?

// First message
let stream1 = try await ai.responses.createStream(
    model: model,
    input: [.message("What is Swift?")],
    previousResponseID: nil,
    store: true  // Required for context to be stored
)

for try await event in stream1 {
    if case let .response(.outputText(.delta(delta))) = event {
        // Handle streaming text
    }
    if case let .response(.responseLifecycle(.completed(lifecycleEvent))) = event {
        conversationResponseId = lifecycleEvent.response.id
    }
}

// Follow-up (maintains context)
let stream2 = try await ai.responses.createStream(
    model: model,
    input: [.message("Can you give an example?")],
    previousResponseID: conversationResponseId,
    store: true
)
```

### Step 8: Error Handling

```swift
do {
    let stream = try await ai.responses.createStream(model: model, input: [...])
    for try await event in stream {
        // process events
    }
} catch let error as SetappAIError {
    switch error.code {
    case .insufficientCredits:
        // User needs more credits
        if let recoveryURL = error.recoveryURL {
            // Open URL to purchase credits
        }
    case .rateLimit:
        // Too many requests — back off and retry
        break
    case .modelNotAllowed:
        // Model not available for this user's plan
        break
    case .general:
        // General error
        break
    }
} catch is CancellationError {
    // Stream was cancelled
} catch {
    // Other errors
}
```

### Step 9: Stream Cancellation

Wrap streaming in a cancellable Task:

```swift
let task = Task {
    do {
        let stream = try await ai.responses.createStream(
            model: model,
            input: [.message("...")]
        )
        for try await event in stream {
            guard !Task.isCancelled else { break }
            if case let .response(.outputText(.delta(delta))) = event {
                // Handle delta
            }
        }
    } catch is CancellationError {
        // Cancelled
    } catch {
        // Handle error
    }
}

// Cancel when needed (e.g., user taps stop):
task.cancel()
```

### Step 10: Wire Into App Architecture

Find the app's existing AI/LLM service layer and add SetappAI as a provider. Common patterns:

**If the app has a provider protocol/enum:**
Add a `.setappAI` case alongside existing providers, gated with `#if SETAPP`:

```swift
enum AIProviderType: String, CaseIterable {
    case onDevice = "On-Device"
    #if SETAPP
    case setappAI = "Setapp AI"
    #endif
}

// Default provider differs per build:
static var defaultProviderType: AIProviderType {
    #if SETAPP
    return .setappAI
    #else
    return .onDevice
    #endif
}
```

**If the app has no AI layer yet:**
Create a minimal helper:

```swift
#if SETAPP
import Setapp
import SetappAI

final class SetappAIProvider: @unchecked Sendable {
    private var selectedModel: SetappAIAPI.Model?
    private var previousResponseID: String?
    private var isConfigured = false

    func generate(prompt: String) async throws -> String {
        let ai = SetappManager.shared.ai
        if !isConfigured {
            configureAuth()
            isConfigured = true
        }

        if selectedModel == nil {
            let models = try await ai.models.list()
            selectedModel = models.first(where: { $0.id.contains("claude") && $0.id.contains("sonnet") })
                ?? models.first
        }

        guard let model = selectedModel else {
            throw NSError(domain: "SetappAI", code: -1, userInfo: [NSLocalizedDescriptionKey: "No models available"])
        }

        var text = ""
        let stream = try await ai.responses.createStream(
            model: model,
            input: [.message(prompt)],
            previousResponseID: previousResponseID,
            store: true
        )
        for try await event in stream {
            if case let .response(.outputText(.delta(delta))) = event {
                text += delta.delta
            }
            if case let .response(.responseLifecycle(.completed(lifecycleEvent))) = event {
                previousResponseID = lifecycleEvent.response.id
            }
        }
        return text
    }

    private func configureAuth() {
        let clientId = Bundle.main.object(forInfoDictionaryKey: "SetappAIOAuthClientID") as? String ?? ""
        let secret = Bundle.main.object(forInfoDictionaryKey: "SetappAIOAuthSecret") as? String ?? ""
        guard !clientId.isEmpty, !secret.isEmpty else { return }
        SetappManager.shared.ai.set(configuration: .init(
            authConfiguration: AuthConfiguration(oauthClientId: clientId, oauthSecret: secret)
        ))
    }
}
#endif
```

### Step 11: Credit Balance (Setapp-framework 5.3.3+)

Read the user's remaining AI credits — e.g. to show a balance bar. **Requires Setapp-framework 5.3.3 or newer**; earlier versions have no `credits` member and `SetappManager.shared.ai.credits` will not compile.

> **Caching changed in 5.3.6.** `balances()` now serves a cached value instead of hitting the network every call. Pass `forceUpdate: true` when you need a fresh figure from the server:
>
> ```swift
> let fresh = try await ai.credits.balances(forceUpdate: true)
> ```
>
> This inverts two things below. Cheap repeated reads (driving a balance bar off `balances()`) are now fine. But a post-run "what did that cost" delta must use `forceUpdate: true` on the *after* read, or you diff a stale cache against itself and always see zero.

```swift
let balances = try await SetappManager.shared.ai.credits.balances()

// Balances:
//   totalAvailable:     Amount   — credits remaining right now
//   totalInitialAmount: Amount   — the plan's full grant
//   balances:           [Balance] — per-bucket detail (each has currentValue, initialValue, expiresAt)
// Amount: { amount: Decimal, currency: .macpawCredits | .unsupported(String) }
```

**Map the SDK types into your own `Sendable` value** at the client boundary, so nothing above your networking layer needs to `import SetappAI`:

```swift
struct CreditsSnapshot: Sendable, Equatable { let current: Decimal; let max: Decimal }

func balances() async throws -> CreditsSnapshot {
    let b = try await SetappManager.shared.ai.credits.balances()
    return CreditsSnapshot(current: b.totalAvailable.amount, max: b.totalInitialAmount.amount)
}
```

> **Timeout it.** Unlike streaming, a forced refresh is a bare XPC round trip with no built-in bound. Wrap it in a task-group race against `Task.sleep` (~15s) — a stalled Setapp handshake will otherwise hang the caller indefinitely, and if you gate refetching on an "in-flight" flag, that flag never clears and the balance freezes for the rest of the session.

#### Arithmetic traps (all non-obvious, all real)

- **Round down, never to-nearest.** `1999.6` credits displayed with default rounding shows `2,000` — claiming credits the user doesn't have. Use `.number.rounded(rule: .down)`.
- **Guard `max == 0` before any ratio.** A zero grant (no subscription / unsupported currency) makes `current / max` a `Decimal` divide-by-zero; feeding the resulting NaN into a SwiftUI `.frame(width:)` is a layout crash. Special-case it to an "unavailable" state.
- **Clamp the ratio to `0...1`.** A mid-cycle bonus grant can leave `current > max`.
- **A real zero balance is "available and empty," not "failure."** `current == 0` from a *successful* fetch must render as an accurate empty bar, never as an error/unavailable state — a user who has simply run out otherwise sees "something broke."

#### "Credits used" deltas are account-wide — treat with care

`balances()` reports the whole **account** balance, not your app's consumption. A before/after diff to show "you just used N" is only sound when you guard it:

- a prior snapshot exists (no baseline → show no delta, never a bogus first-load number),
- the grant is unchanged between reads (a subscription renewal mid-session otherwise yields a negative or nonsense delta),
- the balance actually fell, by a displayable amount.

Even then, residual noise is inherent: **another Setapp AI app on the same account, or an expiring credit bucket, lands in the same diff.** Suppress rather than guess when unsure.

> **Open question — debit timing.** Whether the gateway debits `totalAvailable` synchronously at stream-end or with lag is not documented; verify against a live account. If it lags, a balance read immediately after a run under-reports, and a single run's usage can surface as two separate deltas. Poll-until-stable (refetch with `forceUpdate: true` until two reads agree) if you need the exact figure.

## Beyond Text: Images, Audio, Video

The Responses API is only part of the SDK. Check `model.mode` before calling any of these — passing a chat model to `ai.images` fails at runtime, not compile time.

### Image generation and editing (5.1.0+)

```swift
let model = models.first { $0.mode == .imageGeneration }!

let parameters = SetappAIAPI.Images.Generation.Parameters(
    model: model,
    prompt: "A serene landscape with mountains and a lake at sunset",
    size: .size1024x1024,
    quality: .high,
    outputFormat: .png,          // .png, .jpeg, .webp
    n: 1
)

let response = try await ai.images.generation(parameters: parameters, timeoutInterval: 60)
if let imageData = response.data?.first?.data {
    let image = NSImage(data: imageData)
}
```

Editing takes one or more input images:

```swift
let inputImage = SetappAIAPI.Images.Edit.InputImage(image: originalImageData, imageType: .png)

let parameters = SetappAIAPI.Images.Edit.Parameters(
    model: model,
    prompt: "Add a rainbow in the sky",
    image: [inputImage],
    size: .size1024x1024,
    quality: .high,
    outputFormat: .png,
    n: 1
)

let response = try await ai.images.edit(parameters: parameters, timeoutInterval: 60)
```

> **Image streaming is not supported** — there is no progressive/partial image delivery. Show a determinate-free spinner, not a progress bar.
>
> On **5.3.0 and earlier**, `SetappAIAPI.Images.Edit.Parameters` had no public initializer, so the edit API was unreachable from outside the module. Fixed in **5.3.1** — bump rather than work around it.

### Audio transcription (5.2.0+)

```swift
let parameters = SetappAIAPI.Audio.Transcription.Parameters(
    file: audioData,
    fileType: .mp3,
    model: "openai/whisper-1"
)

let response = try await ai.audio.transcribe(parameters: parameters, timeoutInterval: 120)
let text = response.text
```

Output variants, all on the same `parameters`:

| Call | Returns |
|---|---|
| `transcribe` | JSON with `.text` |
| `transcribeText` | plain `String` |
| `transcribeVerbose` | `.segments` and `.words` with timings |
| `transcribeSRT` / `transcribeVTT` | subtitle track |
| `transcribeDiarized` | segments labelled by speaker |

Set a generous `timeoutInterval` — transcription scales with audio length and 120s is a floor, not a ceiling.

### Video generation (5.3.0+)

Asynchronous: submit, poll, download. Generation runs from seconds to several minutes.

```swift
let model = models.first { $0.mode == .videoGeneration }!

let parameters = SetappAIAPI.Videos.Generation.Parameters(
    model: model,
    prompt: "A calico cat playing a piano on a concert stage",
    seconds: .four,
    size: .portrait720x1280
)

// 1. Submit — returns immediately with status .queued
let job = try await ai.videos.generate(parameters: parameters, timeoutInterval: 60)

// 2. Poll until terminal
var status = job.status
while status != .completed && status != .failed {
    try await Task.sleep(for: .seconds(5))
    status = try await ai.videos.retrieve(videoID: job.id, timeoutInterval: 30).status
}
guard status == .completed else { /* inspect .error */ return }

// 3. Download
let videoData = try await ai.videos.content(videoID: job.id, variant: .video, timeoutInterval: 300)
try videoData.write(to: destinationURL)

let thumbnail = try await ai.videos.content(videoID: job.id, variant: .thumbnail, timeoutInterval: 60)
```

> **Make the poll loop cancellable and bounded.** The loop above runs forever if the job never reaches a terminal state. Wrap it in a `Task` the user can cancel, check `Task.isCancelled` each pass, and cap total elapsed time. The 300s download timeout is deliberate — video payloads are large.

### Other Responses API features

The SDK also supports **structured outputs** (JSON constrained by a schema), **function calling / tool use**, and **reasoning models**. These ride on the same `ai.responses` surface as streaming text. Check `model.capabilities` for support — `.functionCalling` in particular varies by provider — and see the [SDK guide](https://docs.setapp.com/docs/setapp-ai-sdk-integration) for parameter shapes.

## Rate Limits and Gateway Errors

Setapp does not publish per-user rate limits or per-plan token ceilings in its current documentation. Earlier versions of this skill carried a specific table (400 req/min, 7,500/day, per-plan input-token caps) that can no longer be verified against any published source — **do not design around those numbers.** Treat limits as unknown, handle the error, and confirm real thresholds with your Developer Support Representative if a feature depends on them.

What *is* documented is the error contract. The gateway returns a stable `code` alongside each status:

| Status | Gateway code | Meaning |
|---|---|---|
| 400 | `BAD_REQUEST` | Missing required field or malformed request |
| 401 | `UNAUTHORIZED` | Missing, invalid, or expired token |
| 402 | `INSUFFICIENT_CREDITS` | Not enough credits — send the user to buy more |
| 403 | `FORBIDDEN` | Authenticated but not permitted (e.g. model not on this plan) |
| 422 | `VALIDATION` | Invalid value; check `errors[]` for the offending field |
| 429 | `RATE_LIMIT_EXCEEDED` | Back off and retry |
| 500 | `INTERNAL_SERVER_ERROR` | Gateway or upstream failure; quote `request_id` to support |

Through the Swift SDK these arrive as `SetappAIError.code` — `.rateLimit`, `.insufficientCredits`, `.modelNotAllowed`, `.general`. Branch on `code`, never on the message string.

Reference: https://docs.setapp.com/reference/get_errors_reference

## Testing

1. Ensure the Setapp desktop app is installed, running, and logged in
2. Ensure `setappPublicKey.pem` is in the app bundle
3. Ensure the bundle ID is registered in the Setapp developer portal
4. Ensure sandbox Mach exception is present (if sandboxed) — see `setapp-framework` skill
5. Build and run the Setapp target — the OAuth flow should authenticate automatically
6. Test model listing, streaming, and error cases
7. Verify rate limit handling

> **If AI requests fail silently:** Check that `import SetappAI` is present (not just `import Setapp`), and that OAuth credentials are being read correctly from Info.plist. Log the clientId/secret values (in debug only) to verify they're not empty strings.

## Common Pitfalls

1. **Missing `import SetappAI`** — `SetappManager.shared.ai`, `AuthConfiguration`, and `SetappAIAPI.Model` all require the SetappAI module. `import Setapp` alone is not enough.
2. **OAuth credentials not injected** — If using xcconfig + Info.plist build variables, verify the xcconfig is referenced in build settings and the Info.plist key names match exactly.
3. **Framework prerequisite check** — Don't search for `SetappManager.shared.start` on macOS to detect framework integration — that method doesn't exist on macOS. Search for `import Setapp` or the SPM dependency instead.
4. **`ai.credits` won't compile on old SDKs** — the credits API arrived in Setapp-framework **5.3.3**. On earlier pins, `SetappManager.shared.ai.credits` fails with "value of type has no member 'credits'". Bump the SPM dependency, don't work around it. (See Step 11.)
5. **`set(errorPresenter:)` does not exist** — error mode is the `mode:` field on the configuration object, set in the same call as `authConfiguration`. (See Step 4.)
6. **Selecting models by substring of `id`** — ids get renamed and re-versioned. Filter on `mode` and `capabilities`; a chat model passed to `ai.images` fails at runtime, not compile time.
7. **Stale credit balance after 5.3.6** — `balances()` is cached now. A "credits used" delta that doesn't pass `forceUpdate: true` diffs the cache against itself and reports zero forever.
8. **Unbounded video poll loop** — `ai.videos.retrieve` polling has no built-in ceiling. Make it cancellable and cap elapsed time, or a stuck job hangs the feature.

## Reference

- [Setapp AI Swift SDK guide](https://docs.setapp.com/docs/setapp-ai-sdk-integration) — the authoritative API reference
- [AI integration overview](https://docs.setapp.com/docs/ai-integration) · [AI Gateway (HTTP)](https://docs.setapp.com/docs/ai-gateway) · [TypeScript SDK](https://docs.setapp.com/docs/typescript-sdk)
- [Supported models](https://docs.setapp.com/docs/supported-ai-models) · live JSON at https://api.macpaw.com/ai/api/v1/model/info
- [Gateway error reference](https://docs.setapp.com/reference/get_errors_reference) · [OAuth clients](https://docs.setapp.com/docs/oauth-clients)
- [Framework releases](https://github.com/MacPaw/Setapp-framework/releases) — check here for API changes before trusting this skill's version table
- Docs index for agents: https://docs.setapp.com/llms.txt (append `.md` to any docs URL for clean Markdown)

## What This Skill Does NOT Cover

- **Backend/server-side proxy setup** — for web apps and browser extensions, use the [AI Gateway](https://docs.setapp.com/docs/ai-gateway) HTTP API or the TypeScript SDK
- **iOS activation flows** — covered in Setapp's iOS integration docs
- **Pricing/monetization** — handled through the Setapp developer account
