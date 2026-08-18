# Setapp Framework skill — usage guide

Human-facing companion to [`skills/setapp-framework/SKILL.md`](../skills/setapp-framework/SKILL.md). Claude loads the SKILL.md automatically; this page is for you.


## Who this is for

This skill is for developers adding a macOS app to the Setapp marketplace. It works for both brand new integrations (starting from scratch) and existing apps that need to be updated or verified before submission.

## How to invoke it

Just describe what you're trying to do in natural language. Examples that will trigger this skill:

- *"I want to publish my app on Setapp"*
- *"Help me integrate the Setapp Framework into my app"*
- *"Add the Setapp SDK to my Xcode project"*
- *"We need to submit to Setapp — can you check everything is in order?"*
- *"I'm getting 'This copy requires an active Setapp account' — help me fix it"*

## What to have ready

Before starting, it helps to have:

- Access to your Xcode project (Claude can read your project files if you've given it folder access)
- Your app's bundle ID (or the name you want to use for the Setapp variant)
- Access to the [Setapp developer portal](https://developer.setapp.com) (some steps require actions there that Claude cannot do on your behalf)
- Whether your app uses xcodegen (`project.yml`) or a standard `.xcodeproj` — the instructions differ between the two

## What this skill does, step by step

The skill walks you through a **15-step checklist**, split into four phases:

**Phase 1 — Project setup (Steps 1–4)**
Creates a separate Xcode target for the Setapp build, adds the Setapp Swift Package, and configures the correct bundle ID. Claude will first scan your codebase to detect what's already done and skip those steps.

**Phase 2 — Configuration (Steps 5–10)**
Configures `Info.plist`, downloads the public key, initialises the framework correctly (macOS auto-initialises — no `start()` call needed), sets up sandbox entitlements, and adds usage reporting appropriate to your app type (regular app, sign-in required, or menu bar app).

**Phase 3 — Submission prep (Steps 11–12)**
Packages the archive with the correct structure (the standalone `.png` icon is a common gotcha), and registers the bundle ID in the Setapp developer portal.

**Phase 4 — Compliance (Steps 13–15)**
This is where the skill goes beyond a standard integration guide:

- **Step 13 (Live Guidelines Check):** Fetches the latest Setapp review guidelines from the web and compares them against the built-in checklist. Any new or changed requirements are surfaced as explicit `⚠️` warnings so nothing slips through between skill updates.
- **Step 14 (Review Compliance Scan):** Searches your codebase for patterns that commonly cause rejection — IAP/StoreKit APIs, ad SDKs, custom updaters (Sparkle etc.), third-party licensing tools, analytics SDKs, and background daemon patterns. Results are presented as a summary table. Items already guarded with `#if !SETAPP` are flagged as safe; unguarded items require action.
- **Step 15 (Final Checklist):** A complete pre-submission sign-off list, including two new items confirming Steps 13 and 14 were completed.

## How to interpret compliance scan results

The scan table looks like this:

| Category | Found? | Files | Action Required |
|---|---|---|---|
| IAP / StoreKit | ✅ None | — | — |
| Advertising SDKs | ⚠️ Yes | `Sources/Analytics.swift:42` | Must remove or guard with `#if !SETAPP` |
| Custom updater | ✅ None | — | — |
| Custom licensing | ⚠️ Yes | `Sources/License.swift:18` | Already guarded with `#if !SETAPP` ✓ |

- **✅ None** — clean, no action needed
- **⚠️ Yes + "Already guarded"** — the code exists but is excluded from the Setapp build; safe to proceed
- **⚠️ Yes** without a guard note — this needs to be resolved before submission

## Partial runs

You don't have to run the full checklist every time. You can ask Claude to jump to a specific step, for example:

- *"Just run the compliance scan on my project"*
- *"Check whether my sandbox entitlements are correct for Setapp"*
- *"I've already done the setup — just check the submission requirements"*

## Things Claude cannot do for you

A few steps require manual action in external systems:

- Downloading `setappPublicKey.pem` from the Setapp developer portal (Step 6)
- Registering your bundle ID in the portal (Step 12)
- Notarizing the app with Apple (Step 15)
- Signing with a Developer ID certificate (requires your local keychain)

Claude will remind you of these at the relevant step.

