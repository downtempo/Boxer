#!/bin/bash
# Regression tests for tools/git-hooks/commit-msg.
#
# This hook is the reference implementation other repositories copy, so a
# defect here propagates. It previously enumerated ten AI vendor names, which
# blocked Claude and Gemini while letting GPT-5, Llama, and every other
# unlisted model through. These probes fix the current behavior in place so
# the check cannot quietly regress to a name list.
#
# Run: ./tools/test-git-hooks.sh

set -u

hook="$(cd "$(dirname "$0")" && pwd)/git-hooks/commit-msg"
[[ -x "$hook" ]] || { echo "not executable: $hook" >&2; exit 1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
failures=0

# probe <name> <expected-exit> <message> [env assignment]
probe() {
  local name="$1" want="$2" message="$3" override="${4:-}"
  printf '%s\n' "$message" > "$work/msg"
  local got=0
  if [[ -n "$override" ]] ; then
    env "$override" bash "$hook" "$work/msg" >/dev/null 2>&1 || got=$?
  else
    bash "$hook" "$work/msg" >/dev/null 2>&1 || got=$?
  fi
  if [[ "$got" -eq "$want" ]] ; then
    printf '  [OK]   %s\n' "$name"
  else
    printf '  [FAIL] %s: exit %s, wanted %s\n' "$name" "$got" "$want" >&2
    failures=$((failures + 1))
  fi
}

echo "commit-msg hook probes"

# Co-authored-by is reserved for humans. The shape must be matched, not the
# vendor: every name below except Claude passed the old enumeration.
probe "rejects Claude trailer"            1 $'fix: a change\n\nCo-Authored-By: Claude <noreply@anthropic.com>'
probe "rejects GPT-5 trailer"             1 $'fix: a change\n\nCo-authored-by: GPT-5 <bot@example.test>'
probe "rejects Llama trailer"             1 $'fix: a change\n\nCo-authored-by: Llama <someone@example.test>'
probe "rejects Mistral trailer"           1 $'fix: a change\n\nCo-authored-by: Mistral <someone@example.test>'
probe "rejects underscore variant"        1 $'fix: a change\n\nco_authored_by: Some Model <someone@example.test>'
probe "rejects unnamed trailer"           1 $'fix: a change\n\nCo-authored-by: Anonymous <someone@example.test>'
probe "allows human coauthor override"    0 $'fix: a change\n\nCo-authored-by: A Human <human@example.test>' "ALLOW_COAUTHOR=1"

# Boilerplate and subject prefixes.
probe "rejects generated-with boilerplate" 1 $'fix: a change\n\nGenerated with Claude Code'
probe "rejects AI subject prefix"          1 $'Claude: do a thing'

# Assisted-by format.
probe "accepts well-formed Assisted-by"   0 $'fix: a change\n\nAssisted-by: Claude Code (claude-fable-5)'
probe "rejects Assisted-by without model" 1 $'fix: a change\n\nAssisted-by: Claude Code'

# Em-dash rule.
probe "rejects an em-dash"                1 $'fix: a change—with an em-dash'

# Ordinary commits still pass.
probe "accepts a plain commit"            0 $'fix: a change'

if [[ "$failures" -ne 0 ]] ; then
  echo "$failures probe(s) failed" >&2
  exit 1
fi
echo "all commit-msg hook probes behaved as expected"
