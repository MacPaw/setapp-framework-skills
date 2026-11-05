# Keeping the skills in step with Setapp-framework

The skills document a specific Setapp-framework version. When a newer one ships, a Claude agent updates them and opens a PR here for review.

## How it runs

[`.github/workflows/sdk-sync.yml`](../workflows/sdk-sync.yml) runs daily, on demand from the Actions tab, or from a `repository_dispatch` sent by the framework's release pipeline. It:

1. compares the version the skills document with the newest framework tag, and stops if the skills are current or an `sdk-sync/*` PR is still open;
2. fetches the framework and diffs the CHANGELOG **and** the published `.swiftinterface` files between the two versions — release notes aren't exhaustive;
3. runs Claude with [`agent-instructions.md`](agent-instructions.md): update both skills, README, CHANGELOG and plugin version, and check every documented API against the interfaces (nothing is compiled — testing the SDK is the SDK team's job);
4. runs [`check-sync.sh`](check-sync.sh), which fails unless every current-version statement, both dependency pins, the plugin version bump and the CHANGELOG entry are in place, then checks that the Anthropic key doesn't appear in the changes or the report;
5. opens a PR on branch `sdk-sync/<version>`, labelled `sdk-sync`, with the agent's report as the description.

## Security

- **Only maintainers can start it.** `schedule` runs from `main`; `workflow_dispatch` and `repository_dispatch` need write access. There is no `pull_request` or `pull_request_target` trigger, so PRs and forks never run it, and changes to the workflow only take effect after a maintainer merges them.
- **The key is scoped.** `ANTHROPIC_API_KEY` is a dedicated key with a spend limit, stored in the `sdk-sync` environment, which only `main` can deploy to.
- **The agent's tools are narrow.** It can edit files, use read-only git, `grep`/`sed`/`ls`/`cat`, and run `check-sync.sh` — no Python, no commit or push. Its inputs are this repo's `main` and MacPaw's own framework releases. As a backstop, the workflow scans every changed file and the PR description for the key and refuses to open the PR if it appears.

## Reviewing an `sdk-sync` PR

Read the report rather than the whole diff:

- breaking changes, especially any marked **not in the release notes**;
- anything under **Needs a human**;
- whether the new examples make sense for a real app.

Push fixes to the same branch, or close the PR and re-run the workflow from the Actions tab (*SDK sync* → *Run workflow*).

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
