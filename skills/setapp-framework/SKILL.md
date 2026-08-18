---
name: setapp-framework
description: Use when integrating the Setapp Framework into a macOS app. Triggers on mentions of "integrate Setapp", "add Setapp SDK", "Setapp framework", "publish on Setapp", or adding Setapp licensing/activation to a macOS app. Covers SPM dependency, Info.plist config, framework initialization, sandbox entitlements, usage reporting, archive packaging, and review compliance.
---

# Setapp Framework Integration (macOS)

## Overview

Integrate the Setapp Framework into a macOS app to handle licensing, activation, usage reporting, and updates. This is Phase 1 — required before adding Setapp AI+ features.

## When to Use

- Adding a macOS app to the Setapp marketplace
- Integrating Setapp licensing into a new or existing app
- User mentions "Setapp", "Setapp SDK", "publish on Setapp"

## Checklist

Work through each step. Skip steps that are already done (detect by searching the codebase).

### Step 1: Detect Current State

Search the codebase before doing anything:

```
Search for: "import Setapp", "SetappManager", "Setapp-framework" in SPM/Package.resolved
```

If the framework is already installed, skip to the step that isn't done yet.

### Step 2: Create a Separate Xcode Target

The Setapp build MUST be a separate target from the App Store build. This is because:
- Different bundle ID (`-setapp` suffix required)
- Different entitlements (Mach service exception)
- Different Info.plist (Setapp-specific keys)
- Different signing (Developer ID, not App Store)

If the project uses **xcodegen** (`project.yml`):
- Add a new target (e.g., `AppNameSetapp`) with `platform: macOS`
- Share the same source files via `sources: - path: ...`
- Add `SWIFT_ACTIVE_COMPILATION_CONDITIONS: "$(inherited) SETAPP"` so code can use `#if SETAPP`
- Use a **separate entitlements file** (e.g., `AppName-Setapp.entitlements`)
- Use a **separate Info.plist** (e.g., `Info-Setapp.plist`) — set via `INFOPLIST_FILE` build setting

> **CRITICAL xcodegen warning:** If using xcodegen, do NOT add an `info: path:` block for the Setapp target. xcodegen's `info:` block **overwrites** the plist file on every `xcodegen generate`, destroying any manually added keys (NSUpdateSecurityPolicy, OAuth vars, etc.). Instead, rely solely on `INFOPLIST_FILE` in the target's `settings.base`. The plist file must be maintained manually.

If using a standard Xcode project: Duplicate the existing macOS target and rename it.

### Step 3: Add SPM Dependency

Add the Setapp Framework via Swift Package Manager:

