#!/bin/bash
# Check that shared fork scaffolding is identical across long-lived branches.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: tools/check-scaffolding-sync.sh [canonical-ref] [branch-ref...]

Compares shared scaffolding and docs files from canonical-ref to each branch-ref.
Defaults:
  canonical-ref: origin/maddsV2
  branch-ref:    origin/macos11 origin/macos26

Run after merging scaffolding changes forward from maddsV2 to macos11 and macos26.
EOF
}

if [[ "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

CANONICAL="${1:-origin/maddsV2}"
if [[ $# -gt 0 ]]; then
  shift
fi

if [[ $# -gt 0 ]]; then
  BRANCHES=("$@")
else
  BRANCHES=(origin/macos11 origin/macos26)
fi

FILES=(
  .gitignore
  AGENTS.md
  CLAUDE.md
  GEMINI.md
  docs/modernization-plan.md
  docs/upstream-proposals.md
  tools/bench.sh
  tools/build.sh
  tools/check-scaffolding-sync.sh
  tools/git-hooks/commit-msg
  tools/git-hooks/pre-commit
  tools/premerge-check.sh
  tools/setup-git-hooks.sh
)

git rev-parse --verify "$CANONICAL^{commit}" >/dev/null

STATUS=0
for branch in "${BRANCHES[@]}"; do
  git rev-parse --verify "$branch^{commit}" >/dev/null
  if git diff --quiet "$CANONICAL" "$branch" -- "${FILES[@]}"; then
    echo "OK: $branch matches $CANONICAL scaffolding"
  else
    echo "OUT OF SYNC: $branch differs from $CANONICAL" >&2
    git diff --name-status "$CANONICAL" "$branch" -- "${FILES[@]}" >&2
    STATUS=1
  fi
done

exit "$STATUS"
