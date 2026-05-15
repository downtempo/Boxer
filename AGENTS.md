# AGENTS.md

Guidance for AI coding assistants (Claude Code, OpenAI Codex, Cursor, etc.) working in this fork of Boxer. Keep PRs homogeneous, commits cherry-pickable upstream, and reviews fast.

> This file documents Boxer-specific rules. It is intentionally self-sufficient: an agent that only sees this file (no personal AGENTS.md) should still have everything it needs to do correct work in this repo. The developer also maintains a personal AGENTS.md with general agent conventions across projects; rules below restate the load-bearing personal conventions for this repo's convenience.

## Read first

The modernization plan lives in `docs/modernization-plan.md`.

If that file is missing in this checkout, stop and ask the developer for the active plan item before editing. The plan is the source of truth for assigned work. Each work item is tagged:

- 🟢 **Upstreamable**: write the change as if you are filing an upstream PR. Commit message and code style should make sense to the upstream maintainer with no awareness of this fork.
- 🔴 **Fork-specific** (narrowing to macOS 26 + Apple Silicon): land after the 🟢 items on a branch so a cherry-pick range can exclude them.
- 🔒 **Security fix**: prioritize and follow the security-item rules below.

Always ask the developer if scope is unclear. Do not improvise additional changes outside the assigned plan item.

## Before editing

At the start of every task, identify:

- Active plan item ID.
- Tag: upstreamable, fork-specific, or security.
- Expected files.
- Files that are out of scope.
- Required verification.

If there is no active plan item, stop and ask for one. Do not scan for unrelated work.

## Security items

For security items:

- Use a dedicated branch and commit.
- Do not combine security fixes with cleanup, runtime tuning, or modernization work.
- Reproduce the issue from current code before patching.
- Keep the fix minimal.
- Add the smallest feasible regression fixture or manual reproduction note.
- Avoid sensational exploit language in commit messages and PR titles.
- Tell the developer if the issue appears broader than the assigned item.

## Project conventions

- Languages: Objective-C, Objective-C++, Swift 5.0 (Swift 6 migration is a planned item; do not pre-emptively rewrite).
- 4-space indentation. Match the surrounding file's brace style.
- Objective-C calls use square brackets: `[obj method:arg]`. Do not introduce dot-syntax for non-property method calls.
- Nullability annotations: use `NS_ASSUME_NONNULL_BEGIN` / `END` if the file already has them. Do not add to files that do not.
- No emojis in code, comments, or commit messages. Emoji tags (🟢 🔴 🔒) live only in this file and the plan doc.
- Do not use em-dashes (Unicode U+2014) in commit messages, PR titles, PR descriptions, newly written project documentation, or chat output back to the developer. Use commas, colons, periods, or parentheses instead. Do not rewrite existing text solely to remove them.

## File header conventions

### When modifying an existing file

Preserve the existing header exactly. Do not change copyright years, authors, or license text. The file's existing copyright stays accurate because each contributor retains rights to their own contributions, and the "Alun Bestor and contributors" umbrella already covers everyone who has touched the file.

The four existing header styles you will encounter:

| Directory | Existing style | Notes |
|-----------|---------------|-------|
| `Boxer/`, `Standalone/`, older `.m` / `.mm` / `.h` files | GPL 2.0 block, 2013 Alun Bestor copyright | Most numerous |
| `Other Sources/ADBToolkit/`, older files | BSD 2-clause block with asterisks, 2013 Alun Bestor copyright | Different license from main project |
| Recent Swift and Metal Rendering files | Xcode-default `//` style with `Created by` line, `Copyright © <year> Alun Bestor and contributors` | The current de facto pattern for new work |
| `Other Sources/RegexKitLite/`, vendored libs, OpenEmu shader code | Upstream's own header | Preserve verbatim |

### When creating a new file

The current de facto pattern for new files (regardless of language) is the Xcode-default style with full copyright attribution, following the precedent C.W. Betts established for recent Swift additions (`CoverArt.swift`, `MT32LCDDisplay.swift`, etc.) and the partial pattern from Stuart Carnie's Metal Rendering files. Use this template:

```objc
//
//  <Filename>.<ext>
//  <Boxer | Boxer Standalone | Boxer Bundler | ADBToolkit>
//
//  Created by <Your Name> on <date>.
//  Copyright © <current year> Alun Bestor and contributors. All rights reserved.
//
```

