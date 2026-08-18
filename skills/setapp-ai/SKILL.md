---
name: setapp-ai
description: Use when adding Setapp AI+ capabilities to a macOS or iOS app. Triggers on mentions of "Setapp AI", "SetappAI", "AI+", "Setapp AI integration", or adding AI features through Setapp's AI proxy. Requires the Setapp Framework to be integrated first (use setapp-framework skill if not done).
---

# Setapp AI+ Integration

## Overview

Add AI capabilities to your app through Setapp's unified AI platform. Setapp proxies requests to multiple AI providers (OpenAI, Anthropic, Google Gemini) — no per-user API keys needed. Users get AI access through their Setapp subscription.

## Prerequisites

The Setapp Framework must be integrated first. Check for:

```
Search for: "import Setapp", "Setapp-framework" in Package.resolved, and "com.setapp.ProvisioningService" in entitlements
```

If not found, tell the user: **"The Setapp Framework isn't integrated yet. Use the `setapp-framework` skill first."**

> **Note:** On macOS, do NOT search for `SetappManager.shared.start` — that method doesn't exist on macOS v5.1.0+. The framework auto-initializes. Its absence does NOT mean the framework isn't integrated.

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

### Step 4: Error Presenter

Configure how errors are presented to the user:

```swift
// Option A: Automatic (default) — SDK shows error UI
// No code needed, this is the default behavior.

// Option B: Propagate — errors flow through your own error handling
SetappManager.shared.ai.set(errorPresenter: .propagate)
```

Use `.propagate` if your app has its own error UI. Use the default if you want Setapp to handle error presentation.

### Step 5: Model Discovery

Fetch available models before making AI requests:

```swift
let ai = SetappManager.shared.ai

// List available models
let models = try await ai.models.list()

// Each model has:
// - id: String (e.g., "claude-sonnet-4-20250514", "gpt-4.1-mini")
// - SetappAIAPI.Model type

// Pick a preferred model with fallback
let model = models.first(where: { $0.id.contains("claude") && $0.id.contains("sonnet") })
    ?? models.first(where: { $0.id.contains("claude") })
    ?? models.first
```

> **Note:** Available models change over time. Always use `ai.models.list()` for the current list. As of 2025-2026, available providers include OpenAI (GPT-4o, GPT-4.1, GPT-5 family), Anthropic (Claude Sonnet, Claude Opus), and Google Gemini.
>
> **Live model list:** https://vendor-api.setapp.com/resource/v1/ai/openai/supported-models

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

> **Timeout it.** Unlike streaming, this is a bare XPC round trip with no built-in bound. Wrap it in a task-group race against `Task.sleep` (~15s) — a stalled Setapp handshake will otherwise hang the caller indefinitely, and if you gate refetching on an "in-flight" flag, that flag never clears and the balance freezes for the rest of the session.

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

> **Open question — debit timing.** Whether the proxy debits `totalAvailable` synchronously at stream-end or with lag is not documented; verify against a live account. If it lags, a balance read immediately after a run under-reports, and a single run's usage can surface as two separate deltas. Poll-until-stable (refetch until two reads agree) if you need the exact figure.

## Rate Limits

Per-user limits to be aware of when designing your AI features:

| Model Category | Per Minute | Per Hour | Per Day |
|---------------|-----------|----------|---------|
| GPT-4 & GPT-5 | 400 | — | 7,500 |
| Embedding models | — | 10,000 | 10,000 |
| All other models | — | 10,000 | 20,000 |

**Token limits per request:**
- Enthusiast plan: 160,000 input tokens
- Expert plan: 1,600,000 input tokens

Handle HTTP 429 / `SetappAIError.code == .rateLimit` gracefully.

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

## What This Skill Does NOT Cover

- **Backend/server-side proxy setup** — for web apps, use the AI Gateway (HTTP API) directly
- **iOS activation flows** — covered in Setapp's iOS integration docs
- **Pricing/monetization** — handled through the Setapp developer account
