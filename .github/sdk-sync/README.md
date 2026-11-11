# Keeping the skills in step with Setapp-framework

The skills document a specific Setapp-framework version. When a newer one ships, a Claude agent updates them and opens a PR here for review.

## How it runs

[`.github/workflows/sdk-sync.yml`](../workflows/sdk-sync.yml) runs daily and on demand (Actions → *SDK sync* → *Run workflow*, optionally with a version). It has three jobs:

1. **`detect`** reads the documented version and the latest public `MacPaw/Setapp-framework` tag. It stops if the skills are already current or an `sdk-sync/*` PR is still open.
2. **`agent`** pre-extracts the CHANGELOG diff, the `.swiftinterface` diff and the per-tag interface files, then runs Claude with [`agent-instructions.md`](agent-instructions.md). It uploads the resulting patch and report as a one-day artifact.
3. **`publish`** applies the patch to a fresh checkout of `main` and runs [`check-sync.sh`](check-sync.sh), which fails unless every current-version statement, both dependency pins, the plugin version bump and the CHANGELOG entry are in place. Then it opens a signed PR on branch `sdk-sync/<version>`, labelled `sdk-sync`, with the agent's report as the description.

## How the key is protected

This repo is public, so the setup keeps the Anthropic key away from anything outside `main`:

- **Environment.** `ANTHROPIC_API_KEY` is a secret of the `sdk-sync` environment, not a repository secret. The environment accepts deployments from `main` only, and only the `agent` job uses it. The key is a dedicated one with a spend limit. SRE manages the environment and the secret (Vault → vault-fusion) in `MacPaw/ops-macpaw-io`.
- **Triggers.** Only `schedule` (runs from `main`) and `workflow_dispatch` (needs write access). There is no `pull_request`, `pull_request_target` or `issue_comment` trigger, and workflow runs from forks need maintainer approval.
- **Tokens.** The default `GITHUB_TOKEN` is read-only. `agent` gets `contents: read` and checks out with `persist-credentials: false`. Only `publish` can write, and it never sees the key.
- **Agent.** It may use only `Read`, `Glob`, `Grep`, `Edit` and `Write`: no `Bash`, no web access, no reads under `/proc`. Its output is untrusted, so:
  - the run fails if the agent changed anything outside `skills/**`, `README.md`, `CHANGELOG.md` and `.claude-plugin/plugin.json`;
  - `publish` rejects executables, symlinks and submodules, and runs the copy of `check-sync.sh` it took from `main` before applying the patch;
  - the patch and the report are scanned for the key before upload (the artifact and the logs are public), then again for any `sk-ant-` key before the PR opens;
  - versions must match `^[0-9]+\.[0-9]+\.[0-9]+$`.

Commits go through the GitHub API (`sign-commits`), because the org requires signed commits on every branch.

## Reviewing an `sdk-sync` PR

Review the full diff, not only the report. Close the PR if it touches anything outside `skills/**`, `README.md`, `CHANGELOG.md` and `.claude-plugin/plugin.json`: a new `.mcp.json`, hook, agent or command would ship to everyone who installs the plugin.

Then check the report for:

- breaking changes, especially any marked **not in the release notes**;
- anything under **Needs a human**;
- whether the new examples make sense for a real app.

Push fixes to the same branch, or close the PR and run the workflow again by hand with the version.

## Running it by hand

Without the workflow, run Claude in a clone of this repo with:

```
Update the Setapp skills from Setapp-framework <current> to <new>. Follow .github/sdk-sync/agent-instructions.md:
clone MacPaw/Setapp-framework, check out <new>, and make the CHANGELOG and .swiftinterface diffs yourself.
Write the report outside the repo, then open a PR with it as the description.
```

Check the result with:

```bash
bash .github/sdk-sync/check-sync.sh <new-version> origin/main <path-to-report.md>
```
