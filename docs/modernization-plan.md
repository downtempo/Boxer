# Boxer: Updates and Modernization

## Context

Boxer is a long-running open-source project for running DOS games on the Mac. [Boxer 1.0 was released in 2011 by Alun Bestor](https://web.archive.org/web/20160629231337/https://blog.boxerapp.com/2011/03/25/boxer-turns-1/), and a later branch led by MaddTheSane [released key updates from 2020 through 2022](https://github.com/MaddTheSane/Boxer/releases), including support for 64-bit macOS (required to run on macOS Catalina or later) and Apple Silicon. The upstream branch has had periodic commits since, but the last tagged release was **AS-beta-4.1 on April 12, 2022**, over four years before this work began. Releases are sparse, and the codebase has accumulated drift relative to current macOS.

### Goals

This fork has two goals:

1. **Review the Boxer codebase to make updates and fixes**: ranging from "needed to compile on current macOS" to "nice-to-have improvements." This is the broadly-applicable goal: most of these changes are useful to all Boxer users, and upstream has periodic commits despite the last tagged release being on April 12, 2022, so contributing fixes back is realistic.
2. **Narrow the compatibility target to macOS Tahoe (macOS 26) and Apple Silicon.** This is the *developer's personal preference* for this fork; users on older macOS or Intel hardware won't benefit, so this work stays in the fork and isn't proposed upstream.

The intent is to **contribute as many of the goal-1 fixes upstream as possible**. Commit structure reflects this:

- 🟢 **Upstream-friendly items**: kept self-contained and single-purpose, with commit messages that explain the fix in upstream terms (no "because we target macOS 26"). These should cherry-pick cleanly into an upstream PR against `maddsV2`.
- 🔴 **Fork-specific / narrowing items**: clearly labeled and landed *after* the upstream-friendly items, so a future `git log` makes it obvious which commits are personal-fork-only.

### AI-assisted development approach

This work may use AI-assisted coding tools to inspect the codebase and draft implementation changes. The developer drives scope, API-level reasoning, upstream packaging, build checks, and manual test plans. Meaningful AI assistance should be disclosed in implementation PRs according to `AGENTS.md`.

This is not a benchmark of any single AI model or vendor. Cost control matters because this is a self-funded project, so cost-efficient implementation agents, e.g. Claude Sonnet, are preferred for bounded work where the plan item is explicit and verification is straightforward. Use higher-capability review or reasoning agents for security, concurrency, Swift migration, runtime behavior, architecture, or any item where correctness depends on subtle implementation details. Cost savings are a secondary goal, but NOT at the expense of code quality or review confidence.

### Phase status

Phase 1 (already landed) was mostly goal-1 work, fixes that *must* be made for Boxer to keep building and running on modern macOS, all upstreamable. Phase 2 (this document) covers the remaining modernization, unused-code cleanup, runtime-access fixes for Tahoe TCC + Hardened Runtime, and a small number of explicitly fork-specific narrowing items.

Items below are tagged 🟢 (upstreamable) or 🔴 (fork-specific narrowing) so the commit structure can group accordingly.

---

## ✅ Phase 1: Already landed

| # | Change | Status |
|---|--------|--------|
| 1 | `OSSpinLock` → `os_unfair_lock` in [RegexKitLite.m](Other%20Sources/RegexKitLite/RegexKitLite.m) | ✅ Done |
| 2 | `NSAutoreleasePool` → `objc_autoreleasePoolPush/Pop` in [BXEmulator.mm](Boxer/BXEmulator.mm) | ✅ Done |
| 3 | `WebView` → `WKWebView` migration in [BXStandaloneAboutController](Standalone/BXStandaloneAboutController.m) + [XIB](Standalone/Resources/Base.lproj/StandaloneAbout.xib) | ✅ Done |
| 4 | `AUGraph` + `DLSSynth` → `AVAudioEngine` + `AVAudioUnitSampler` in [BXMIDISynth.m](Boxer/BXMIDISynth.m) | ✅ Done |
| 5 | Unused `RegexKitLite` imports removed from 3 files | ✅ Done |
| 6 | Deployment target → `26.0` (both Debug + Release) | ✅ Done |
| 7 | [Boxer.entitlements](Boxer/Boxer.entitlements) populated (JIT + library-validation) | ✅ Done |
| 8 | Loguru `README.md` → `Readme.md` case fix in [project.pbxproj](Boxer.xcodeproj/project.pbxproj) | ✅ Done |

---

## Phase 2: Work bundles and themed branches

### 🟢 Bundle A: First-pass cleanup and modernization (cost-efficient implementation agent, e.g. Claude Sonnet, with themed branches)

Bundle A is a planning bundle, not a PR boundary. Split it into the themed branches in the commit/PR structuring section. A cost-efficient implementation agent is appropriate for bounded cleanup and build-setting work. Items that affect rendering, audio, power behavior, permissions, signing, Game Mode, or security require focused verification and stronger review.

| # | Item | Files | Scope |
|---|------|-------|-------|
| A1 🟢 | **Delete the orphaned `Other Sources/VDKQueue/` directory.** Contains only `README.md`. VDKQueue was added in [`4686eb3`](https://github.com/MaddTheSane/Boxer/commit/4686eb310fe091d14edc8fe3043e8caecd69764f) (Alun Bestor, 2013-01-09); its source files (`VDKQueue.h`, `VDKQueue.m`) and 12 project.pbxproj references were removed in [`2840998`](https://github.com/MaddTheSane/Boxer/commit/284099826896add058deeaebd192f9bac3731577) "Remove VDKQueue." (C.W. Betts, 2020-07-16). The README was left behind by oversight. Safe to delete: zero references in source, project file, entitlements, schemes, or build settings; no replacement `FSEvent`/`kqueue`/`NSFilePresenter` code exists (Boxer's current approach just invalidates caches on app activation). | `Other Sources/VDKQueue/` | Small |
| A3 🟢 | **Fix `dispatch_get_current_queue()` to `dispatch_get_main_queue()`** at [Bundler/BBAppDelegate+AppExporting.m:21](Bundler/BBAppDelegate+AppExporting.m:21). The call has been in place since the Bundler was merged into mainline Boxer in [`839dfd57`](https://github.com/MaddTheSane/Boxer/commit/839dfd57) (Alun Bestor, 2012-11-02); the API was deprecated in macOS 10.6 and removed in 10.9. Surrounding context confirms the call site runs on the main queue, so the replacement preserves intent. | [Bundler/BBAppDelegate+AppExporting.m](Bundler/BBAppDelegate+AppExporting.m) | Small |
| A4 🟢 | **Delete the commented-out `@available(macOS 11, *)` block** at [BXExternalMIDIDevice.m:315-316](Boxer/BXExternalMIDIDevice.m:315). Commented out by C.W. Betts in [`858eb26`](https://github.com/MaddTheSane/Boxer/commit/858eb269) (2021-03-06, "Add nullability metadata.") while experimenting with the macOS 11 `MIDIEventList` API; never wired up. Two commented lines, safe to remove. | [BXExternalMIDIDevice.m](Boxer/BXExternalMIDIDevice.m) | Small |
| A5 🟢 | Bump OpenEmu-Shaders submodule `0f9e7e3` → `2ac33a9` (Nov 2025) | `.gitmodules` + submodule update | Small |
| A6 🟢 | Switch CwlDemangle SPM from `MaddTheSane@swift5Compat` (2020) → `mattgallagher/CwlDemangle@master` | [project.pbxproj](Boxer.xcodeproj/project.pbxproj) | Small |
| A7 🟢 | `@synchronized` → `os_unfair_lock` on hot paths only | [BXMIDIDeviceMonitor.m:77](Boxer/BXMIDIDeviceMonitor.m:77), [ADBFileHandle.m:893,1019](Other%20Sources/ADBToolkit/ADBFileHandle.m) | Medium |
| **A8** 🟢 | **Enable Hardened Runtime for Boxer target**: flip `ENABLE_HARDENED_RUNTIME = NO` → `YES` at lines 5361, 5412. Required for notarization; without it the entitlements file is effectively a no-op. | [project.pbxproj](Boxer.xcodeproj/project.pbxproj) | Small |
| **A9** 🟢 | **Apply entitlements to Standalone target too**: wire `Boxer/Boxer.entitlements` into the Boxer Standalone target's build config so bundled gameboxes get JIT permissions. | [project.pbxproj](Boxer.xcodeproj/project.pbxproj) | Small |
| **A10** 🟢 | **Add TCC usage descriptions to Info.plist**: Tahoe will prompt for these on first access; without custom text the user sees ugly defaults. Add: `NSRemovableVolumesUsageDescription` (for CD/USB game discs), `NSDesktopFolderUsageDescription`, `NSDocumentsFolderUsageDescription`, `NSDownloadsFolderUsageDescription` (common gamebox locations). | [Info.plist](Info.plist) | Small |
| **A11** 🟢 | **Add `NSInputMonitoringUsageDescription` to Info.plist**: required by macOS 10.15+ for the `IOHIDManager` calls in [ADBHIDMonitor.m:124,155](Other%20Sources/ADBToolkit/ADBHIDMonitor.m). Without it the gamepad enumeration triggers a generic-text prompt; user still has to enable Boxer in Settings → Privacy → Input Monitoring before joysticks work. | [Info.plist](Info.plist) | Small |
| **A12** 🔴 | **Drop Intel: set `ARCHS = arm64` + slim SDL frameworks**: Boxer's own source is fully arch-agnostic (zero `__x86_64__` / SSE/AVX). SDL2 + SDL2_net frameworks ship as universal; slim with `lipo -extract arm64 Frameworks/SDL2.framework/Versions/A/SDL2 -o ...` (same for SDL2_net). Tahoe already excludes most Intel Macs; net effect: ~7MB smaller distribution, simpler signing. **Fork-specific narrowing, not for upstream.** | [project.pbxproj](Boxer.xcodeproj/project.pbxproj), [Frameworks/SDL2.framework](Frameworks/SDL2.framework), [Frameworks/SDL2_net.framework](Frameworks/SDL2_net.framework) | Fork-specific small |
| **A13** 🟢 | **Enable Hardened Runtime for Boxer Standalone target**: same `ENABLE_HARDENED_RUNTIME = NO` → `YES` flip as A8. Without it, standalone game apps stamped out by Bundler won't notarize. | [project.pbxproj](Boxer.xcodeproj/project.pbxproj) | Small |
| **A14** 🟢 | **Share Boxer + Standalone schemes in workspace**: `Boxer.xcworkspace/xcshareddata/xcschemes/` currently only contains `Boxer CI.xcscheme` and `Boxer Bundler CI.xcscheme`. Add `Boxer.xcscheme` and `Boxer Standalone.xcscheme` (mirror the CI ones with `parallelizeBuildables = YES` etc.) so contributors see them in the scheme picker by default. | new scheme files | Small |
| **A15** 🟢 | **Delete the legacy `.pch` prefix header in Bundler.** `Bundler/Boxer Bundler-Prefix.pch` contains only `#import <Cocoa/Cocoa.h>`. Drop `GCC_PRECOMPILE_PREFIX_HEADER` and `GCC_PREFIX_HEADER` from the Bundler build config ([project.pbxproj lines 5242, 5280](Boxer.xcodeproj/project.pbxproj:5242)), delete the file, verify a clean build. The PCH was introduced alongside the Bundler merge in [`839dfd57`](https://github.com/MaddTheSane/Boxer/commit/839dfd57) (Alun Bestor, 2012-11-02), back when prefix headers were the Xcode default. Modern Xcode prefers per-file imports. | [project.pbxproj](Boxer.xcodeproj/project.pbxproj), delete `Bundler/Boxer Bundler-Prefix.pch` | Small |
| **A17** 🟢 | **Set `preferredFramesPerSecond` on `BXMetalRenderingView`** to match the active DOS mode's native refresh (70 for VGA Mode 13h, 60 for SVGA/SuperVGA, etc.), currently uses MTKView's default which on ProMotion 120Hz displays causes judder. Fixes frame pacing on M4 Pro/Max and M5 displays. | [Boxer/Metal Rendering/BXMetalRenderingView.m](Boxer/Metal%20Rendering/BXMetalRenderingView.m), [Boxer/Rendering/](Boxer/Rendering) (need to wire DOS mode → refresh rate) | Runtime |
| **A18** 🟢 | **Switch Metal layer color space to Display-P3** for the 8-bit path in [BXMetalLayer.m:45](Boxer/Metal%20Rendering/BXMetalLayer.m:45), currently `kCGColorSpaceITUR_709` (HDTV chromaticities). Use `kCGColorSpaceDisplayP3` (or `kCGColorSpaceSRGB` if the CRT shaders look wrong) for wide-gamut color on M4/M5 displays. The existing TODO at line 39 already flags this. | [BXMetalLayer.m](Boxer/Metal%20Rendering/BXMetalLayer.m) | Runtime |
| **A19** 🟢 | **Set explicit AVAudioEngine input/output buffer duration** to ~5ms for lower MIDI/audio latency. Default is ~10ms; action games (Doom, Wolfenstein) feel snappier with reduced buffer. Configure via `AVAudioSession` on the underlying audio unit. | [BXMIDISynth.m](Boxer/BXMIDISynth.m), possibly the SDL audio path | Runtime |
| **A20** 🟢 | **Release `IOPMAssertionTypeNoDisplaySleep` while the session is paused, re-acquire on resume.** Currently it's held for the entire session lifetime ([BXSession.m:2361](Boxer/BXSession.m:2361)), laptop display stays awake even when the user alt-tabs and pauses. Hook into the existing pause/resume notifications. | [BXSession.m](Boxer/BXSession.m) | Runtime |
| **A21** 🟢 | **Skip Metal redraws when the DOS framebuffer is unchanged.** Currently the renderer draws at display rate regardless of whether DOS has produced a new frame. Hook into the existing video-frame change notification (`BXVideoFrame` updates) and only call `MTKView` `draw` when there's actual new content; otherwise let the view idle. Expected to reduce GPU work on menu screens and turn-based games; verify with runtime captures. | [BXMetalRenderingView.m](Boxer/Metal%20Rendering/BXMetalRenderingView.m), wire to [Boxer/Rendering/](Boxer/Rendering) | Runtime |
| **A22** 🟢 | **Adopt macOS Game Mode.** Add `LSPrefersGameMode = true` to [Info.plist](Info.plist). Pair with C0 for full benefit once the GameController migration is underway. Expected to improve sustained performance behavior on supported macOS versions; verify with runtime captures. | [Info.plist](Info.plist), link `GameController.framework` | Runtime |
| **A23** 🟢🔒 | **Fix CUE resource path validation (security-sensitive)**: referenced resources in a CUE import should resolve inside the CUE file's base directory before being copied into a gamebox. Add a containment check after path standardization and surface an import error for invalid entries. Keep detailed reproduction/regression steps in the dedicated security PR rather than in this roadmap. **Priority for upstream, affects all Boxer users.** | [ADBBinCueImage.m](Other%20Sources/ADBToolkit/ADBBinCueImage.m), possibly [BXDriveBundleImport.m](Boxer/BXDriveBundleImport.m) for error surfacing | Security |
| **A24** 🟢 | **Cap MIDI SysEx length from guest** (defense-in-depth). `boxer_sendMIDISysex` in [BXCoalfaceAudio.mm:117](Boxer/BXCoalfaceAudio.mm:117) passes `Bitu len` straight to `[NSData dataWithBytesNoCopy:length:]`. DOSBox already bounds this internally, but adding `if (len > 65536) return;` is a trivial host-side cap against any future fuzzing or DOSBox bug. | [BXCoalfaceAudio.mm](Boxer/BXCoalfaceAudio.mm) | Small |

**Bundle A scope:** mostly small and medium implementation items, split into themed branches. Security and runtime-behavior items need focused verification and stronger review.

---

### 🟡 Bundle B: Refactors with care (cost-efficient implementation agent plus stronger review)

Each item is independently revertable. A cost-efficient implementation agent, e.g. Claude Sonnet, may draft the change when the checklist is explicit, but the developer should use stronger review for concurrency, Swift migration, locking, security, or runtime-behavior details.

| # | Item | Files | Scope |
|---|------|-------|-------|
| B1 🟢 | Migrate `NSInvocation` callbacks → direct `objc_msgSend` delegate dispatch. This is the `shouldCloseSelector` bridge code, not a simple block conversion; confirm call conventions during implementation. | [BXSession.m:714](Boxer/BXSession.m:714), [BXImportSession.m:315](Boxer/BXImportSession.m:315) | Medium |
| B3 🟢 | Replace `YRKSpinningProgressIndicator` (6+ call sites) with `NSProgressIndicator` style `Spinning`. UX-visible, needs screenshot QA. | [BXDOSWindowController](Boxer/DOS%20window/BXDOSWindowController.m), [BXHUDSpinningProgressIndicator](Boxer/BXHUDSpinningProgressIndicator.m), [BXProgramPanel](Boxer/BXProgramPanel.m), etc. | Visual QA |
| B4 🟢 | **Bump `SWIFT_VERSION` from `5.0` → `6.0`** for all 4 occurrences in [project.pbxproj](Boxer.xcodeproj/project.pbxproj). Swift 6 enforces data-race safety at compile time. Only 12 Swift files in the codebase, mostly UI/image generation, all relatively self-contained. Compiler will surface any required `Sendable` / `@MainActor` annotations. (Optional stepping stone: set `SWIFT_STRICT_CONCURRENCY = complete` under Swift 5 first, fix warnings, then bump to 6.0.) Files: [CoverArt.swift](Boxer/CoverArt.swift), [BootlegCoverArt.swift](Boxer/BootlegCoverArt.swift), [MT32LCDDisplay.swift](Boxer/MT32LCDDisplay.swift), [DummyMIDIDevice.swift](Boxer/DummyMIDIDevice.swift), [NSImage+ADBImageEffects.swift](Other%20Sources/ADBToolkit/NSImage+ADBImageEffects.swift), [BXShadersModel+OpenEmu.swift](Boxer/Shaders/BXShadersModel+OpenEmu.swift), [BXShadersModel.swift](Boxer/Shaders/BXShadersModel.swift), + 5 ADBToolkit helpers. | Swift migration |
| B5 🟢 | **Thermal / Low Power Mode awareness**: Observe `NSProcessInfoThermalStateDidChangeNotification`; throttle/pause emulation when `thermalState == .critical`. Show a bezel when Low Power Mode (`ProcessInfo.processInfo.isLowPowerModeEnabled`) is on, warning the user emulation may run slow. | new helper in [BXSession.m](Boxer/BXSession.m), [BXBezelController.m](Boxer/BXBezelController.m) | Runtime |
| B6 🟢 | **Pixel-perfect integer scaling audit**: Build, take screenshots at common DOS resolutions (320×200, 320×240, 640×480) on M-series Retina at various window sizes. Confirm DOS pixels render as integer multiples; if blurry, add a "snap to integer scale" preference. CRT shaders need this for sharp scanlines. | [BXMetalRenderingView.m](Boxer/Metal%20Rendering/BXMetalRenderingView.m), [BXDOSWindowController.m](Boxer/DOS%20window/BXDOSWindowController.m) | Visual QA |
| B7 🟢 | **Tahoe Liquid Glass HUD audit**: Boxer's custom `BXHUDWindow` chrome predates macOS dark mode and Liquid Glass. Replace custom dark-theme backgrounds with `NSVisualEffectView` (`.hudWindow` material) where appropriate so the HUD looks native to Tahoe. Visual-only change; check it doesn't break `BXThemes`. `NSVisualEffectView` has been around since 10.10 so this is upstream-friendly. | [BXHUDWindow.m](Boxer/BXHUDWindow.m), [BXThemes.m](Boxer/BXThemes.m), several inspector/bezel views | Visual QA |
| B8 🟢 | **Low Power Mode auto-throttle.** When `ProcessInfo.processInfo.isLowPowerModeEnabled` is YES, automatically halve the active DOSBox cycle count (or fall back to the gamebox's "lowest" cycle profile) and show a one-time bezel: "Low Power Mode is on, performance reduced to extend battery." On disable, restore prior settings. Listen for `NSProcessInfoPowerStateDidChangeNotification`. | [BXSession+BXEmulatorControls](Boxer/BXSession+BXEmulatorControls.m) (or equivalent), [BXBezelController.m](Boxer/BXBezelController.m) | Runtime |
| B9 🟢 | **Convert `BXMIDIDeviceMonitor` polling → CoreMIDI notifications.** If the monitor uses timer polling for MT-32 device discovery (audit [BXMIDIDeviceMonitor.m](Boxer/BXMIDIDeviceMonitor.m) to confirm), switch to `MIDIClientCreate` with a notification callback. Reduces background wakeups on battery; CoreMIDI's `kMIDIObjectAdded` / `kMIDIObjectRemoved` events arrive only when state changes. | [BXMIDIDeviceMonitor.m](Boxer/BXMIDIDeviceMonitor.m) | Runtime |
| B10 🟢 | **Fix property-based locking on `self.emulator`** at [BXSession.m:2147](Boxer/BXSession.m:2147). `@synchronized(self.emulator)` becomes a silent no-op if `self.emulator` is nil, possible if the property is cleared between the `isEmulating` check at line 2145 and the lock acquisition at 2147. Fix: lock on a stable ivar (a dedicated `_emulatorAccessLock`) or read `_emulator` into a local before locking. May overlap with A7's hot-path `@synchronized` → `os_unfair_lock` conversion; verify both refer to the same call sites. | [BXSession.m](Boxer/BXSession.m) | Locking |
| B11 🟢 | **Fix ADBFileHandle close-vs-read race.** [ADBFileHandle.m:823](Other%20Sources/ADBToolkit/ADBFileHandle.m:823) clears `self.sourceHandle = nil` outside any lock; reader at [line 893](Other%20Sources/ADBToolkit/ADBFileHandle.m:893) uses `@synchronized(self.sourceHandle)` which becomes a no-op once nilled. Subsequent method calls on the nil sourceHandle silently return 0, producing wrong-data reads instead of erroring out. Fix: lock on a stable ivar/lock object during both close and read; check for cleared handle inside the lock and error explicitly. | [ADBFileHandle.m](Other%20Sources/ADBToolkit/ADBFileHandle.m) | Locking |

**Bundle B scope:** medium refactors, generally one PR per item. Treat Swift, locking, runtime, and visual changes as higher-review work even when the diff is compact.

---

### 🔴 Bundle C: Larger projects, defer (not for cost-efficient-only delegation)

These each warrant their own focused PR with manual testing. A cost-efficient implementation agent may help with small substeps, but should not own the overall design or final review.

| # | Item | Why deferred |
|---|------|--------------|
| C1 🟢 | **Sparkle 1.23 → 2.9.1** | Major version, API change (`SUUpdater` → `SPUUpdater`). Security-positive (EdDSA signing, hardened-runtime support, sandbox-friendly XPC services). Large refactor plus auto-update flow testing. |
| C2 🟢 | **MT32Emu fork → upstream `munt_2_7_0`** | Roland MT-32 audio behavior changes. Needs manual audio QA on real games. Current fork not updated since March 2022. |
| C3 🟢 | **DOSBox-Staging, investigate eduo's fork** | Boxer's pinned fork (`MaddTheSane/dosbox-staging boxer-compat`) has not been updated since March 2022. Upstream is at 0.82.2 / 0.83-RC1, with multiple releases of emulation improvements since then. The `eduo` fork (`eduo/dosbox-staging`) has updates as of Nov 2025 and existing Boxer contribution history. **First step: read eduo's fork to understand what macOS-specific patches it carries, then propose a path forward. Do not bump the submodule blindly.** This could be a high-impact upstream contribution. |
| C4 🟢 | Retire `BXDOSWindowControllerLion` subclass. Lion-era fullscreen overrides; modern macOS handles fullscreen natively. Migrate behavior to parent class and rewire `DOSWindow.xib` + `DOSImportWindow.xib`. | Large refactor plus XIB editing. |
| **C0** 🟢 (promoted from C5) | **GameController framework migration** (replace DDHidLib for joystick). Expected benefits include broader modern-controller support, battery-level reporting, and no Input Monitoring prompt for GameController-backed devices. Promote above other C-items if gamepad UX is the goal. Track alongside the existing DDHidLib path during migration, then retire DDHidLib after validation. | Multi-day, high user-perceived impact. |

---


### Security note

Security-sensitive items are kept specific enough to guide implementation, but this public roadmap avoids publishing a full exploit recipe before a dedicated fix PR exists. The fix PR should include the reproduction/regression check, expected behavior before and after the patch, and any maintainer-facing disclosure needed for upstream review.

---

## Commit / PR structuring for upstream-friendliness

Goal: land each 🟢 item as a self-contained commit so it can be cherry-picked into an upstream PR. Full branch naming and convention guidance lives in `AGENTS.md`. Short version:

1. **Themed branches, not bundle-as-PR.** Each plan bundle splits into focused themed branches at implementation time. Bundle A (~22 items) breaks into roughly 10 themed branches like `chore/cleanup-unused-code`, `build/hardened-runtime-and-entitlements`, `fix/cue-resource-validation`, `perf/metal-frame-pacing-and-color`, etc. Bundle B items typically map 1:1 to a branch each. Bundle C items each get their own dedicated branch.
2. **Commits within a branch.** Each commit is a single focused change with a focused message ("Fix dispatch_get_current_queue removed in macOS 10.9", not "Bundle A item 3"). 🔴 fork-specific items live on dedicated `macos26/*` branches, not mixed into the themed 🟢 branches.
3. **Branch off `maddsV2`.** Every topic branch starts from the fork's `maddsV2` (which mirrors upstream). PR target is `macos26` (the personal working branch). This keeps each themed branch cleanly cherry-pickable for upstream later.
4. **Upstream submission.** After a themed branch merges into `macos26`, evaluate whether to send it upstream. Create an `upstream/<topic>` branch from `maddsV2`, cherry-pick or recreate the relevant commits, and follow `AGENTS.md` for upstream AI-assistance disclosure and trailer handling before filing a PR to `MaddTheSane/Boxer:maddsV2`.
5. **Priority order for upstream.** The CUE resource validation fix (A23 🔒) should go upstream first and soon, since it affects every Boxer user. Other 🟢 themed branches go upstream as time allows.

### Suggested themed branches for Bundle A

| Branch | Plan items | Notes |
|--------|-----------|-------|
| `chore/cleanup-unused-code` | A1, A4, A15 | VDKQueue removal, commented `@available`, legacy `.pch` |
| `chore/refresh-dependencies` | A5, A6 | OpenEmu-Shaders bump, CwlDemangle upstream switch |
| `chore/replace-removed-apis` | A3 | `dispatch_get_current_queue` and other removed APIs |
| `build/hardened-runtime-and-entitlements` | A8, A9, A13 | HR on, Standalone entitlements wired |
| `build/share-workspace-schemes` | A14 | Workspace schemes |
| `build/tahoe-tcc-and-game-mode` | A10, A11, A22 | `Info.plist` TCC strings and Game Mode |
| `refactor/concurrency-hot-paths` | A7 (and B10 if it overlaps) | `@synchronized` to `os_unfair_lock` |
| `perf/metal-frame-pacing-and-color` | A17, A18 | `preferredFramesPerSecond` and Display-P3 |
| `perf/audio-buffer-and-power` | A19, A20, A21 | AVAudioEngine buffer, IOPM on pause, redraw skipping |
| `fix/cue-resource-validation` | A23 🔒 | Standalone security-sensitive fix |
| `fix/midi-sysex-length-cap` | A24 | Single defense-in-depth fix |
| `macos26/build/drop-intel-arch` | A12 🔴 | Fork-only narrowing |

---

## Verification & benchmarks

Two-track measurement, both committed to the repo so deltas are auditable.

### Track 1: static snapshot (automated)

`tools/bench.sh [label]` runs in ~30 seconds, no submodules or build required.
Outputs a markdown snapshot covering:
- Source size (LoC, file counts) for Boxer's own code vs. vendored
- Deprecated-API marker counts (`OSSpinLock`, `NSAutoreleasePool`, `WebView`,
  `kAudioUnitSubType_DLSSynth`, `AUGraph`, `@available`, `@synchronized`,
  `NSInvocation`, `Carbon`, `RegexKitLite`)
- Submodule pinned commits + Swift Package versions
- Build settings (`MACOSX_DEPLOYMENT_TARGET`, `SWIFT_VERSION`, `ARCHS`,
  `ENABLE_HARDENED_RUNTIME`, `MTL_LANGUAGE_REVISION`, …)
- Tahoe TCC hygiene (which usage-description plist keys are present,
  `LSPrefersGameMode`, entitlements file populated)
- Vendored framework architectures + sizes

**Workflow:**
1. Baseline already captured in [BENCHMARKS.md](BENCHMARKS.md) as
   *2026-05-14, post Phase 1, pre Bundle A*.
2. After each themed PR or bundle milestone merges, run `tools/bench.sh "post <branch-or-milestone>"`
   and append the new snapshot to `BENCHMARKS.md`.
3. The marker counts and TCC table give a clean before/after delta per bundle.

Expected deltas after the relevant Bundle A themed branches:
- `@available` guards: remain nonzero. Former A2 was moved to the not-planning section; keep upstream-compatibility guards.
- `@synchronized` blocks: 21 → 19 (only hot paths touched).
- `dispatch_get_current_queue` markers: → 0.
- `[NSImage setSize:]`: unchanged if tracked; it is not actually deprecated and is explicitly skipped.
- Tahoe TCC rows: all ❌ → ✅ after the TCC/Game Mode branch.
- `ARCHS`: (unset) → arm64 only on the fork-specific A12 branch.
- `ENABLE_HARDENED_RUNTIME`: mixed → YES after the hardening branch.
- SDL2 / SDL2_net frameworks: universal → arm64 only on the fork-specific A12 branch (~7 MB saved).

### Track 2: runtime captures (manual, on M-series hardware)

Static metrics don't capture frame pacing, energy impact, audio latency, or
gamepad UX. Capture these on your M4/M5 Mac, ideally before Bundle A goes out
(honest "before") and after each bundle merges.

**Capture procedure:**

Pick one or two representative games. Examples:
- **Frenetic action**: Doom (E1M1 from spawn, run forward for 60 s)
- **Music-heavy**: Roger Rabbit / Wing Commander (GM intro track for 60 s)
- **Static-scene**: Maniac Mansion title screen, hands off keyboard (30 s)

For each capture session, run through:

1. **Cold launch time.** Quit Boxer, then time-to-first-window with
   Instruments → *Time Profiler* template (`xcrun xctrace record --template "Time Profiler" --launch Boxer.app`).
2. **Idle on main window, no session.** 30 s sample. Activity Monitor →
   Energy tab: should be ~0 % CPU / "Low" energy impact.
3. **Active gameplay.** Launch the test game. 60 s of consistent gameplay:
   - Frame rate + variance: Instruments → *Core Animation FPS* template.
   - Energy Impact + Avg Energy Impact: Activity Monitor → Energy tab.
   - Power draw (laptop):
     `sudo powermetrics --samplers cpu_power,gpu_power,thermal -i 1000 -n 60`
     (60 samples = ~1 min). Watch for `GPU Power` and `Package Power`.
   - Memory: Activity Monitor → Memory tab → Real Memory.
4. **Paused, game loaded.** Hit pause, leave for 30 s. CPU% should drop
   sharply once A20 lands (IOPMAssertion release on pause).
5. **Battery drain** (laptop, unplugged): full screen brightness, AirPods or
   headphones, play continuously for 30–60 min, record battery % delta.
6. **Gamepad walk-through.** Plug in a controller. Confirm:
   - TCC "Input Monitoring" prompt text reads your custom string (after A11).
   - All buttons / analog sticks / triggers / D-pad register.
   - Notable absences (DualSense haptics, Xbox Share, Backbone): C0 only.

**Record results** in [BENCHMARKS.md](BENCHMARKS.md) under the
*Runtime captures* section, one subsection per capture session. Compare
before/after each bundle merge.

### What "good" looks like at the end

After Bundles A + B land, target state:
- All static markers in the "deprecated" table at 0 where the plan actually targets them. Expected exceptions: `@available`, deferred `@synchronized`, Carbon, and RegexKitLite.
- All TCC plist keys present, `LSPrefersGameMode = true`,
  `ENABLE_HARDENED_RUNTIME = YES` consistently.
- Universal SDL frameworks slimmed to arm64.
- 60 s gameplay frame variance reduced (A17 frame pacing fix).
- Paused-session CPU% dropping below 5 % (A20 IOPM release).
- Static-scene games drawing only when frame changes (A21).
- Energy Impact in Activity Monitor stays "Low" / "Medium" during typical
  gameplay; Game Mode (A22) participates in supported macOS scheduling behavior.

---

## Verification (post Bundle A)

1. **Build**: `xcodebuild -workspace Boxer.xcworkspace -scheme Boxer -configuration Release build` completes cleanly. A nonzero `@available(macOS <26)` marker count is expected and should not be treated as a failure.
2. **Hardened runtime check**: `codesign -d --entitlements - Build/Products/Release/Boxer.app` shows the JIT entitlements are present.
3. **Tahoe TCC flow**:
   - Launch Boxer fresh; import a gamebox from `~/Documents`. TCC prompt appears with custom text from `NSDocumentsFolderUsageDescription`.
   - Insert a USB stick or mount a game CD. TCC prompt for removable volumes appears with custom text.
4. **Joystick flow**: Plug in a gamepad, launch a game that uses it. First-run: TCC "Input Monitoring" prompt appears with custom text. After enabling Boxer in Settings → Privacy → Input Monitoring, gamepad input works.
5. **MIDI audio**: Open a GM-music game; confirm music plays through `AVAudioUnitSampler`. Check program-change response by listening for instrument changes mid-song.
6. **Update check**: Help → Check for Updates still works (Sparkle 1.x is untouched in Bundle A).

---

## AI assistance disclosure

Parts of this planning document were drafted with AI assistance and edited by Andy Volk. Implementation PRs should disclose meaningful AI assistance separately and describe the build or manual checks performed.
