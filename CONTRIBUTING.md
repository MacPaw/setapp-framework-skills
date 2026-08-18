# Contributing

These skills are only as good as the pitfalls they encode. If you hit something the checklist missed, that's the highest-value contribution.

## License

This repository is [Apache License 2.0](LICENSE). By submitting a pull request, you agree your contribution is licensed under the same terms (Apache-2.0 §5, "Submission of Contributions") — no separate agreement needed. Merging is at MacPaw's discretion; rejected changes remain yours to keep in your own fork.

## What to change

- **A new pitfall** — add it to the relevant `## Common Pitfalls` list and, if it belongs in the flow, to the matching step.
- **An SDK change** — update the affected step and note the minimum `Setapp-framework` version that introduced it.
- **A review-guideline change** — update the scan patterns in Step 14 and the checklist in Step 15 of `setapp-framework`.

## Conventions

- One skill per folder under `skills/`, containing a single `SKILL.md`.
- Frontmatter carries exactly two keys, `name` and `description`. The `name` must match the folder name. The `description` is what an agent matches against, so it should name concrete trigger phrases — that's what makes the skill fire on the right prompt.
- Keep `SKILL.md` addressed to the agent: imperative steps, verifiable checks, real code. Human-facing prose belongs in `docs/`.
- Say the version. "Requires 5.3.3+" saves someone a compile error that reads like a typo.
- Prefer a short, correct snippet over a long, illustrative one.

## Before opening a PR

- Verify the change against a real integration — these steps are claims about behavior, not style preferences.
- Check the cross-references still hold: `setapp-framework` points forward to `setapp-ai`, and `setapp-ai` states the framework prerequisite.
- Bump `version` in `.claude-plugin/plugin.json` for anything users would want to pull.