- **URL:** `https://github.com/MacPaw/Setapp-framework.git`
- **Version:** From `5.3.6` (latest as of 2026-08-18 — always check [releases](https://github.com/MacPaw/Setapp-framework/releases))

> **Version floors.** `5.1.0` still works for plain licensing, but take the latest unless you have a reason not to. Features gated on newer releases:
>
> | Need | Minimum |
> |---|---|
> | Plain licensing / activation | 5.1.0 |
> | AI image generation & editing | 5.1.0 |
> | AI audio transcription | 5.2.0 |
> | AI video generation | 5.3.0 |
> | AI credit balances (`ai.credits`) | 5.3.3 |
> | Cached credit balances (`forceUpdate:`) | 5.3.6 |
>
> **Breaking change in 5.3.6:** `requestAuthorizationCode` no longer takes a `scope` argument — the framework now applies the `application.access` scope itself, and `VendorAuthorizationScope` / `SCVendorAppScope` are no longer public. If the app calls it, change to `requestAuthorizationCode(clientID:completionHandler:)`.

If the project uses `Package.swift`:

```swift
dependencies: [
    .package(
        name: "Setapp",
        url: "https://github.com/MacPaw/Setapp-framework.git",
        from: "5.3.6"
    )
]
```

If using xcodegen (`project.yml`):

```yaml
packages:
  Setapp:
    url: https://github.com/MacPaw/Setapp-framework.git
    from: "5.3.6"
```

Link only to the Setapp target:

```yaml
dependencies:
  - package: Setapp
    product: Setapp
```

> **Important:** You must specify `product: Setapp` explicitly — without it, xcodegen may fail to resolve the package product.

If using Xcode project (`.xcodeproj`): Add via Xcode > File > Add Package Dependencies.

When using `-force_load` for the static library, add this linker flag to the Setapp target only:

```yaml
OTHER_LDFLAGS: "$(inherited) -force_load $(BUILT_PRODUCTS_DIR)/libSetapp.a"
```

**Verify:** Check `Package.resolved` contains `Setapp-framework`.

> **Resource bundle.** From 5.0.0, `SetappFramework-Resources.bundle` is required for both macOS and iOS apps that use the Setapp AI API — it carries the activation UI's localized strings and assets. SPM and CocoaPods pull it in for you. If you integrate manually or via Carthage, download it from the [release assets](https://github.com/MacPaw/Setapp-framework/releases/latest) and add it to Copy Bundle Resources. (Before 5.0.0 it was iOS-only and named `SetappFramework-Resources-iOS.bundle`.)

### Step 4: Bundle ID

The Setapp bundle ID **must** use the `-setapp` suffix:

```
<domain>.<companyName>.<appName>-setapp
```

Example: `com.macpaw.agentodo-setapp`

If the app ships **additional executables** (helpers, menu bar agents, XPC services, login items), each one extends the Setapp bundle ID:

```
<domain>.<companyName>.<appName>-setapp.<executableName>
```

Example: `com.macpaw.cleanmymac-setapp.Menu`

This is set once in the Setapp developer account and **cannot be changed**. The Xcode target's bundle ID must match exactly. Use only the hyphen-minus character (U+002D) — an option-key en dash looks identical and will not match. Never put a version number in the bundle ID.

Reference: https://docs.setapp.com/docs/set-an-app-bundle-id

> **App Store Connect note:** When creating the App ID / app record for the Setapp build (needed for notarization), Apple requires unique app names per account. If you already have an App Store app with the same name, use a variant like "AppName (Setapp)" or "AppName for Setapp" for the App Store Connect record. This is only the internal record name — `CFBundleDisplayName` can still match the original app name.

### Step 5: Configure Info.plist

Create a **separate** `Info-Setapp.plist` for the Setapp target. It must include ALL standard keys (CFBundleName, CFBundleVersion, etc.) plus these Setapp-specific keys:

**Allow Setapp to update the app (macOS 13+):**

```xml
<key>NSUpdateSecurityPolicy</key>
<dict>
    <key>AllowProcesses</key>
    <dict>
        <key>MEHY5QF425</key>
        <array>
            <string>com.setapp.DesktopClient.SetappAgent</string>
        </array>
    </dict>
</dict>
```

**Declare supported architectures (universal recommended):**

```xml
<key>MPSupportedArchitectures</key>
<array>
    <string>arm64</string>
    <string>x86_64</string>
</array>
```

**If using SetappAI (OAuth credentials as build variables):**

```xml
<key>SetappAIOAuthClientID</key>
<string>$(SETAPP_AI_OAUTH_CLIENT_ID)</string>
<key>SetappAIOAuthSecret</key>
<string>$(SETAPP_AI_OAUTH_SECRET)</string>
```

Store the actual values in a gitignored `.xcconfig` file and reference it via `configFiles` in xcodegen or Xcode build settings.

### Step 6: Public Key

The `setappPublicKey.pem` file must be downloaded from the Setapp developer account and added to the Xcode project's main bundle. Claude cannot do this — remind the developer:

1. Go to https://developer.setapp.com/applications
2. Click "New version" on your app
3. Find the public key link on the right side of "Release info"
4. Download `setappPublicKey.pem`
5. Drag it into Xcode navigator (check "Copy items if needed")
6. Ensure it's in the main bundle of the Setapp target
7. If using xcodegen, add it to `resources:` for the Setapp target

The filename MUST be exactly: `setappPublicKey.pem`

### Step 7: Framework Initialization (macOS vs iOS)

**macOS (v5.1.0+):** The framework **auto-initializes** on macOS. Do NOT call `SetappManager.shared.start()` — the `start(with:)` method **does not exist** on macOS in v5.1.0 and will cause a compilation error:

```
error: value of type 'SetappManager' has no member 'start'
```

No explicit initialization code is needed for macOS. The framework detects the Setapp desktop client automatically via XPC.

**iOS:** `SetappManager.shared.start(with: .default)` IS required for iOS targets. Call it in `applicationDidFinishLaunching` or equivalent.

### Step 8: Sandbox Entitlements (CRITICAL for Sandboxed Apps)

If the app is sandboxed (`com.apple.security.app-sandbox: true`), you **MUST** add a Mach service temporary exception. Without this, the sandbox blocks XPC communication with the Setapp desktop client and the app will show "This copy of [App] requires an active Setapp account installed on your Mac" even when Setapp is installed and logged in.

Add this to the **Setapp target's entitlements file**:

```xml
<key>com.apple.security.temporary-exception.mach-lookup.global-name</key>
<array>
    <string>com.setapp.ProvisioningService</string>
</array>
```

> **CRITICAL:** The Mach service name is exactly `com.setapp.ProvisioningService`. Not `com.setapp.DesktopClient.SetappAgent`, not `com.setapp.DesktopClient.SetappAgent.HelperTool` — those are wrong and won't work.
>
> Reference: https://docs.setapp.com/docs/add-sandbox-temporary-exception-entitlement

This is the **most common cause** of "Setapp not detected" errors in sandboxed apps.

### Step 9: Usage Reporting

Detect the app type and add appropriate usage events:

**Regular app (has its own window, no sign-in required):**
No manual events needed — the framework handles everything automatically.

**App requiring sign-in:**

```swift
// After successful sign-in AND on launch if already signed in:
SetappManager.shared.reportUsageEvent(.signIn)

// After sign-out:
SetappManager.shared.reportUsageEvent(.signOut)
```

**Menu bar app (or app with menu bar extra):**

```swift
// When user clicks/opens the menu bar panel:
SetappManager.shared.reportUsageEvent(.userInteraction)
```

### Step 10: Release Notes (Optional but Recommended)

Add release notes display after app updates:

```swift
// In applicationDidFinishLaunching:
SetappManager.shared.showReleaseNotesWindowIfNeeded()
```

Optionally, add an on-demand menu item:

```swift
@IBAction private func showReleaseNotes(_ sender: Any) {
    SetappManager.shared.showReleaseNotesWindow()
}
```

### Step 11: Archive Packaging for Submission

Setapp has specific requirements for the zip archive you upload.

**Archive structure** — the app in the zip root, or in a single nested directory:

```
AppName.zip                 AppName.zip
├── AppName.app       or    └── SomeDirectory
└── AppIcon.png                 ├── AppName.app
                                └── AppIcon.png
```

**Icon requirements:**
- The file must be named exactly **`AppIcon.png`**. Not `<AppName>.png` — Setapp's uploader only accepts `AppIcon.png`, and a name-matched file is rejected.
- **1024 × 1024 pixels**, PNG.
- Design placed inside an 824 × 824 frame with a 100px margin, corners curved — follow [Apple's app icon guidance](https://developer.apple.com/design/human-interface-guidelines/app-icons).
- Sits **alongside** the `.app`, not inside the bundle. Setapp reads the icon from the archive, not from `Assets.car` or the `.icns`.

> **Xcode won't export a 1024px standalone icon by default.** It caps extraction at 256 × 256, so the icon you ship is silently too small. Set Build Settings > Asset Catalog Compiler - Options > **Standalone Icon File Behaviour** to `All`, or in an xcconfig:
>
> ```
> ASSETCATALOG_COMPILER_STANDALONE_ICON_BEHAVIOR = all
> ```

**Archive rules:**
- No `__MACOSX` folders. Do not compress from Finder's context menu — it adds hidden metadata. Use `ditto` or `zip -r` from the command line.
- Bundle size cannot exceed 1 GB.
- The unpacked archive must contain exactly one root directory holding the `.app`, with no extra metadata folders.

Verify before uploading:

```bash
/usr/bin/ditto -x -k AppName.zip /tmp/verify && find /tmp/verify -maxdepth 2
```

If `__MACOSX` appears, the archive was packed wrong — rebuild it.

**Required `Info.plist` keys in the submitted bundle:**

| Key | Note |
|---|---|
| `CFBundleIdentifier` | Must match the ID registered in the portal |
| `CFBundleName` | |
| `CFBundleIconFile` | The `.icns` may contain icons below 512px; the standalone `AppIcon.png` is what Setapp displays |
| `CFBundleVersion` | |
| `CFBundleShortVersionString` | |
| `NSUpdateSecurityPolicy` | See Step 5 |

**Signing:**
- Signed with a **Developer ID certificate** (not App Store distribution)
- **Notarized** by Apple

**Automated upload (optional).** Setapp supports CI upload three ways: the [build upload API](https://docs.setapp.com/reference/post_version-1), a [shell script template](https://github.com/MacPaw/fastlane-plugin-setapp/blob/main/lib/fastlane/plugin/setapp/helper/setapp_build_uploader.sh), or the [Fastlane plugin](https://github.com/MacPaw/fastlane-plugin-setapp). All need a Setapp Automation token — request it from your Developer Support Representative.

Reference: https://docs.setapp.com/docs/submitting-apps-for-review

### Step 12: Developer Portal Registration

Before the app will work (even in debug), the bundle ID must be registered in the Setapp developer portal:

1. Go to https://developer.setapp.com/applications
2. Register your app with the exact bundle ID (e.g., `com.macpaw.appname-setapp`)
3. This cannot be changed after registration

Without portal registration, the Setapp desktop client won't recognize the app, and the framework will show an activation error dialog.

### Step 13: Live Guidelines Check

Before finalising the submission, fetch the latest Setapp review guidelines to catch any policy changes that may have occurred since this skill was last updated.

**Setapp's docs are agent-readable.** Two things make this cheap and reliable:

- `https://docs.setapp.com/llms.txt` is a complete index of every docs page. Fetch it first to discover pages this skill doesn't know about.
- Any docs page serves clean Markdown by appending `.md` to its URL — e.g. `https://docs.setapp.com/docs/review-guidelines.md`. Prefer the `.md` form; the HTML is a JS app and fetches poorly.

Fetch these two pages and read them:

- https://docs.setapp.com/docs/preparing-your-application-for-setapp.md
- https://docs.setapp.com/docs/review-guidelines.md

Then compare the fetched requirements against the Step 15 checklist below. Specifically look for:

1. **New prohibited behaviours** not currently in the checklist (e.g. new restrictions on data collection, network access, background activity, etc.)
2. **Updated technical requirements** (e.g. minimum macOS version, new entitlement requirements, archive format changes)
3. **Monetisation policy changes** (e.g. rules around in-app purchases, trials, paywalls)
4. **Privacy or analytics restrictions** that may affect tracking SDKs in the codebase

If the fetched guidelines contain requirements not covered in Step 15, add them to the checklist and flag them to the developer explicitly:

```
⚠️  New guideline detected (not in skill checklist):
    "[Paste the relevant requirement here]"
    Action required: [describe what the developer needs to verify or change]
```

Also re-check the pinned SDK version against https://github.com/MacPaw/Setapp-framework/releases — release notes are where breaking API changes surface first (the `requestAuthorizationCode` scope removal in 5.3.6, for example, appeared there before anywhere else).

If a page cannot be fetched (network issue, 403, etc.), note this and proceed — the static checklist in Step 15 is a good baseline, but the developer should verify manually before submission.

### Step 14: Review Compliance Scan

Before submitting, scan the codebase for patterns that commonly cause Setapp review rejection. Search across all Swift, Objective-C, and configuration files in the Setapp target.

Run each of the following searches and report findings. Flag anything found as a ⚠️ warning with the file path and line — the developer must verify whether it applies to the Setapp build specifically (some may be guarded by `#if !SETAPP` and are fine).

#### IAP and StoreKit
Search for signs of in-app purchases, which are prohibited on Setapp:

```
Patterns: "StoreKit", "SKPaymentQueue", "SKProduct", "SKPayment",
          "requestReview", "AppStore.open", "Purchase", "paymentQueue"
```

If found: Check whether the code is guarded with `#if !SETAPP`. If not guarded, it must be removed or conditionally compiled out for the Setapp target.

#### Advertising SDKs
Search for known ad frameworks and tracking SDKs:

```
Patterns: "GoogleMobileAds", "GADRequest", "AdMob", "FBAudienceNetwork",
          "AppLovin", "ironSource", "MoPub", "ATTrackingManager",
          "advertisingIdentifier", "IDFA"
```

If found: Advertising functionality is prohibited on Setapp. Must be removed from the Setapp target entirely.

#### Custom Update Frameworks
Setapp handles all app updates — bundling a separate update mechanism is prohibited:

```
Patterns: "Sparkle", "SUUpdater", "checkForUpdates", "SUStandardVersionComparator",
          "Squirrel", "auto-update", "checkForUpdate"
```

If found: Sparkle and similar frameworks must not be active in the Setapp build. Ensure update checks are disabled or the framework is excluded from the Setapp target.

#### Custom Licensing / Copy Protection
Setapp handles licensing — custom licence checks can conflict with Setapp activation:

```
Patterns: "LicenseKey", "licenseKey", "activationKey", "serialNumber",
          "Paddle", "DevMate", "FastSpring", "Gumroad"
```

If found: Custom licensing must be replaced with Setapp's activation flow. Check whether this code is already guarded with `#if !SETAPP`.

#### Analytics and Data Collection
Some analytics SDKs may conflict with Setapp's privacy requirements:

```
Patterns: "Mixpanel", "Amplitude", "Segment", "Firebase", "Crashlytics",
          "Sentry", "Bugsnag", "HockeyApp", "AppCenter"
```

If found: These are not automatically disqualifying, but verify the SDK's data collection settings comply with Setapp's privacy guidelines (fetched in Step 13). At minimum, ensure no user data is sent without consent.

#### Background Daemons / Launch Agents
Background processes require explicit user consent:

```
Patterns: "SMLoginItemSetEnabled", "launchd", "LaunchAgent", "LaunchDaemon",
          "registerForRemoteNotifications" (without consent flow)
```

If found: Verify there is a clear user consent flow before any background process is enabled.

#### Summary output format

After running all searches, present a table like this:

| Category | Found? | Files | Action Required |
|---|---|---|---|
| IAP / StoreKit | ✅ None | — | — |
| Advertising SDKs | ⚠️ Yes | `Sources/Analytics.swift:42` | Must remove or guard with `#if !SETAPP` |
| Custom updater | ✅ None | — | — |
| Custom licensing | ⚠️ Yes | `Sources/License.swift:18` | Already guarded with `#if !SETAPP` ✓ |
| Analytics SDKs | ⚠️ Yes | `Sources/Tracking.swift:7` | Verify privacy compliance |
| Background processes | ✅ None | — | — |

Only proceed to Step 15 once all ⚠️ items are either resolved or confirmed safe.

### Step 15: Pre-Submission Review Checklist

Before submitting to Setapp, verify:

- [ ] App is **notarized**
- [ ] App is **signed with Developer ID certificate**
- [ ] **Universal binary** (arm64 + x86_64) — set "Build Active Architectures Only" to NO for Release
- [ ] Tested on **latest macOS version**
- [ ] **No license keys** or custom copy protection (Setapp handles licensing)
- [ ] **No proprietary installer/update framework** (Setapp handles updates)
- [ ] **No built-in store or in-app purchases**
- [ ] **No advertising or promotional functionality**
- [ ] **No background processes** without explicit user consent
- [ ] **No notifications** without first obtaining user consent
- [ ] `setappPublicKey.pem` is in the main bundle
- [ ] `NSUpdateSecurityPolicy` is in Info.plist
- [ ] `MPSupportedArchitectures` is in Info.plist
- [ ] Sandbox Mach exception (`com.setapp.ProvisioningService`) is in entitlements (if sandboxed)
- [ ] Usage reporting is configured for the app type
- [ ] Archive includes a **1024×1024 `AppIcon.png`** alongside the `.app` (exact filename)
- [ ] Archive unpacks with `ditto -x -k` to a single root dir, no `__MACOSX`
- [ ] `Info.plist` has CFBundleIdentifier, CFBundleName, CFBundleIconFile, CFBundleVersion, CFBundleShortVersionString
- [ ] Release notes text prepared (max 5,000 characters)
- [ ] Bundle ID registered in Setapp developer portal
- [ ] Live guidelines check (Step 13) completed — no new policy items outstanding
- [ ] Review compliance scan (Step 14) completed — no unresolved ⚠️ items

## Testing

1. Register the app in the Setapp developer portal
2. Install the Setapp desktop app on your Mac and log in
3. Build and run the Setapp target
4. The framework should activate without showing the "requires Setapp" dialog
5. Check that usage events are reported (visible in Setapp developer dashboard)

If you see "This copy of [App] requires an active Setapp account installed on your Mac":
- **First check:** Sandbox Mach exception entitlement — is `com.setapp.ProvisioningService` present?
- **Second check:** Is the bundle ID registered in the Setapp developer portal?
- **Third check:** Is the Setapp desktop app running and logged in?

Reference: https://docs.setapp.com/docs/testing-your-application

## Common Pitfalls

1. **`SetappManager.shared.start()` on macOS** — Does not compile on macOS v5.1.0. The framework auto-initializes. Only iOS needs explicit `start()`.
2. **Wrong Mach service name** — Must be `com.setapp.ProvisioningService`, not any SetappAgent variant.
3. **xcodegen overwriting Info.plist** — Never use `info: path:` block for the Setapp target; it overwrites the file on every generate.
4. **Icon named after the app** — the standalone icon must be `AppIcon.png` exactly, 1024×1024, in the zip next to the `.app`. Naming it `<AppName>.png` fails the upload, and Xcode caps standalone icon export at 256px unless `ASSETCATALOG_COMPILER_STANDALONE_ICON_BEHAVIOR = all`.
5. **App name collision in App Store Connect** — Use "AppName (Setapp)" for the ASC record name.
6. **Finder-compressed archive** — right-click > Compress adds `__MACOSX`, which fails validation. Pack with `ditto`/`zip -r` and verify by unpacking.
7. **SPM version** — The docs' install page still shows `from: "4.2.1"`; that's stale. Use 5.3.6 (or current latest). Older pins silently lack the AI, credits, and image/audio/video APIs.

## Reference

- [Docs index for agents (`llms.txt`)](https://docs.setapp.com/llms.txt) — append `.md` to any docs URL for clean Markdown
- [App requirements](https://docs.setapp.com/docs/preparing-your-application-for-setapp) · [Review guidelines](https://docs.setapp.com/docs/review-guidelines)
- [Set an app bundle ID](https://docs.setapp.com/docs/set-an-app-bundle-id) · [Sandbox exception](https://docs.setapp.com/docs/add-sandbox-temporary-exception-entitlement) · [Supported architectures](https://docs.setapp.com/docs/specify-supported-architectures)
- [Usage reporting](https://docs.setapp.com/docs/implement-usage-reporting) · [Submitting apps for review](https://docs.setapp.com/docs/submitting-apps-for-review) · [Testing](https://docs.setapp.com/docs/testing-your-application)
- [Integration troubleshooting](https://docs.setapp.com/docs/integration-troubleshooting) · [Framework releases](https://github.com/MacPaw/Setapp-framework/releases) · [Developer portal](https://developer.setapp.com/applications)

## What's Next

After the framework is integrated, use the **`setapp-ai`** skill to add Setapp AI+ capabilities.
