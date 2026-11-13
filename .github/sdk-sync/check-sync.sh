#!/usr/bin/env bash
# Fails unless every "current version" statement says TARGET and the release
# bookkeeping (plugin version bump, changelog entry, report) is in place.
#
# Usage: check-sync.sh <target-version> <base-ref> <report-path>
#   base-ref: the commit the update started from (used for the plugin version bump)
set -uo pipefail

target=$1 base=$2 report=$3
if [[ ! $target =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "FAIL  target '$target' is not x.y.z"
  exit 2
fi

fw=skills/setapp-framework/SKILL.md
ai=skills/setapp-ai/SKILL.md
fail=0
ok()  { echo "ok    $1"; }
bad() { echo "FAIL  $1"; fail=1; }
# Values below come from files the agent edited, so they are passed as
# arguments and never evaluated as shell code.
check() { local desc=$1; shift; if "$@"; then ok "$desc"; else bad "$desc"; fi; }
esc=${target//./\\.}

# setapp-framework: version line, both dependency pins, pitfall
check "$fw: Version line says $target" \
  grep -qE "^- \*\*Version:\*\* From \`$esc\`" "$fw"
pins=$(grep -cE '^[[:space:]]+from: "' "$fw")
good_pins=$(grep -cE "^[[:space:]]+from: \"$esc\"" "$fw")
check "$fw: all $pins dependency pins are $target (found $good_pins)" \
  test "$pins" -ge 2 -a "$pins" -eq "$good_pins"
check "$fw: SPM-version pitfall says $target" \
  grep -qE "Use $esc \(or current latest\)" "$fw"

# setapp-ai: current-version statement
check "$ai: 'Latest is' says $target" \
  grep -qE "Latest is \*\*$esc\*\*" "$ai"

# README
check "README.md: 'Verified against' says $target" \
  grep -qE "Verified against \*\*Setapp-framework $esc\*\*" README.md

# Plugin version strictly increased
old_pv=$(git show "$base:.claude-plugin/plugin.json" | python3 -c 'import json,sys;print(json.load(sys.stdin)["version"])')
new_pv=$(python3 -c 'import json;print(json.load(open(".claude-plugin/plugin.json"))["version"])')
higher=$(printf '%s\n%s\n' "$old_pv" "$new_pv" | sort -V | tail -1)
semver='^[0-9]+\.[0-9]+\.[0-9]+$'
bumped=false
[[ $new_pv =~ $semver && $new_pv != "$old_pv" && $higher == "$new_pv" ]] && bumped=true
check "plugin.json: version bumped ($old_pv -> $new_pv)" $bumped

# CHANGELOG: newest entry is the new plugin version and mentions the target
top=$(grep -m1 -E '^## ' CHANGELOG.md)
top_version=$(printf '%s' "$top" | awk '{print $2}')
check "CHANGELOG.md: top entry is $new_pv ($top)" \
  test "$top_version" = "$new_pv"
entry=$(awk '/^## /{n++} n==1' CHANGELOG.md)
check "CHANGELOG.md: top entry mentions $target" \
  grep -qF -- "$target" <<<"$entry"

# Report
check "report written ($report)" test -s "$report"

exit $fail
