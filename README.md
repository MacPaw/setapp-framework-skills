# Setapp Skills

Agent skills that walk an AI coding assistant — Claude Code, Cursor, Codex, or anything else that reads `SKILL.md` files — through shipping a macOS app on [Setapp](https://setapp.com).

Two skills, in order:

| Skill | What it does | Phase |
|---|---|---|
| [`setapp-framework`](skills/setapp-framework/SKILL.md) | Integrates the Setapp Framework: separate Xcode target, SPM dependency, `Info.plist`, sandbox entitlements, usage reporting, archive packaging, and a pre-submission compliance scan. | 1 — required |
| [`setapp-ai`](skills/setapp-ai/SKILL.md) | Adds Setapp AI+: OAuth config, model discovery, text streaming, conversation context, image generation and editing, audio transcription, video generation, credit balances, and the gateway error contract. | 2 — optional |

`setapp-ai` assumes `setapp-framework` is already done.

> Verified against **Setapp-framework 5.3.6** and the Setapp docs as of **18 August 2026**. Both skills carry version-floor tables; check [releases](https://github.com/MacPaw/Setapp-framework/releases) if you're on a newer SDK.

## Why use these

Setapp integration has a handful of failure modes that cost hours if you hit them blind — the wrong Mach service name in the sandbox entitlement, `xcodegen` silently overwriting your `Info.plist`, calling `SetappManager.shared.start()` on macOS where it doesn't exist, the standalone icon PNG that must sit *next to* the `.app` in the archive. These skills encode the fixes, plus a review-compliance scan that catches the code patterns Setapp rejects (IAP, ad SDKs, Sparkle, custom licensing) before you submit.

## Install

### Claude Code — as a plugin (recommended)

```bash
claude plugin marketplace add MacPaw/setapp-framework-skills
```

```bash
claude plugin install setapp-skills@setapp
```

Updates arrive with `claude plugin update setapp-skills`.

### Claude Code — manual

Copy the skill folders into your skills directory. Use `~/.claude/skills/` for every project, or `.claude/skills/` inside one repo.

```bash
git clone https://github.com/MacPaw/setapp-framework-skills.git
cp -R setapp-framework-skills/skills/* ~/.claude/skills/
```

### Other agents

Each skill is a single self-contained Markdown file with YAML frontmatter. Point your tool at `skills/<name>/SKILL.md`, or paste its contents into the conversation.

## Use

Describe what you want in plain language — the skills trigger on intent, not on a command:

- *"I want to publish my app on Setapp"*
- *"Add the Setapp SDK to my Xcode project"*
- *"Run the Setapp review compliance scan on this codebase"*
- *"I'm getting 'This copy requires an active Setapp account' — help me fix it"*
- *"Add Setapp AI+ streaming to my app"*

The framework skill first scans your project to see what's already in place and skips those steps, so it's safe to run against a half-finished integration. You can also jump to one step: *"just check my sandbox entitlements."*

Longer walkthrough: [docs/setapp-framework-guide.md](docs/setapp-framework-guide.md).

## What the agent can't do for you

Some steps need a human in an external system. The skills stop and tell you when you reach one:

- Downloading `setappPublicKey.pem` from the [developer portal](https://developer.setapp.com/applications)
- Registering your bundle ID in the portal (permanent — you can't change it later)
- Signing with a Developer ID certificate, and notarizing with Apple

## Repository layout

```
skills/
  setapp-framework/SKILL.md   Phase 1 — licensing, activation, submission prep
  setapp-ai/SKILL.md          Phase 2 — Setapp AI+
docs/
  setapp-framework-guide.md   Human-facing walkthrough of the framework skill
.claude-plugin/
  plugin.json                 Claude Code plugin manifest
  marketplace.json            Makes this repo installable as a marketplace
LICENSE                       Apache License 2.0
```

## License

[Apache License 2.0](LICENSE), copyright MacPaw Way Ltd. Use, modify, and redistribute the skills freely, including republishing a modified copy elsewhere. By opening a pull request against this repository you license your contribution under the same terms — see [CONTRIBUTING.md](CONTRIBUTING.md).

## Contributing

Skills go stale when the SDK or the review guidelines move. If you hit a pitfall that isn't covered, please open a PR — see [CONTRIBUTING.md](CONTRIBUTING.md).

## Reference

- [Setapp developer docs](https://docs.setapp.com) — append `.md` to any docs URL for agent-readable Markdown, and see [`llms.txt`](https://docs.setapp.com/llms.txt) for the full page index
- [Setapp AI Swift SDK guide](https://docs.setapp.com/docs/setapp-ai-sdk-integration)
- [Setapp review guidelines](https://docs.setapp.com/docs/review-guidelines)
- [Setapp-framework releases](https://github.com/MacPaw/Setapp-framework/releases)
- [Developer portal](https://developer.setapp.com)
