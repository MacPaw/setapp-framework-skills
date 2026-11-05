# Keeping the skills in step with Setapp-framework

The skills document a specific Setapp-framework version. When a newer one ships, a Claude agent updates them and opens a PR here for review.

## How it runs

The workflow lives in the private **`MacPaw/setapp-ios`** repo (`.github/workflows/setapp-skills-sync.yml`), not here, so the Anthropic API key never touches this public repo. The framework's release pipeline calls it after the new version is deployed to the public `MacPaw/Setapp-framework` repo. It:

1. checks out this repo with a GitHub App token, and stops if the skills already document that version or an `sdk-sync/*` PR is still open;
2. fetches the framework and diffs the CHANGELOG **and** the published `.swiftinterface` files between the documented and the new version — release notes aren't exhaustive;
3. runs Claude with [`agent-instructions.md`](agent-instructions.md): update both skills, README, CHANGELOG and plugin version, and check every documented API against the interfaces (nothing is compiled — testing the SDK is the SDK team's job);
4. runs [`check-sync.sh`](check-sync.sh), which fails unless every current-version statement, both dependency pins, the plugin version bump and the CHANGELOG entry are in place;
5. opens a PR on branch `sdk-sync/<version>`, labelled `sdk-sync`, with the agent's report as the description.

## Reviewing an `sdk-sync` PR

Read the report rather than the whole diff:

- breaking changes, especially any marked **not in the release notes**;
- anything under **Needs a human**;
- whether the new examples make sense for a real app.

Push fixes to the same branch, or ask for changes and re-run the workflow by hand from `setapp-ios` (Actions → *Sync Setapp skills* → *Run workflow*, with the version).

## Running it by hand

Without the pipeline, run Claude in a clone of this repo with:

```
Update the Setapp skills from Setapp-framework <current> to <new>. Follow .github/sdk-sync/agent-instructions.md:
clone MacPaw/Setapp-framework, check out <new>, and make the CHANGELOG and .swiftinterface diffs yourself.
Write the report outside the repo, then open a PR with it as the description.
```

Check the result with:

```bash
bash .github/sdk-sync/check-sync.sh <new-version> origin/main <path-to-report.md>
```
