#!/bin/bash
# bench.sh — static measurement snapshot for the Boxer modernization work.
#
# Usage:   tools/bench.sh [label]
# Output:  Markdown report on stdout (redirect to file).
#
# Designed to run in ~30s without initializing submodules or running xcodebuild.
# For full build + binary metrics, pass --build (requires submodules initialized).

set -u
cd "$(dirname "$0")/.."

LABEL="${1:-snapshot}"
WITH_BUILD=0
[[ "${1:-}" == "--build" ]] && WITH_BUILD=1

git_rev="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
git_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
git_dirty="$(git diff --quiet 2>/dev/null && echo clean || echo dirty)"
timestamp="$(date '+%Y-%m-%d %H:%M:%S %Z')"

# Directories we count as "Boxer's own source" (excluding vendored libs).
OWN_SRC=("Boxer" "Standalone" "Bundler")
VENDORED_SRC=("Other Sources/ADBToolkit" "Other Sources/RegexKitLite" \
              "Other Sources/BGHUDAppKit" "Other Sources/VDKQueue" \
              "Other Sources/YRKSpinningProgressIndicator" \
              "Other Sources/MCAdditions")

count_files() {
  local pattern="$1" ; shift
  find "$@" \( -name "$pattern" \) 2>/dev/null | wc -l | tr -d ' '
}
count_loc() {
  local pattern="$1" ; shift
  find "$@" \( -name "$pattern" \) -print0 2>/dev/null \
    | xargs -0 cat 2>/dev/null | wc -l | tr -d ' '
}
grep_count() {
  # grep_count <pattern> <path...>  → recursive count, .m/.mm/.swift/.h only
  local pat="$1" ; shift
  grep -rE --include="*.m" --include="*.mm" --include="*.swift" --include="*.h" \
       "$pat" "$@" 2>/dev/null | wc -l | tr -d ' '
}

cat <<EOF
# Boxer benchmark — $LABEL

