# SDK sync — agent instructions

You are updating `skills/setapp-framework/SKILL.md` and `skills/setapp-ai/SKILL.md` for a new Setapp-framework release. The prompt gives you the old version (`CURRENT`), the new one (`TARGET`), a framework checkout at `TARGET`, and two diffs. A human reviews your PR, so be precise and say what you couldn't verify.

## 1. Find every change — not just the announced ones

- Read the CHANGELOG diff in full.
- Then read the `.swiftinterface` diff. **Release notes are not exhaustive**: 5.5.4 raised the macOS floor from 11.5 to 12.0 and dropped `SetappManager`'s `NSObject` base without mentioning either. Look specifically for:
  - `-target arm64-apple-macosX` / `-target arm64-apple-iosX` changes (deployment floor),
  - removed or renamed `public` symbols, changed signatures, new `@available(*, deprecated…)` / `unavailable`,
  - changed class hierarchy or protocol conformances (`NSObject`, `Sendable`, `Codable`),
  - new members on `SetappManager`, `SetappAIAPI`, and the `*APIProtocol` types.
- Make a list: each change → version it arrived in (when several releases are covered, check the per-tag interface files the prompt provides) → which skill it affects.

## 2. Edit the skills

Follow `CONTRIBUTING.md`. Edit only `skills/**`, `README.md`, `CHANGELOG.md` and `.claude-plugin/plugin.json` — the workflow rejects changes to anything else. In particular:

- Bump the version everywhere it's stated as current: the `Version:` line and both SPM/xcodegen `from:` pins in `setapp-framework`, the `Latest is **x.y.z** (date)` line in `setapp-ai` (date = the tag's CHANGELOG date), pitfall 7 in `setapp-framework` (`Use x.y.z (or current latest)`), and the "Verified against" line in `README.md`. The workflow runs `.github/sdk-sync/check-sync.sh` afterwards and fails if any of these, the plugin version bump, or the changelog entry is missing.
- Add every new feature to the version-floor tables in **both** skills with its minimum version.
- **Breaking changes** go in the `Breaking change in x.y.z` callouts under Step 3 of `setapp-framework`, plus a Common Pitfalls entry. Say when a break is silent (compiles but behaves differently) — those matter most.
- **Deprecations with a removal date**: put a ⚠️ callout near the top of the affected skill, a migration note in the relevant section, and a pitfall. Rewrite samples to the replacement API — never leave a sample on a deprecated call.
- New capabilities: add a short, correct snippet in the right section. Prefer selecting models by `mode` / `capabilities`, keep loops bounded and cancellable, and never hardcode model ids or URLs the SDK can provide.
- If a change touches review/submission requirements (entitlements, Info.plist, deployment target), update the Step 14 scan and the Step 15 checklist too.
- Keep existing structure, step numbering, and voice. Don't rewrite unrelated text.

## 3. Check every documented API against the published interfaces

Don't compile anything — testing the SDK is the SDK team's job. Instead, verify the documentation against the `.swiftinterface` files in `<fw>/Setapp.xcframework` (macOS slice for macOS snippets, `ios-arm64` for iOS-only ones):

- For every snippet you added or changed, list each SDK symbol it uses — types, methods with their argument labels, initializer parameters, enum cases, properties — and `grep` the interface for each one. The exact labels and parameter order must match.
- Check that nothing a snippet calls is marked `deprecated` or `unavailable` in the new interface, unless the text is explicitly about migrating away from it.
- Check that version floors you wrote are right: for each new symbol, find the first tag where it appears by grepping the per-tag interface files.
- Fix the skill until every symbol checks out. If something can't be settled from the interface (behavior, defaults, server-side limits), say so in the report rather than guessing.

## 4. Changelog and version

- Add a `## <next minor> — <today>` entry at the top of `CHANGELOG.md` in the existing style: **Breaking changes**, **Added**, **Changed**.
- Bump `version` in `.claude-plugin/plugin.json` by one minor.

## 5. Report

Write the PR description to the report path given in the prompt:

- One line: `CURRENT → TARGET`, the releases covered.
- **Time-sensitive** section first if anything has a removal date.
- Breaking changes, flagging any **not in the release notes** (found via the interface diff).
- New coverage, and other changes.
- **Verification**: which snippets were checked symbol-by-symbol against the interfaces, and anything that couldn't be. Nothing is compiled or run against a live Setapp account — say so.
- **Needs a human**: anything ambiguous or behavioral that the interfaces can't settle.

Don't commit, push, or open the PR yourself — the workflow does that.