Same format for `.m`, `.mm`, `.swift`, `.h`. The second-line "project" tag matches the target the file belongs to (look at neighboring files in the same directory to confirm; Xcode uses the target name, not the directory name).

Do not add a per-file GPL or BSD license block to new files. The project `LICENSE` applies, and the recent precedent omits the per-file license text.

Do not copy the older GPL 2.0 block style (with 2013 Alun Bestor copyright) into new files you author. That style is preserved on existing 2013-era files when modifying them, but applying it to new code misattributes authorship.

### Files that have no header

Plists, XIBs, project files, entitlements, schemes, `.gitignore`, `.gitattributes`, shell scripts under `tools/`, Markdown docs: no header.

### Vendored third-party code

`Other Sources/RegexKitLite/`, `Other Sources/BGHUDAppKit/`, `Other Sources/YRKSpinningProgressIndicator/`, `Other Sources/MCAdditions/`: preserve upstream headers verbatim. Do not author new files in these directories.

Vendored frameworks under `Vendor/` are git submodules; do not modify their files.

## Comments

Default to no comments. Only add a comment when the why is non-obvious: a hidden constraint, a workaround, or a subtle invariant. Do not write comments that describe what the code does. Do not add planning, decision, or analysis files unless explicitly asked.

Do not add `// FIXME` or `// TODO` for things you choose not to fix. Either fix it or leave the code as-is.

## Commit conventions

One focused commit per plan item. Each 🟢 commit should cherry-pick cleanly into an upstream PR.

**Message format:**

```text
<area>: <one-line summary, imperative mood, no period>

<optional body: explain the why, link to relevant Apple docs or
DOSBox issues where useful. Do not mention bundle names, plan items,
or "macOS 26" unless the change is 🔴 fork-specific.>
```

Examples of good summaries:

- `BXEmulator: replace NSAutoreleasePool with objc_autoreleasePoolPush`
- `Standalone: migrate WebView to WKWebView in About panel`
- `ADBBinCueImage: reject CUE entries that escape the base URL`

Bad summaries. Do not write these:

- `Bundle A item 7` (fork-internal reference)
- `Modernize for Tahoe` (no concrete change described)
- `Fix things` (no information)

### Attribution

Use the `Assisted-by:` trailer convention, not `Co-Authored-By:`.

**Required trailer when AI made meaningful contributions to the diff:**

```text
Assisted-by: <agent> (<model>)
```

Examples:

```text
Assisted-by: Claude Code (claude-sonnet-4-6)
Assisted-by: OpenAI Codex (gpt-5)
Assisted-by: Cursor (claude-3-7-sonnet)
Assisted-by: Aider (gpt-5-mini)
```

One trailer per commit. Place after any human `Co-authored-by:` trailers. Use the canonical model identifier, not marketing names.

**Forbidden in commit messages:**

- `Co-Authored-By: Claude <noreply@anthropic.com>` and variants. The `Co-authored-by:` trailer is reserved for human collaborators. Using it for AI conflates the two and is unwelcome in many upstreams.
- `🤖 Generated with [Claude Code]` or similar boilerplate.
- `Generated-by:`, `Created-by-AI:`, or other non-standard variants.
- Trailers naming a vendor's bot account, such as `<noreply@anthropic.com>` or `<copilot@github.com>`.
- The strings `Claude:`, `Codex:`, or `ChatGPT:` as message prefixes.

A `commit-msg` hook in `tools/git-hooks/` enforces this. Install once with `tools/setup-git-hooks.sh`. The hook rejects commits with forbidden patterns and explains how to fix. A companion `pre-commit` hook installed alongside refuses commits to protected branches (`maddsV2`, `master`, `main`), rejects unresolved merge conflict markers, and flags obvious personal-path or secret leaks in staged content.

**PR description footer (single line, italicized, before any test plan section):**

```markdown
*Drafted with AI assistance (<agent>, <model>). Reviewed by @<your-github-handle>.*
```

If multiple tools contributed:

```markdown
*Drafted with AI assistance (<agent/model list>). Reviewed by @<your-github-handle>.*
```

No emoji, no vendor logo, no link to a marketing page. The footer goes once at the bottom. Do not duplicate it in commit messages.