- **timestamp:** $timestamp
- **git:** \`$git_rev\` on \`$git_branch\` ($git_dirty)
- **macOS host:** $(sw_vers -productVersion 2>/dev/null || echo unknown) / $(uname -m)

## Source size

| Scope | .m/.mm | .swift | .h | Total LoC (.m+.mm+.swift+.h+.c+.cpp) |
|-------|--------|--------|----|------|
EOF

own_m=$(count_files "*.m" "${OWN_SRC[@]}")
own_mm=$(count_files "*.mm" "${OWN_SRC[@]}")
own_swift=$(count_files "*.swift" "${OWN_SRC[@]}")
own_h=$(count_files "*.h" "${OWN_SRC[@]}")
own_loc_m=$(count_loc "*.m" "${OWN_SRC[@]}")
own_loc_mm=$(count_loc "*.mm" "${OWN_SRC[@]}")
own_loc_sw=$(count_loc "*.swift" "${OWN_SRC[@]}")
own_loc_h=$(count_loc "*.h" "${OWN_SRC[@]}")
own_total=$((own_loc_m + own_loc_mm + own_loc_sw + own_loc_h))
echo "| Boxer's own | $own_m | $own_swift | $own_h | $own_total |"

ven_m=$(count_files "*.m" "${VENDORED_SRC[@]}")
ven_mm=$(count_files "*.mm" "${VENDORED_SRC[@]}")
ven_h=$(count_files "*.h" "${VENDORED_SRC[@]}")
ven_loc_m=$(count_loc "*.m" "${VENDORED_SRC[@]}")
ven_loc_mm=$(count_loc "*.mm" "${VENDORED_SRC[@]}")
ven_loc_h=$(count_loc "*.h" "${VENDORED_SRC[@]}")
ven_total=$((ven_loc_m + ven_loc_mm + ven_loc_h))
echo "| Vendored (Other Sources) | $ven_m | 0 | $ven_h | $ven_total |"

cat <<EOF

## Deprecated / modernization markers

These counts should trend to **zero** as Bundle A lands.

| Marker | Count |
|--------|------:|
EOF

while IFS=$'\t' read -r pat label ; do
  count=$(grep_count "$pat" "${OWN_SRC[@]}" "Other Sources/ADBToolkit" 2>/dev/null || echo 0)
  printf "| %s | %s |\n" "$label" "$count"
done <<'EOF'
OSSpinLock	OSSpinLock=os_unfair_lock candidates
NSAutoreleasePool	NSAutoreleasePool=@autoreleasepool candidates
kAudioUnitSubType_DLSSynth	DLS Synth references
\<WebView\>	WebView (vs WKWebView) references
AUGraph[A-Z]	AUGraph API call references
@available\((macOS|OSX) [0-9]	@available macOS/OSX guards (all)
EOF

# @synchronized blocks (lower-priority modernization target)
sync_count=$(grep_count "@synchronized" "${OWN_SRC[@]}" "Other Sources/ADBToolkit")
echo "| @synchronized blocks | $sync_count |"

# NSInvocation usage
inv_count=$(grep_count "NSInvocation" "${OWN_SRC[@]}")
echo "| NSInvocation references | $inv_count |"

# Carbon imports
carbon_count=$(grep_count "Carbon/Carbon.h" "${OWN_SRC[@]}")
echo "| Carbon.framework imports | $carbon_count |"

# RegexKitLite usages (the OSSpinLock fix landed; full removal is a separate effort)
rkl_count=$(grep_count "RegexKitLite|stringByMatching|isMatchedByRegex" "${OWN_SRC[@]}")
echo "| RegexKitLite-using files | $rkl_count |"

cat <<EOF

## Dependencies

### Git submodules
EOF
git submodule status 2>/dev/null | awk '{print "- `" $1 "` " $2}' || echo "- (none)"

cat <<EOF

### Swift Package dependencies (from project.pbxproj)
EOF
python3 <<'PYEOF'
import re
with open('Boxer.xcodeproj/project.pbxproj') as f:
    text = f.read()
# Find each XCRemoteSwiftPackageReference block
pattern = re.compile(
    r'XCRemoteSwiftPackageReference\s*"([^"]+)"\s*\*/\s*=\s*\{[^}]*?repositoryURL\s*=\s*"?([^";]+)"?;.*?(?:requirement\s*=\s*\{(.*?)\};).*?\};',
    re.DOTALL)
seen = set()
for m in pattern.finditer(text):
    name, url, req = m.group(1), m.group(2).strip(), m.group(3)
    minv = re.search(r'minimumVersion\s*=\s*"?([^";]+)"?;', req)
    branch = re.search(r'branch\s*=\s*"?([^";]+)"?;', req)
    revision = re.search(r'revision\s*=\s*"?([^";]+)"?;', req)
    if minv: spec = "≥" + minv.group(1)
    elif branch: spec = "branch:" + branch.group(1)
    elif revision: spec = "rev:" + revision.group(1)[:8]
    else: spec = "?"
    key = (name, url, spec)
    if key in seen: continue
    seen.add(key)
    print(f"- `{name}` from {url} ({spec})")
PYEOF

cat <<EOF

## Build settings (from project.pbxproj)

| Setting | Value(s) seen |
|---------|---------------|
EOF
for key in MACOSX_DEPLOYMENT_TARGET SWIFT_VERSION ARCHS ENABLE_HARDENED_RUNTIME \
           ENABLE_APP_SANDBOX CODE_SIGN_ENTITLEMENTS MTL_LANGUAGE_REVISION ; do
  vals=$(grep -hE "^[[:space:]]*${key}[[:space:]]*=" Boxer.xcodeproj/project.pbxproj 2>/dev/null \
         | sed -E "s/^[[:space:]]+//; s/^${key}[[:space:]]*=[[:space:]]*//; s/[[:space:]]*;.*//" \
         | sort -u | paste -sd ', ' -)
  [[ -z "$vals" ]] && vals="(unset)"
  echo "| \`$key\` | $vals |"
done

cat <<EOF

## Tahoe TCC / hardened-runtime hygiene

| Check | Status |
|-------|:------:|
EOF
check_plist_key() {
  local key="$1"
  local plist="$2"
  if plutil -extract "$key" raw "$plist" >/dev/null 2>&1 ; then
    echo "✅"
  else
    echo "❌"
  fi
}
echo "| \`NSRemovableVolumesUsageDescription\` in Info.plist | $(check_plist_key NSRemovableVolumesUsageDescription Info.plist) |"
echo "| \`NSDesktopFolderUsageDescription\` in Info.plist | $(check_plist_key NSDesktopFolderUsageDescription Info.plist) |"
echo "| \`NSDocumentsFolderUsageDescription\` in Info.plist | $(check_plist_key NSDocumentsFolderUsageDescription Info.plist) |"
echo "| \`NSDownloadsFolderUsageDescription\` in Info.plist | $(check_plist_key NSDownloadsFolderUsageDescription Info.plist) |"
echo "| \`NSInputMonitoringUsageDescription\` in Info.plist | $(check_plist_key NSInputMonitoringUsageDescription Info.plist) |"
echo "| \`LSPrefersGameMode\` in Info.plist | $(check_plist_key LSPrefersGameMode Info.plist) |"

ent_size=$(wc -c < Boxer/Boxer.entitlements 2>/dev/null | tr -d ' ')
if [[ "$ent_size" -gt 200 ]] ; then ent_ok="✅" ; else ent_ok="❌ (empty/stub)" ; fi
echo "| Boxer.entitlements populated | $ent_ok |"

cat <<EOF

## Vendored framework slices

| Framework | Architectures |
|-----------|---------------|
EOF
for fw in Frameworks/SDL2.framework Frameworks/SDL2_net.framework ; do
  bin="$fw/Versions/A/$(basename $fw .framework)"
  if [[ -f "$bin" ]] ; then
    archs=$(lipo -archs "$bin" 2>/dev/null)
    size=$(du -h "$bin" 2>/dev/null | awk '{print $1}')
    echo "| \`$(basename $fw)\` | $archs ($size) |"
  fi
done

if [[ $WITH_BUILD -eq 1 ]] ; then
  cat <<EOF

## Build (xcodebuild)

EOF
  build_log=$(mktemp)
  if xcodebuild -workspace Boxer.xcworkspace -scheme Boxer -configuration Release \
                -derivedDataPath ./build/bench-derived clean build \
                CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO \
                > "$build_log" 2>&1 ; then
    echo "- **Status:** ✅ built clean"
  else
    echo "- **Status:** ❌ build failed (see log)"
  fi
  warn=$(grep -cE "warning:" "$build_log" 2>/dev/null || echo 0)
  err=$(grep -cE "error:" "$build_log" 2>/dev/null || echo 0)
  echo "- **Warnings:** $warn"
  echo "- **Errors:** $err"
  if [[ -d "build/bench-derived/Build/Products/Release/Boxer.app" ]] ; then
    bundle_size=$(du -sh "build/bench-derived/Build/Products/Release/Boxer.app" | awk '{print $1}')
    bin_archs=$(lipo -archs "build/bench-derived/Build/Products/Release/Boxer.app/Contents/MacOS/Boxer" 2>/dev/null)
    echo "- **Bundle size:** $bundle_size"
    echo "- **Binary architectures:** $bin_archs"
  fi
  rm -f "$build_log"
fi

cat <<EOF

---

_Generated by \`tools/bench.sh\`._
EOF
