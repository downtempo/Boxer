#!/bin/bash
# Run a topic branch through a managed macos26 integration worktree.

set -euo pipefail

INVOCATION_PWD="$(pwd -P)"
cd "$(dirname "$0")/.."
REPO_ROOT="$(pwd -P)"

usage() {
  cat <<'EOF'
Usage: tools/premerge-check.sh [options] [topic-ref] [-- extra-build-args...]

Runs a trial merge of topic-ref into a managed macos26 integration worktree,
then runs the static benchmark snapshot and the requested build there.

If topic-ref is omitted, the current branch is used. The current branch must be
committed cleanly because this script merges refs, not uncommitted working-tree
changes.

Options:
  --base REF                 Integration base branch (default: macos26)
  --remote NAME              Remote used for fresh base fetch (default: origin)
  --no-fetch                 Use the local base ref without fetching
  --worktree PATH            Managed integration worktree path
  --artifacts-dir PATH       Directory for generated bench artifacts
  --label LABEL              Label passed to tools/bench.sh
  --scheme NAME              Xcode scheme to build (default: Boxer Bundler)
  --configuration NAME       Build configuration (default: Release)
  --no-build                 Skip tools/build.sh
  --no-bench                 Skip tools/bench.sh
  --no-timing                Do not pass --timing to tools/build.sh
  --deep-clean-shaders       Deep-clean ignored OpenEmuShaders build artifacts
  --reset-managed            Reset a dirty managed worktree before starting
  --keep-merge               Leave the trial merge in place after success
  --help                     Show this help

Environment:
  BOXER_PREMERGE_WORKTREE    Default worktree path override
  BOXER_PREMERGE_ARTIFACTS   Default artifact directory override

Relative worktree and artifact paths resolve from the invocation directory.
EOF
}

die() {
  echo "error: $*" >&2
  exit 2
}