**Upstream export workflow:** do not rewrite commit history or remove attribution trailers unless the developer explicitly requests it.

If the developer asks for a clean upstream export, perform it in a fresh clone or temporary branch, then show the resulting commit list before pushing or opening a PR.

**Sign-off:** not required.

**Do not:**

- Do not squash unrelated changes into one commit.
- Do not amend a published commit. Add a follow-up commit instead.
- Do not use `--no-verify` or skip hooks.
- Do not include `--force` push unless explicitly told.

## Branch naming

Use a conventional-commit prefix as the rightmost segment, with an optional namespace prefix prepended when destination matters.

**Conventional prefixes (rightmost segment):**

- `fix/`: bug fixes, including security fixes
- `chore/`: maintenance, dependency bumps, dead-code removal
- `build/`: build configuration, project file, `Info.plist`, entitlements, schemes
- `refactor/`: code restructuring with no behavior change
- `perf/`: performance work
- `feat/`: new user-facing features (rare in this project)
- `docs/`: documentation only

**Namespace prefixes (optional, prepended when destination matters):**

- *(none)*: defaults to fork modernization. Merges into `macos26` (the personal working branch).
- `upstream/`: branch staged for a PR back to `MaddTheSane/Boxer:maddsV2`. Always cherry-picked from existing work, never the original work branch.
- `macos26/`: work that requires macOS 26 and breaks compatibility for older systems. Never upstreamed. If a future macOS bump introduces another wave of narrowing changes, use `macos27/` etc. by the same pattern.

**Examples:**

```text
fix/cue-resource-validation
chore/cleanup-unused-code
build/hardened-runtime-and-entitlements
build/tahoe-tcc-and-game-mode
refactor/concurrency-hot-paths
perf/metal-frame-pacing-and-color
upstream/fix/cue-resource-validation       (clean version PR'd to MaddTheSane/Boxer)
macos26/build/drop-intel-arch              (fork-only narrowing)
```

**Body rules:**

- Lowercase, hyphen-separated.
- Imperative phrase describing what the branch accomplishes.
- No fork-internal item numbers (`bundle-a-item-7` is bad).
- No bot prefixes (`claude/`, `codex/`, `bot/`).

**Long-lived branches in this fork:**

- `maddsV2`: clean mirror of `MaddTheSane/Boxer:maddsV2`. Never commit to it directly. Update only by fetching from upstream.
- `macos26`: the personal working branch. All merged PRs land here. This is the branch the developer builds and runs.

