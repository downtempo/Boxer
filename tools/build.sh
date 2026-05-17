#!/bin/bash
# Host-aware xcodebuild wrapper for Boxer.

set -euo pipefail
cd "$(dirname "$0")/.."

usage() {
  cat <<'EOF'
Usage: tools/build.sh [options] [-- extra-xcodebuild-args...]

Options:
  --scheme NAME              Xcode scheme to build (default: Boxer CI)
  --configuration NAME       Build configuration (default: Release)
  --derived-data-path PATH   DerivedData path
  --jobs N                   Override xcodebuild -jobs
  --no-parallel              Do not pass -parallelizeTargets or -jobs
  --timing                   Pass -showBuildTimingSummary
  --clean                    Run clean before build
  --no-sign                  Disable code signing for local verification builds
  --quiet                    Pass -quiet
  --dry-run                  Print the resolved xcodebuild command and exit
  --help                     Show this help

Environment:
  BOXER_XCODE_JOBS           Default job count override
  BOXER_XCODE_PARALLEL=0     Disable parallel target scheduling
  CMAKE_POLICY_VERSION_MINIMUM
                             Defaults to 3.5 for the pinned OpenEmuShaders tools
EOF
}

default_xcode_jobs() {
  if [[ -n "${BOXER_XCODE_JOBS:-}" ]]; then
    echo "$BOXER_XCODE_JOBS"
    return
  fi

  local jobs
  jobs="$(sysctl -n hw.activecpu 2>/dev/null || true)"
  if [[ -z "$jobs" ]]; then
    jobs="$(sysctl -n hw.ncpu 2>/dev/null || true)"
  fi
  if [[ -z "$jobs" ]]; then
    jobs=4
  fi
  echo "$jobs"
}

scheme="Boxer CI"
configuration="Release"
derived_data_path=""
jobs=""
parallel="${BOXER_XCODE_PARALLEL:-1}"
timing=0
clean=0
no_sign=0
quiet=0
dry_run=0
extra_args=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scheme)
      scheme="$2"
      shift 2
      ;;
    --configuration)
      configuration="$2"
      shift 2
      ;;
    --derived-data-path)
      derived_data_path="$2"
      shift 2
      ;;
    --jobs)
      jobs="$2"
      shift 2
      ;;
    --no-parallel)
      parallel=0
      shift
      ;;
    --timing)
      timing=1
      shift
      ;;
    --clean)
      clean=1
      shift
      ;;
    --no-sign)
      no_sign=1
      shift
      ;;
    --quiet)
      quiet=1
      shift
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    --)
      shift
      extra_args+=("$@")
      break
      ;;
    *)
      extra_args+=("$1")
      shift
      ;;
  esac
done

if [[ "$parallel" != "0" ]]; then
  jobs="${jobs:-$(default_xcode_jobs)}"
  if ! [[ "$jobs" =~ ^[0-9]+$ ]] || [[ "$jobs" -lt 1 ]]; then
    echo "Invalid job count: $jobs" >&2
    exit 2
  fi
fi

export CMAKE_POLICY_VERSION_MINIMUM="${CMAKE_POLICY_VERSION_MINIMUM:-3.5}"

cmd=(xcodebuild
  -workspace Boxer.xcworkspace
  -scheme "$scheme"
  -configuration "$configuration")

if [[ -n "$derived_data_path" ]]; then
  cmd+=(-derivedDataPath "$derived_data_path")
fi

if [[ "$parallel" != "0" ]]; then
  cmd+=(-parallelizeTargets -jobs "$jobs")
fi

if [[ "$timing" -eq 1 ]]; then
  cmd+=(-showBuildTimingSummary)
fi

if [[ "$quiet" -eq 1 ]]; then
  cmd+=(-quiet)
fi

if [[ "$clean" -eq 1 ]]; then
  cmd+=(clean)
fi
cmd+=(build)

if [[ "$no_sign" -eq 1 ]]; then
  cmd+=(CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO)
fi

if [[ ${#extra_args[@]} -gt 0 ]]; then
  cmd+=("${extra_args[@]}")
fi

echo "Scheme: $scheme"
echo "Configuration: $configuration"
if [[ "$parallel" != "0" ]]; then
  echo "Xcode jobs: $jobs"
else
  echo "Xcode jobs: disabled"
fi
echo "CMAKE_POLICY_VERSION_MINIMUM: $CMAKE_POLICY_VERSION_MINIMUM"

if [[ "$dry_run" -eq 1 ]]; then
  printf "Command:"
  printf " %q" "${cmd[@]}"
  printf "\n"
  exit 0
fi

exec "${cmd[@]}"