absolute_path() {
  local path="$1"
  local base="${2:-$PWD}"
  local full_path
  local path_dir
  local path_name

  case "$path" in
    /*) full_path="$path" ;;
    *) full_path="$base/$path" ;;
  esac

  path_dir="$(dirname "$full_path")"
  path_name="$(basename "$full_path")"
  if [[ -d "$path_dir" ]]; then
    printf "%s/%s\n" "$(cd "$path_dir" && pwd -P)" "$path_name"
  else
    printf "%s\n" "$full_path"
  fi
}

git_dir_for() {
  local path="$1"
  local git_dir
  git_dir="$(git -C "$path" rev-parse --git-dir)"
  case "$git_dir" in
    /*) printf "%s\n" "$git_dir" ;;
    *) printf "%s/%s\n" "$path" "$git_dir" ;;
  esac
}

marker_for() {
  local path="$1"
  printf "%s/boxer-premerge-check-managed\n" "$(git_dir_for "$path")"
}

managed_worktree_ready() {
  local path="$1"
  [[ -d "$path" ]] || return 1
  git -C "$path" rev-parse --show-toplevel >/dev/null 2>&1 || return 1
  [[ -f "$(marker_for "$path")" ]]
}

ensure_same_repository() {
  local path="$1"
  local root_common
  local worktree_common

  root_common="$(cd "$(git rev-parse --git-common-dir)" && pwd -P)"
  worktree_common="$(git -C "$path" rev-parse --git-common-dir)"
  case "$worktree_common" in
    /*) ;;
    *) worktree_common="$path/$worktree_common" ;;
  esac
  worktree_common="$(cd "$worktree_common" && pwd -P)"

  [[ "$root_common" == "$worktree_common" ]] ||
    die "$path is not a worktree for this repository"
}

sync_submodules() {
  local path="$1"
  git -C "$path" submodule sync --recursive
  git -C "$path" submodule update --init --recursive
}

deep_clean_shaders() {
  local path="$1"
  local shader_path

  for shader_path in \
    Vendor/OpenEmuShaders \
    Vendor/OpenEmuShaders/3rdparty/SPIRV-Cross \
    Vendor/OpenEmuShaders/3rdparty/SPIRV-Tools \
    Vendor/OpenEmuShaders/3rdparty/glslang
  do
    if git -C "$path/$shader_path" rev-parse --show-toplevel >/dev/null 2>&1; then
      git -C "$path/$shader_path" reset --hard
      git -C "$path/$shader_path" clean -ffdx
    fi
  done
}

cleanup_managed_worktree() {
  local path="$1"
  local base_ref="$2"

  managed_worktree_ready "$path" ||
    die "refusing to reset unmanaged worktree $path"

  git -C "$path" merge --abort >/dev/null 2>&1 || true
  git -C "$path" reset --hard "$base_ref"
  git -C "$path" clean -ffd
  sync_submodules "$path"
}

BASE="macos26"
REMOTE="origin"
FETCH=1
RUN_BUILD=1
RUN_BENCH=1
TIMING=1
DEEP_CLEAN_SHADERS=0
RESET_MANAGED=0
KEEP_MERGE=0
WORKTREE="${BOXER_PREMERGE_WORKTREE:-}"
ARTIFACTS_DIR="${BOXER_PREMERGE_ARTIFACTS:-}"
LABEL=""
SCHEME="Boxer Bundler"
CONFIGURATION="Release"
TOPIC=""
EXTRA_BUILD_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)
      BASE="$2"
      shift 2
      ;;
    --remote)
      REMOTE="$2"
      shift 2
      ;;
    --no-fetch)
      FETCH=0
      shift
      ;;
    --worktree)
      WORKTREE="$2"
      shift 2
      ;;
    --artifacts-dir)
      ARTIFACTS_DIR="$2"
      shift 2
      ;;
    --label)
      LABEL="$2"
      shift 2
      ;;
    --scheme)
      SCHEME="$2"
      shift 2
      ;;
    --configuration)
      CONFIGURATION="$2"
      shift 2
      ;;
    --no-build)
      RUN_BUILD=0
      shift
      ;;
    --no-bench)
      RUN_BENCH=0
      shift
      ;;
    --no-timing)
      TIMING=0
      shift
      ;;
    --deep-clean-shaders)
      DEEP_CLEAN_SHADERS=1
      shift
      ;;
    --reset-managed)
      RESET_MANAGED=1
      shift
      ;;
    --keep-merge)
      KEEP_MERGE=1
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    --)
      shift
      EXTRA_BUILD_ARGS+=("$@")
      break
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      if [[ -n "$TOPIC" ]]; then
        die "only one topic ref may be provided"
      fi
      TOPIC="$1"
      shift
      ;;
  esac
done

CURRENT_BRANCH="$(git branch --show-current)"
if [[ -z "$TOPIC" ]]; then
  [[ -n "$CURRENT_BRANCH" ]] ||
    die "topic-ref is required from detached HEAD"
  [[ "$CURRENT_BRANCH" != "$BASE" ]] ||
    die "current branch is the integration base; pass a topic-ref explicitly"
  TOPIC="$CURRENT_BRANCH"
fi

if [[ "$TOPIC" == "$CURRENT_BRANCH" ]]; then
  git diff --quiet ||
    die "current branch has uncommitted working-tree changes"
  git diff --cached --quiet ||
    die "current branch has staged changes"
fi

git rev-parse --verify "$TOPIC^{commit}" >/dev/null 2>&1 ||
  die "topic ref not found: $TOPIC"

if [[ "$FETCH" -eq 1 ]]; then
  git fetch "$REMOTE" "$BASE"
  BASE_REF="FETCH_HEAD"
else
  if git rev-parse --verify "$REMOTE/$BASE^{commit}" >/dev/null 2>&1; then
    BASE_REF="$REMOTE/$BASE"
  else
    BASE_REF="$BASE"
  fi
fi
BASE_CANDIDATE="$BASE_REF"
if ! BASE_REF="$(git rev-parse --verify "$BASE_CANDIDATE^{commit}" 2>/dev/null)"; then
  die "base ref not found: $BASE_CANDIDATE"
fi

if [[ -z "$WORKTREE" ]]; then
  WORKTREE="$(dirname "$REPO_ROOT")/$(basename "$REPO_ROOT")-premerge-integration"
fi
WORKTREE="$(absolute_path "$WORKTREE" "$INVOCATION_PWD")"

if [[ -z "$ARTIFACTS_DIR" ]]; then
  ARTIFACTS_DIR="${TMPDIR:-/tmp}/boxer-premerge-artifacts"
fi
ARTIFACTS_DIR="$(absolute_path "$ARTIFACTS_DIR" "$INVOCATION_PWD")"
mkdir -p "$ARTIFACTS_DIR"

if [[ -e "$WORKTREE" && ! -d "$WORKTREE" ]]; then
  die "$WORKTREE exists and is not a directory"
fi

if [[ -d "$WORKTREE" ]]; then
  managed_worktree_ready "$WORKTREE" ||
    die "refusing to use unmanaged worktree path: $WORKTREE"
  ensure_same_repository "$WORKTREE"

  if [[ -n "$(git -C "$WORKTREE" status --porcelain)" ]]; then
    [[ "$RESET_MANAGED" -eq 1 ]] ||
      die "$WORKTREE is dirty; inspect it or rerun with --reset-managed"
    cleanup_managed_worktree "$WORKTREE" "$BASE_REF"
  fi
else
  git worktree prune
  git worktree add --detach "$WORKTREE" "$BASE_REF"
  printf "%s\n" "$REPO_ROOT" >"$(marker_for "$WORKTREE")"
fi

ensure_same_repository "$WORKTREE"
git -C "$WORKTREE" reset --hard "$BASE_REF"
git -C "$WORKTREE" clean -ffd
sync_submodules "$WORKTREE"

if [[ "$DEEP_CLEAN_SHADERS" -eq 1 ]]; then
  deep_clean_shaders "$WORKTREE"
  sync_submodules "$WORKTREE"
fi

echo "Integration worktree: $WORKTREE"
echo "Base: $BASE_REF"
echo "Topic: $TOPIC"

if ! git -C "$WORKTREE" merge --no-commit --no-ff "$TOPIC"; then
  git -C "$WORKTREE" merge --abort >/dev/null 2>&1 || true
  die "trial merge failed"
fi

sync_submodules "$WORKTREE"

SAFE_TOPIC="$(printf "%s" "$TOPIC" | tr -c 'A-Za-z0-9._-' '-')"
STAMP="$(date '+%Y%m%d-%H%M%S')"
BENCH_FILE="$ARTIFACTS_DIR/$STAMP-$SAFE_TOPIC-bench.md"

if [[ -z "$LABEL" ]]; then
  LABEL="premerge $TOPIC into $BASE"
fi

if [[ "$RUN_BENCH" -eq 1 ]]; then
  (cd "$WORKTREE" && tools/bench.sh "$LABEL" >"$BENCH_FILE")
  echo "Bench artifact: $BENCH_FILE"
fi

if [[ "$RUN_BUILD" -eq 1 ]]; then
  BUILD_CMD=(tools/build.sh --scheme "$SCHEME" --configuration "$CONFIGURATION")
  if [[ "$TIMING" -eq 1 ]]; then
    BUILD_CMD+=(--timing)
  fi
  if [[ ${#EXTRA_BUILD_ARGS[@]} -gt 0 ]]; then
    BUILD_CMD+=("${EXTRA_BUILD_ARGS[@]}")
  fi
  (cd "$WORKTREE" && "${BUILD_CMD[@]}")
fi

if [[ "$KEEP_MERGE" -eq 1 ]]; then
  echo "Trial merge left in place: $WORKTREE"
else
  cleanup_managed_worktree "$WORKTREE" "$BASE_REF"
  echo "Trial merge cleaned up."
fi

echo "Pre-merge check succeeded."