Always branch new work off `maddsV2`, not `macos26`. This keeps each topic branch cleanly cherry-pickable for upstream (`maddsV2` in the fork shares the same base as upstream's `maddsV2`, so no merge conflicts during cherry-pick).

## PR conventions

Bundle A is not automatically one homogeneous PR. Split it by review risk:

- Bundle A-trivial: small cleanup and build hygiene items may share one PR if each item is a separate commit.
- Bundle A-runtime: rendering, audio, power, permissions, signing, and Game Mode changes need focused manual verification and should not be buried in a trivial cleanup PR.
- Security items get dedicated branches and PRs.
- Fork-specific items land after upstreamable items so upstream cherry-pick ranges can exclude them.

Bundle B: one PR per item unless the plan explicitly says two items overlap.

Bundle C: dedicated branch and PR per item.

**Target base branch:**

- Standard topic branches: PR into `macos26` (the personal working branch).
- `upstream/*` branches: PR into `MaddTheSane/Boxer:maddsV2`.
- `macos26/*` branches: still PR into `macos26` locally; never opened against upstream.

### Runtime behavior items

Items that affect rendering, audio, input, power, permissions, signing, security, or user-visible UI require focused verification.

Do not describe these as purely mechanical cleanup, even if the diff is small. The PR must include the manual checks that prove the runtime behavior still works.

**PR description template:**

```markdown
## Summary

<one or two sentence summary of the change, in upstream-friendly terms>

## Why

<motivation: what is broken, what was deprecated, what the fix enables>

## Files

- `path/to/file.m`: <short note>
- `path/to/other.m`: <short note>

## Test plan

- [ ] Builds clean on Xcode 26 (`xcodebuild -workspace Boxer.xcworkspace -scheme Boxer build`)
- [ ] <feature-specific manual check, if any>
- [ ] `tools/bench.sh` snapshot appended to `BENCHMARKS.md`
```

PR title: same conventions as commit summary. No fork-internal references.

Avoid screenshots in PRs unless the change is visually load-bearing, such as the HUD audit, spinner replacement, color space change, or other UI-visible work.

## Verification

Before and after each PR, run:

```bash
./tools/bench.sh "post <bundle-or-item-name>" >> BENCHMARKS.md
```

Edit `BENCHMARKS.md`'s snapshot index at the top to add the new dated row. The static markers in the snapshot, including deprecated API counts, TCC plist coverage, and build settings, should move in the expected direction. If a marker moved unexpectedly, investigate before merging.

The `@available(macOS <26)` count is expected to remain nonzero unless the active plan item explicitly changes it. Do not treat a nonzero `@available` count as a failure.

Run the narrowest useful build, plus any touched target:

- Boxer app changes: `xcodebuild -workspace Boxer.xcworkspace -scheme Boxer -configuration Release build`
- Bundler changes: build the Bundler scheme, or the corresponding CI scheme if the shared scheme is not present.
- Standalone changes: build the Standalone scheme, or the corresponding CI scheme if the shared scheme is not present.
- Project, entitlement, signing, or Hardened Runtime changes: run the codesign entitlement check from the plan.
- XIB or visual changes: include screenshot QA.
- Runtime rendering, audio, power, or input changes: include the relevant manual runtime check from the plan.

For runtime captures such as frame pacing, energy, and battery drain, follow the procedure in the plan's *Verification & benchmarks* section. These are manual and only need to happen on bundle milestones or when the active item affects runtime behavior.

## Boundaries

**Do not modify:**

- `DOSBox-Staging/` submodule contents.
- `Vendor/DDHidLib`, `Vendor/MT32Emu`, `Vendor/OpenEmuShaders` submodule contents.
- `Frameworks/SDL2.framework`, `Frameworks/SDL2_net.framework` binary frameworks. `lipo` operations on them are allowed only under the active plan item that explicitly calls for it.
- `Other Sources/RegexKitLite/`, `Other Sources/BGHUDAppKit/`, `Other Sources/YRKSpinningProgressIndicator/`, `Other Sources/MCAdditions/` unless the active plan item explicitly targets them.

For submodule updates, do not edit vendored source directly. Record:

- Old SHA.
- New SHA.
- Upstream repository and branch or tag.
- Reason for the update.
- Any manual verification performed.

For DOSBox-Staging work, investigate and propose a path first. Do not bump the submodule blindly.

**Do modify** per active plan item:

- Anything under `Boxer/`, `Standalone/`, `Bundler/`, `Other Sources/ADBToolkit/`.
- `Boxer.xcodeproj/project.pbxproj` for build-setting changes. Be careful with reformatting and preserve tab indentation.
- `Info.plist`, `Boxer/Boxer.entitlements`, XIBs.
- `BENCHMARKS.md`, this file, files under `tools/`.

## Trust but verify

Agents make confident-sounding claims that don't always survive verification. Before acting on a finding from another agent or your own scan, **read the actual current file** to confirm. Do not trust file:line citations without re-reading the line. When a finding is invalidated by verification, say so explicitly rather than carrying it forward into the work.

For any "delete X" finding where X is a vendored library, wrapper directory, or framework, search for every public symbol it exports (classes, protocols, notification constants, macros, delegate method signatures), not just the library's name or directory path. Directory- and string-name searches frequently miss live class-name usages.

## Do not do these things

- Do not add backward-compatibility shims, dead `// removed` comments, or renamed `_unused` parameters for code you removed. Just delete it.
- Do not add error handling, fallbacks, or input validation for cases that cannot happen, unless the active plan item explicitly concerns security, parsing, importing, or host boundary validation.
- Do not add new abstractions, helper classes, or refactors beyond the active plan item.
- Do not introduce a new test framework unless the active plan item asks for it. For security, parser, importer, or race-condition fixes, add the smallest feasible regression check or manual reproduction note.
- Do not update copyright years on files you only modify.
- Do not strip `@available(macOS <26)` guards. They exist for upstream compatibility.
- Do not introduce Swift to files that are currently Objective-C. Do not introduce SwiftUI.
- Do not write planning, ADR, or analysis files unless the developer asks. The plan doc is the planning artifact.
