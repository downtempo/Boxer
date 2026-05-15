#!/bin/bash
# Configures this repo to use the version-controlled hooks in tools/git-hooks/.
# Run once after cloning, and again if a contributor reports the hooks aren't firing.

set -eu
cd "$(dirname "$0")/.."

if [[ ! -d .git ]] && [[ ! -f .git ]] ; then
  echo "Run this from inside the repo (or a worktree)." >&2
  exit 1
fi

find tools/git-hooks -type f -not -name '.*' -exec chmod +x {} +

# core.hooksPath points git at our versioned hooks directory.
# This is per-repo, not global. Worktrees inherit it.
git config core.hooksPath tools/git-hooks

echo "Git hooks installed (core.hooksPath = tools/git-hooks)."
echo "Active hooks:"
ls -1 tools/git-hooks
