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
| 4 | `AUGraph` + `DLSSynth` → `AVAudioEngine` + Apple `MIDISynth` via `AVAudioUnitMIDIInstrument` in [BXMIDISynth.m](Boxer/BXMIDISynth.m) | ✅ Done |
| 5 | Unused `RegexKitLite` imports removed from 3 files | ✅ Done |
| 6 | Deployment target → `26.0` (both Debug + Release) | ✅ Done |
| 7 | [Boxer.entitlements](Boxer/Boxer.entitlements) populated (JIT + library-validation) | ✅ Done |
| 8 | Loguru `README.md` → `Readme.md` case fix in [project.pbxproj](Boxer.xcodeproj/project.pbxproj) | ✅ Done |

---

## Phase 2: Work bundles and themed branches

### Item readiness

A readiness tag is attached to items (external review noted the table format
made every row look equally ready):

- **Done**: landed in a commit.
- **Ready**: code-backed, scoped, verifiable as written.
- **Investigate**: claim plausible, implementation/mechanism unknown until checked.
- **Experiment**: outcome subjective or measurement-dependent (needs QA/capture).
- **Defer**: intentionally not scheduled now.
- **Remove**: plan premise invalidated by current code.

Per-bundle readiness is tabulated after each bundle's item table; the most
load-bearing tags are also inlined on individual rows.

### 🟢 Bundle A: First-pass cleanup and modernization (cost-efficient implementation agent, e.g. Claude Sonnet, with themed branches)

Bundle A is a planning bundle, not a PR boundary. Split it into the themed branches in the commit/PR structuring section. A cost-efficient implementation agent is appropriate for bounded cleanup and build-setting work. Items that affect rendering, audio, power behavior, permissions, signing, Game Mode, or security require focused verification and stronger review.

"Bundle A" is a deliberately broad planning label: it spans work as different as deleting an orphaned file, flipping signing/Hardened Runtime, adding TCC privacy strings, and runtime rendering/audio changes. These do not share a failure mode or a review bar. The readiness tags below and the themed-branch split in the commit/PR structuring section are what keep that heterogeneity honest, do not read a uniform "ready to implement" into the table because rows look alike.

| # | Item | Files | Scope |
|---|------|-------|-------|
| A1 🟢 | **Delete the orphaned `Other Sources/VDKQueue/` directory.** Contains only `README.md`. VDKQueue was added in [`4686eb3`](https://github.com/MaddTheSane/Boxer/commit/4686eb310fe091d14edc8fe3043e8caecd69764f) (Alun Bestor, 2013-01-09); its source files (`VDKQueue.h`, `VDKQueue.m`) and 12 project.pbxproj references were removed in [`2840998`](https://github.com/MaddTheSane/Boxer/commit/284099826896add058deeaebd192f9bac3731577) "Remove VDKQueue." (C.W. Betts, 2020-07-16). The README was left behind by oversight. Safe to delete: zero references in source, project file, entitlements, schemes, or build settings; no replacement `FSEvent`/`kqueue`/`NSFilePresenter` code exists (Boxer's current approach just invalidates caches on app activation). | `Other Sources/VDKQueue/` | Small |
| A3 🟢 | **Fix `dispatch_get_current_queue()` to `dispatch_get_main_queue()`** at [Bundler/BBAppDelegate+AppExporting.m:21](Bundler/BBAppDelegate+AppExporting.m:21). The call has been in place since the Bundler was merged into mainline Boxer in [`839dfd57`](https://github.com/MaddTheSane/Boxer/commit/839dfd57) (Alun Bestor, 2012-11-02); the API was deprecated in macOS 10.6 and removed in 10.9. Surrounding context confirms the call site runs on the main queue, so the replacement preserves intent. | [Bundler/BBAppDelegate+AppExporting.m](Bundler/BBAppDelegate+AppExporting.m) | Small |
| A4 🟢 | **Delete the commented-out `@available(macOS 11, *)` block** at [BXExternalMIDIDevice.m:315-316](Boxer/BXExternalMIDIDevice.m:315). Commented out by C.W. Betts in [`858eb26`](https://github.com/MaddTheSane/Boxer/commit/858eb269) (2021-03-06, "Add nullability metadata.") while experimenting with the macOS 11 `MIDIEventList` API; never wired up. Two commented lines, safe to remove. | [BXExternalMIDIDevice.m](Boxer/BXExternalMIDIDevice.m) | Small |
| ~~A5~~ 🟢 ⏸️ | ~~Bump OpenEmu-Shaders submodule `0f9e7e3` → `2ac33a9` (Nov 2025)~~ **Deferred to Bundle C.** Empirical attempt showed the 117-commit jump removes Obj-C interop on `OEFilterChain`, `OEShaderParameter`, and the broader shader API surface (8 Boxer files, ~1000 LoC affected). Requires a multi-day rewrite of Boxer's shader integration to Swift or an Obj-C shim layer, not a small SHA bump. **Clean-build workaround for the current pin:** set `CMAKE_POLICY_VERSION_MINIMUM=3.5` in the build environment so the old vendored glslang/SPIRV-Tools CMake files survive CMake 4.x policy compatibility checks. Do not edit or stage `Vendor/OpenEmuShaders/3rdparty/Makefile`; that was only a local diagnostic workaround. | n/a | Deferred → Bundle C |
| A6 🟢 | Switch CwlDemangle SPM from `MaddTheSane@swift5Compat` (2020) → `mattgallagher/CwlDemangle@master` | [project.pbxproj](Boxer.xcodeproj/project.pbxproj) | Small |
| A7 🟢 | **`@synchronized` → `os_unfair_lock` in `BXMIDIDeviceMonitor`** - all 3 sites guarding `_discoveredMT32s` (the reader plus both writer paths), not "line 77 only" as originally scoped. All 3 lock the same list, so converting one in isolation splits mutual exclusion across two mechanisms. The correct conversion intrinsically (a) fixes a latent reassignment race (the KVO `mutableArrayValueForKey:` path reassigns `_discoveredMT32s` on every add/remove, so `@synchronized(_discoveredMT32s)` was already locking on unstable object identities), and (b) restructures the cold writers to mutate the ivar directly with manual `will/didChangeValueForKey:`, because `os_unfair_lock` is non-recursive and `mutableArrayValueForKey:` would re-enter the locked getter and deadlock. Both are unavoidable consequences of doing the conversion correctly, documented in the commit - not scope creep. The `ADBFileHandle.m` `@synchronized(self.sourceHandle)` sites originally listed here are **moved to B11** (the stable-lock-object choice there *is* the close-vs-read race fix; they cannot be separated). | [BXMIDIDeviceMonitor.m](Boxer/BXMIDIDeviceMonitor.m) | Medium (concurrency) |
| **A8** 🟢 | **Enable Hardened Runtime for Boxer target**: flip `ENABLE_HARDENED_RUNTIME = NO` → `YES` at lines 5361, 5412. Required for notarization, but do not land this as a standalone project-setting flip against the empty `Boxer.entitlements` stub on `maddsV2`. The hardening branch must either carry the populated JIT/library-validation entitlements as part of the same reviewed change or verify it only in a disposable `macos26` integration tree where Phase 1 has already populated them. | [project.pbxproj](Boxer.xcodeproj/project.pbxproj), possibly [Boxer.entitlements](Boxer/Boxer.entitlements) depending on branch base | Small |
| **A9** 🟢 | **Apply populated entitlements to Standalone target too**: wire `Boxer/Boxer.entitlements` into the Boxer Standalone target's build config so bundled gameboxes get JIT permissions. Same lineage caveat as A8: Standalone must not be hardened against an empty entitlements file. | [project.pbxproj](Boxer.xcodeproj/project.pbxproj), possibly [Boxer.entitlements](Boxer/Boxer.entitlements) depending on branch base | Small |
| **A10** 🟢 | **Add TCC usage descriptions to app Info.plists**: Tahoe will prompt for these on first access; without custom text the user sees ugly defaults. Add: `NSRemovableVolumesUsageDescription` (for CD/USB game discs), `NSNetworkVolumesUsageDescription` (for NAS/network shares), `NSDesktopFolderUsageDescription`, `NSDocumentsFolderUsageDescription`, `NSDownloadsFolderUsageDescription` (common gamebox locations). Apply to both Boxer and Boxer Standalone unless implementation proves a key is irrelevant to Standalone. | [Info.plist](Info.plist), [Standalone/Boxer Standalone-Info.plist](Standalone/Boxer%20Standalone-Info.plist) | Small |
| **A11** 🟢 | **Add `NSInputMonitoringUsageDescription` to app Info.plists**: required by macOS 10.15+ for the `IOHIDManager` calls in [ADBHIDMonitor.m:124,155](Other%20Sources/ADBToolkit/ADBHIDMonitor.m). Without it the gamepad enumeration triggers a generic-text prompt; user still has to enable Boxer in Settings → Privacy → Input Monitoring before joysticks work. Apply to both Boxer and Boxer Standalone because bundled gameboxes run through the Standalone app. | [Info.plist](Info.plist), [Standalone/Boxer Standalone-Info.plist](Standalone/Boxer%20Standalone-Info.plist) | Small |
| **A12** 🔴 | **Drop Intel: set `ARCHS = arm64` + slim SDL frameworks**: Boxer's first-party code is expected to build arm64-only; architecture-specific CPU-core paths are already gated (`C_DYNAMIC_X86` / `C_DYNREC`), so verify the arm64 dynrec path in the integration build rather than treating this as a pure mechanical setting. SDL2 + SDL2_net frameworks ship as universal; slim with `lipo -extract arm64 Frameworks/SDL2.framework/Versions/A/SDL2 -o ...` (same for SDL2_net). Tahoe already excludes most Intel Macs; net effect: ~7MB smaller distribution, simpler signing. **Fork-specific narrowing, not for upstream.** | [project.pbxproj](Boxer.xcodeproj/project.pbxproj), [Frameworks/SDL2.framework](Frameworks/SDL2.framework), [Frameworks/SDL2_net.framework](Frameworks/SDL2_net.framework) | Fork-specific small |
| **A13** 🟢 | **Enable Hardened Runtime for Boxer Standalone target**: same `ENABLE_HARDENED_RUNTIME = NO` → `YES` flip as A8. Without it, standalone game apps stamped out by Bundler won't notarize. Same lineage caveat as A8/A9: hardening and populated entitlements must be verified together. | [project.pbxproj](Boxer.xcodeproj/project.pbxproj), possibly [Boxer.entitlements](Boxer/Boxer.entitlements) depending on branch base | Small |
| **A14** 🟢 | **Share Boxer + Standalone schemes in workspace**: `Boxer.xcworkspace/xcshareddata/xcschemes/` currently only contains `Boxer CI.xcscheme` and `Boxer Bundler CI.xcscheme`. Add `Boxer.xcscheme` and `Boxer Standalone.xcscheme` (mirror the CI ones with `parallelizeBuildables = YES` etc.) so contributors see them in the scheme picker by default. | new scheme files | Small |
| **A15** 🟢 | **Delete the legacy `.pch` prefix header in Bundler.** `Bundler/Boxer Bundler-Prefix.pch` contains only `#import <Cocoa/Cocoa.h>`. Drop `GCC_PRECOMPILE_PREFIX_HEADER` and `GCC_PREFIX_HEADER` from the Bundler build config ([project.pbxproj lines 5242, 5280](Boxer.xcodeproj/project.pbxproj:5242)), delete the file, verify a clean build. The PCH was introduced alongside the Bundler merge in [`839dfd57`](https://github.com/MaddTheSane/Boxer/commit/839dfd57) (Alun Bestor, 2012-11-02), back when prefix headers were the Xcode default. Modern Xcode prefers per-file imports. | [project.pbxproj](Boxer.xcodeproj/project.pbxproj), delete `Bundler/Boxer Bundler-Prefix.pch` | Small |
| **A17** 🟢 | **Set `preferredFramesPerSecond` on `BXMetalRenderingView`** to match the active DOS mode's native refresh (70 for VGA Mode 13h, 60 for SVGA/SuperVGA, etc.), currently uses MTKView's default which on ProMotion 120Hz displays causes judder. Fixes frame pacing on M4 Pro/Max and M5 displays. | [Boxer/Metal Rendering/BXMetalRenderingView.m](Boxer/Metal%20Rendering/BXMetalRenderingView.m), [Boxer/Rendering/](Boxer/Rendering) (need to wire DOS mode → refresh rate) | Runtime |
| **A18** 🟢 | **Evaluate Metal layer color space** for the 8-bit path in [BXMetalLayer.m:45](Boxer/Metal%20Rendering/BXMetalLayer.m:45), currently `kCGColorSpaceITUR_709` (HDTV chromaticities). Compare `kCGColorSpaceDisplayP3` and `kCGColorSpaceSRGB` with screenshots and shader QA before deciding; Display P3 may be beneficial on modern panels but is not proven as the correct default for DOS-era color. The existing TODO at line 39 flags sRGB/non-shader behavior, not a settled P3 migration. | [BXMetalLayer.m](Boxer/Metal%20Rendering/BXMetalLayer.m) | Runtime experiment |
| **A19** 🟢 (Investigate) | **Set an explicit AVAudioEngine I/O buffer size** for lower MIDI/audio latency (default ~10ms; action games feel snappier with a smaller buffer). `AVAudioSession` does NOT apply on native macOS (iOS-family API; zero usage in this codebase). The macOS mechanism is the engine's I/O audio unit / output node buffer frame size (e.g. `kAudioDevicePropertyBufferFrameSize` on the HAL output unit); the SDL audio path is separate. Mechanism unverified: investigate before scheduling. | [BXMIDISynth.m](Boxer/BXMIDISynth.m), possibly the SDL audio path | Runtime (investigate) |
| ~~**A20**~~ 🟢 (Remove) | ~~Release `IOPMAssertionTypeNoDisplaySleep` while paused.~~ **Premise invalidated by current code.** `-[BXSession _shouldSuppressDisplaySleep]` ([BXSession.m:2378](Boxer/BXSession.m:2378)) already returns NO when `isPaused`/`isAutoPaused`/at-prompt, and `_syncSuppressesDisplaySleep` is invoked from 7 sites including the pause/suspend path ([BXSession.m:2187](Boxer/BXSession.m:2187)). The "held for the entire session lifetime" claim mis-cited the assertion's creation line (2361) as its lifetime. Release-on-pause already exists and is wired. Optional residual (Verify, no code change): confirm the background-autopause transition reaches `_syncSuppressesDisplaySleep`. | n/a | Removed |
| **A21** 🟢 | **Skip Metal redraws when the DOS framebuffer is unchanged.** Currently the renderer draws at display rate regardless of whether DOS has produced a new frame. Use the existing emulator delegate/frame-delivery path (`BXVideoFrame` updates) and only call `MTKView` `draw` when there's actual new content; otherwise let the view idle. Expected to reduce GPU work on menu screens and turn-based games; verify with runtime captures. | [BXMetalRenderingView.m](Boxer/Metal%20Rendering/BXMetalRenderingView.m), wire to [Boxer/Rendering/](Boxer/Rendering) | Runtime |
| **A22** 🟢 | **Adopt macOS Game Mode.** Add `LSSupportsGameMode = true` to both app plists. Treat this plist-only part as ready. Do not link `GameController.framework` here unless implementation-time documentation or testing proves it is required; framework adoption belongs with C0's GameController migration. Expected to improve sustained performance behavior on supported macOS versions; verify with runtime captures. | [Info.plist](Info.plist), [Standalone/Boxer Standalone-Info.plist](Standalone/Boxer%20Standalone-Info.plist) | Runtime |
| **A23** 🟢🔒 | **Fix CUE resource path validation (security-sensitive)**: referenced resources in a CUE import should resolve inside the CUE file's base directory before being copied into a gamebox. Add a containment check after path standardization and surface an import error for invalid entries. Apply it to both CUE resolution paths: `ADBBinCueImage` and `BXDriveBundleImport` parse/resolve resource paths separately. Keep detailed reproduction/regression steps in the dedicated security PR rather than in this roadmap. **Priority for upstream, affects all Boxer users.** | [ADBBinCueImage.m](Other%20Sources/ADBToolkit/ADBBinCueImage.m), [BXDriveBundleImport.m](Boxer/BXDriveBundleImport.m) | Security |
| **A24** 🟢 | **Cap MIDI SysEx length from guest** (defense-in-depth). `boxer_sendMIDISysex` in [BXCoalfaceAudio.mm:117](Boxer/BXCoalfaceAudio.mm:117) passes `Bitu len` straight to `[NSData dataWithBytesNoCopy:length:]`. DOSBox already bounds this internally, but adding `if (len > 65536) return;` is a trivial host-side cap against any future fuzzing or DOSBox bug. | [BXCoalfaceAudio.mm](Boxer/BXCoalfaceAudio.mm) | Small |
| **A25** 🟢 | **Small first-party deprecated-API swaps** (from a clean-build audit, ranked by frequency). (a) `NSReadPixel` (deprecated 10.14) → `NSBitmapImageRep.colorAt(x:y:)` at [CoverArt.swift](Boxer/CoverArt.swift) - ✅ **done** ("Replace deprecated NSReadPixel in CoverArt transparency"); turned out to be a type-fallback branch restructure, not the "1-line" originally scoped. (b) `CGCursorIsVisible` - **reshaped and moved to B20**: not a mechanical swap (no non-deprecated 1:1 exists; the correct fix is a tracked hide-state machine, with a documented Cmd-Tab edge case needing manual runtime QA). (c) `targetPath`: **reshaped and moved to B21**, not a mechanical swap. `targetPath` is a `__deprecated` property in the `BXGamebox (BXGameboxLegacyPathAPI)` category, backed by the legacy `BXTargetProgramGameInfoKey` game-info string plus a symlink fallback. There is no URL-typed replacement (`legacyTargetURL` is a read-only Boxer 1.3.x reader of that same legacy key, not a modern setter). The non-deprecated model is the separate `launchers`/`defaultLauncher` subsystem stored under a different game-info key, so removing the usage is a storage-model migration with behavioral QA, not a chore. Also 5 coupled sites, not 3: lines 106/145/238 plus the KVO keypaths at 62/86. With (a) done and (b)/(c) moved out, A25 is complete. | [CoverArt.swift](Boxer/CoverArt.swift) (done) | Small (a only) |
| **A26** 🟢🔒 | **Secure Bundler pasteboard row decoding.** The Bundler archives drag rows with the old keyed archiver API and decodes pasteboard data with `unarchiveObjectWithData:`. Treat pasteboard contents as untrusted input: migrate to secure coding APIs (`archivedDataWithRootObject:requiringSecureCoding:error:` and `unarchivedObjectOfClass:fromData:error:`), restrict decoding to `NSIndexSet`, handle decode errors, and validate the decoded indexes before `objectsAtIndexes:`. Small isolated security hardening, similar in shape to A24, and should land on its own branch rather than inside the cleanup branch. | [BBAppDelegate.m:568](Bundler/BBAppDelegate.m:568), [BBAppDelegate.m:597](Bundler/BBAppDelegate.m:597) | Security |

**Bundle A scope:** mostly small and medium implementation items, split into themed branches. Security and runtime-behavior items need focused verification and stronger review.

**Bundle A readiness**

| Item(s) | Readiness | Basis |
|---------|-----------|-------|
| A1, A3, A4, A6, A7, A15, A24 | Done | landed on `chore/cleanup-and-deps` |
| A25(a) | Done | NSReadPixel; A25(b) reshaped to B20, A25(c) to B21 |
| A5 | Defer | shader-submodule bump deferred to Bundle C |
| A8, A9, A13 | Ready after entitlement-lineage decision | hardening must be verified with populated entitlements, not the `maddsV2` stub |
| A10, A11, A14 | Ready | scoped build / plist / scheme edits |
| A12 🔴 | Ready | fork-only ARCHS + lipo, scoped |
| A23 🔒 | Ready | code-backed security fix; upstream priority, own branch |
| A26 🔒 | Ready | code-backed Bundler pasteboard hardening; own branch |
| A17 | Investigate | frame pacing needs DOS-mode-to-refresh wiring + runtime QA |
| A21 | Investigate | redraw-skip is a renderer-architecture change |
| A18 | Experiment | color-space choice is a visual judgement; screenshot QA |
| A19 | Investigate | macOS buffer-size mechanism unverified (not AVAudioSession) |
| A20 | Remove | already implemented in current code |
| A22 | Mixed | `LSSupportsGameMode` plist = Ready; GameController coupling = Investigate |

---

### 🟡 Bundle B: Refactors with care (cost-efficient implementation agent plus stronger review)

Each item is independently revertable. A cost-efficient implementation agent, e.g. Claude Sonnet, may draft the change when the checklist is explicit, but the developer should use stronger review for concurrency, Swift migration, locking, security, or runtime-behavior details.

| # | Item | Files | Scope |
|---|------|-------|-------|
| B1 🟢 | Migrate `NSInvocation` callbacks → direct `objc_msgSend` delegate dispatch. This is the `shouldCloseSelector` bridge code, not a simple block conversion; confirm call conventions during implementation. | [BXSession.m:714](Boxer/BXSession.m:714), [BXImportSession.m:315](Boxer/BXImportSession.m:315) | Medium |
| B3 🟢 | Replace `YRKSpinningProgressIndicator` (6+ call sites) with `NSProgressIndicator` style `Spinning`. UX-visible, needs screenshot QA. | [BXDOSWindowController](Boxer/DOS%20window/BXDOSWindowController.m), [BXHUDSpinningProgressIndicator](Boxer/BXHUDSpinningProgressIndicator.m), [BXProgramPanel](Boxer/BXProgramPanel.m), etc. | Visual QA |
| B4 🟢 | **Bump `SWIFT_VERSION` from `5.0` → `6.0`** for all 4 occurrences in [project.pbxproj](Boxer.xcodeproj/project.pbxproj). Swift 6 enforces data-race safety at compile time. Only 12 Swift files in the codebase, mostly UI/image generation, all relatively self-contained. Compiler will surface any required `Sendable` / `@MainActor` annotations. **Mandatory prerequisite (not optional):** first set `SWIFT_STRICT_CONCURRENCY = complete` under Swift 5, fix every warning, then bump to 6.0. Do not jump straight to 6.0. **Pre-adoption gate:** complete B22 before any migration starts relying on the ADBToolkit Swift URL helpers. Files: [CoverArt.swift](Boxer/CoverArt.swift), [BootlegCoverArt.swift](Boxer/BootlegCoverArt.swift), [MT32LCDDisplay.swift](Boxer/MT32LCDDisplay.swift), [DummyMIDIDevice.swift](Boxer/DummyMIDIDevice.swift), [NSImage+ADBImageEffects.swift](Other%20Sources/ADBToolkit/NSImage+ADBImageEffects.swift), [BXShadersModel+OpenEmu.swift](Boxer/Shaders/BXShadersModel+OpenEmu.swift), [BXShadersModel.swift](Boxer/Shaders/BXShadersModel.swift), + 5 ADBToolkit helpers. | Swift migration |
| B5 🟢 | **Unified Low Power / thermal power policy** (consolidates former B5 + B8 into one user-facing behavior, per review). One coherent design: observe `NSProcessInfoThermalStateDidChangeNotification` and throttle/pause emulation when `thermalState == .critical`; observe `NSProcessInfoPowerStateDidChangeNotification` and, when `ProcessInfo.processInfo.isLowPowerModeEnabled`, auto-throttle (halve the active DOSBox cycle count, or fall back to the gamebox's "lowest" cycle profile) with a one-time bezel ("Low Power Mode is on, performance reduced to extend battery"); restore prior settings when conditions clear. Warn, observe, and throttle are designed together, not as separate items. | new helper in [BXSession.m](Boxer/BXSession.m) / [BXSession+BXEmulatorControls](Boxer/BXSession+BXEmulatorControls.m), [BXBezelController.m](Boxer/BXBezelController.m) | Runtime (design) |
| B6 🟢 | **Pixel-perfect integer scaling audit**: Build, take screenshots at common DOS resolutions (320×200, 320×240, 640×480) on M-series Retina at various window sizes. Confirm DOS pixels render as integer multiples; if blurry, add a "snap to integer scale" preference. CRT shaders need this for sharp scanlines. | [BXMetalRenderingView.m](Boxer/Metal%20Rendering/BXMetalRenderingView.m), [BXDOSWindowController.m](Boxer/DOS%20window/BXDOSWindowController.m) | Visual QA |
| B7 🟢 | **Tahoe Liquid Glass HUD audit**: Boxer's custom `BXHUDWindow` chrome predates macOS dark mode and Liquid Glass. Replace custom dark-theme backgrounds with `NSVisualEffectView` (`.hudWindow` material) where appropriate so the HUD looks native to Tahoe. Visual-only change; check it doesn't break `BXThemes`. `NSVisualEffectView` has been around since 10.10 so this is upstream-friendly. | [BXHUDWindow.m](Boxer/BXHUDWindow.m), [BXThemes.m](Boxer/BXThemes.m), several inspector/bezel views | Visual QA |
| ~~B8~~ 🟢 ⏸️ | ~~Low Power Mode auto-throttle.~~ **Merged into B5** (unified Low Power / thermal power policy) per review: warn, observe, and throttle are one user-facing behavior and must be designed together. | n/a | Merged → B5 |
| B9 🟢 | **Audit `BXMIDIDeviceMonitor` threading and callback delivery.** The original "convert polling to CoreMIDI notifications" premise is already satisfied: the monitor registers a `MIDIClientCreate` notification callback at [BXMIDIDeviceMonitor.m:103](Boxer/BXMIDIDeviceMonitor.m:103), not timer polling. The residual work is concurrency. `_discoveredMT32s` is now correctly locked (A7 plus its follow-up), but `_listeners` is still mutated and enumerated without synchronization (including an unguarded `for ... in _listeners`), while CoreMIDI notification and input-listener callbacks arrive on different threads. Audit which work runs on which thread and give `_listeners` a single-owner or locked discipline. Same defect class as A7/B10/B11 but a distinct object: keep it separate. | [BXMIDIDeviceMonitor.m](Boxer/BXMIDIDeviceMonitor.m) | Concurrency (audit + fix) |
| B10 🟢 | **Fix property-based locking on `self.emulator`** at [BXSession.m:2147](Boxer/BXSession.m:2147). `@synchronized(self.emulator)` becomes a silent no-op if `self.emulator` is nil, possible if the property is cleared between the `isEmulating` check at line 2145 and the lock acquisition at 2147. Fix: lock on a stable ivar (a dedicated `_emulatorAccessLock`) or read `_emulator` into a local before locking. (A7 was re-scoped to `BXMIDIDeviceMonitor` only, so it no longer overlaps this `BXSession.m` site - but the *defect class* is identical to A7's reassignment race and B11's nil race: `@synchronized` on a mutable/nillable expression. Worth fixing all three consistently.) | [BXSession.m](Boxer/BXSession.m) | Locking |
| B11 🟢 | **Fix ADBFileHandle close-vs-read race.** [ADBFileHandle.m:823](Other%20Sources/ADBToolkit/ADBFileHandle.m:823) clears `self.sourceHandle = nil` outside any lock; reader at [line 893](Other%20Sources/ADBToolkit/ADBFileHandle.m:893) uses `@synchronized(self.sourceHandle)` which becomes a no-op once nilled. Subsequent method calls on the nil sourceHandle silently return 0, producing wrong-data reads instead of erroring out. Fix: lock on a stable ivar/lock object during both close and read; check for cleared handle inside the lock and error explicitly. **Now also subsumes the `@synchronized` → `os_unfair_lock` conversion of the 893/1019 sites originally scoped under A7** - converting `@synchronized(self.sourceHandle)` to a stable lock object *is* the race fix (same defect class as A7's reassignment race), so the cleanup and the correctness fix here are inseparable and must land together. Note `self.sourceHandle = nil` also occurs at line 975, not only 823. | [ADBFileHandle.m](Other%20Sources/ADBToolkit/ADBFileHandle.m) | Locking |
| B12 🟢 | **Add `NSApplicationPresentationDisableForceQuit` to fullscreen presentation options** (Tier 2 of the Accessibility-prompt reduction work). Boxer already toggles `NSApplicationPresentationDisableProcessSwitching` in `syncApplicationPresentationMode` at [BXBaseAppController.m:286](Boxer/Application%20Delegate/BXBaseAppController.m:286) when the mouse is locked; extend that bitmask to also include `NSApplicationPresentationDisableForceQuit` so a misfired ⌘-⌥-Esc doesn't kill an in-progress DOS session. The flag requires Dock-hide (already set when mouse is locked) so no new constraints. No permission required. Pairs cleanly with whatever currently exists for fullscreen entry/exit. **Follows on from the Tier 0+1 hotkey-prompt opt-in change at [BXKeyboardEventTap.m](Boxer/BXKeyboardEventTap.m:107) and [BXBaseAppController+BXHotKeys.m:390](Boxer/Application%20Delegate/BXBaseAppController+BXHotKeys.m:390).** **Safety constraint (review):** disabling Force Quit is user-hostile if Boxer itself hangs. Gate it on the narrowest condition (mouse locked AND emulation actively running AND fullscreen); never while paused, at the DOS prompt, or on the launcher panel. Keep an escape path: clear `NSApplicationPresentationDisableForceQuit` immediately on pause, focus loss, emulation stall/watchdog, or window-mode exit, so a hung session can always be force-quit. | [BXBaseAppController.m](Boxer/Application%20Delegate/BXBaseAppController.m) | Small + safety review |
| B13 🟢 | **Move arrow-key interception to `NSEvent.addLocalMonitorForEvents`** (Tier 3 of the Accessibility-prompt reduction work). Currently the CGEventTap captures arrow keys (Up/Down/Left/Right) at [BXBaseAppController+BXHotKeys.m:105-108](Boxer/Application%20Delegate/BXBaseAppController+BXHotKeys.m:105) - but macOS doesn't system-globally intercept arrow keys the way it does F-keys, so a local event monitor should suffice and would not require Accessibility. F1-F12 must stay on the event tap because macOS does pre-empt them for brightness/Mission Control/media keys at a level above app delivery. Result: users who don't need F-key pass-through in DOS games (most casual users) never need to grant Accessibility at all. **Empirical testing required**: validate arrow-key behavior in windowed mode (mouse locked & unlocked), fullscreen, mid-Mission-Control gesture, and with VoiceOver running. | [BXInputController.m](Boxer/DOS%20window/BXInputController.m), [BXBaseAppController+BXHotKeys.m](Boxer/Application%20Delegate/BXBaseAppController+BXHotKeys.m) | Medium (empirical) |
| B14 🟢 | **Pre-prompt explainers for TCC permissions.** A10 and A11 add Info.plist usage strings so the *OS dialog itself* has reasonable text, but there's no Boxer-side context shown *before* the OS prompt fires for the first time. Add a one-time, dismissible Boxer sheet at the call sites where TCC-protected APIs first fire - at minimum: first gamebox import that crosses into `~/Documents`/`~/Desktop`/`~/Downloads`, first removable-volume mount (CD/USB), first gamepad connection (Input Monitoring). The sheet should explain (1) what permission is about to be asked, (2) what happens if the user clicks Deny in the OS dialog, (3) how to grant it later via Settings. Boxer already has the equivalent pattern for Accessibility via [hotkeyWarningAlert](Boxer/Application%20Delegate/BXBaseAppController+BXHotKeys.m:341); B14 extends that pattern to filesystem/input prompts. As part of the same permission-handoff work, replace old `.prefPane` paths and `com.apple.systempreferences` ScriptingBridge usage in the Accessibility prompt flow with a modern System Settings URL handoff. **Depends on A10 and A11 landing first** (so the OS-prompt strings exist before the pre-prompt promises them). | [BXSession.m](Boxer/BXSession.m) (drive imports), [ADBHIDMonitor.m](Other%20Sources/ADBToolkit/ADBHIDMonitor.m) (first HID enumeration), [BXBaseAppController+BXHotKeys.m](Boxer/Application%20Delegate/BXBaseAppController+BXHotKeys.m) (Accessibility handoff), new explainer view/sheet | Small (copy + prompt flow) |
| B15 🟢 | **Tighten the existing hotkey-warning copy.** The current `hotkeyWarningAlert` strings at [BXBaseAppController+BXHotKeys.m:350,357,363](Boxer/Application%20Delegate/BXBaseAppController+BXHotKeys.m:350) say "macOS hotkeys won't interfere with Boxer's game controls" - accurate but vague. Update to: (a) name the specific keys affected (F1-F12), (b) clarify what works without the permission (arrow keys, media keys via `NX_SYSDEFINED` fallback path - see B13's split), (c) make the relationship between Accessibility and the degraded-mode `BXKeyboardEventTapTappingSystemEventsOnly` state visible to the user. Strings live in `Boxer/Resources/<locale>.lproj/Localizable.strings` and the auto-generated `Localizable.xcstrings` - update all locales or mark fallbacks. Pure copy change, no code refactor. **Best done alongside or just after B13** so the wording can accurately describe the post-B13 reality. | [BXBaseAppController+BXHotKeys.m](Boxer/Application%20Delegate/BXBaseAppController+BXHotKeys.m), [Localizable.xcstrings](Boxer/Resources/Localizable.xcstrings) | Small (copy + locales) |

| B16 🟢 | **Migrate legacy `NSCollectionView` grid API → `NSCollectionViewFlowLayout`.** Single highest-frequency first-party deprecation cluster: 24 of ~42 first-party deprecation warnings come from one pre-10.11 API family - `maxNumberOfColumns` (×10), `itemPrototype` (×6), `minItemSize` (×4), `maxItemSize` (×4). It is **one coherent migration, not four fixes**. Sites: [BXDocumentationBrowser.m](Boxer/Documentation%20Panel/BXDocumentationBrowser.m), [BXDocumentationPanelController.m](Boxer/Documentation%20Panel/BXDocumentationPanelController.m), [BXGameboxPanelController.m](Boxer/Inspector%20Panel/BXGameboxPanelController.m), [BXCollectionItemView.m](Boxer/BXCollectionItemView.m). UX-visible (documentation browser, gamebox/inspector panels) → **screenshot QA at common window sizes required**, same review shape as B3/B6/B7. | the 4 files above + their XIBs | Medium + Visual QA |
| B17 🟢 | **Investigate Boxer's self-deprecated classes** `BXProgramPanelController` (×4) and `BXStatusBarController` (×2). These are *Boxer's own* classes annotated `DEPRECATED_ATTRIBUTE`/`__attribute__((deprecated))` yet still referenced - not a macOS-API deprecation. **First step is a "why" pass, not a code swap**: determine whether they were superseded by a newer class (then finish/remove the migration) or whether the deprecation annotation is premature/stale (then drop the annotation). Resolution shape depends entirely on that finding; do not treat as a mechanical replacement. | [BXProgramPanelController](Boxer/DOS%20window/BXProgramPanel.m), [BXStatusBarController](Boxer/DOS%20window/BXStatusBarController.m), + referencing sites | Investigate |
| B18 🟢 | **Replace deprecated `-[NSView dragImage:at:offset:event:pasteboard:source:slideBack:]`** (×2) with `-[NSView beginDraggingSessionWithItems:event:source:]` (`NSDraggingSession`). API-shape change (drag-item providers + `NSDraggingSource` conformance), not a one-liner. Enumerate the 2 sites from a clean build before editing. Modest visual/interaction QA (drag-and-drop still works). | drag sites (audit from build log) | Small–Medium |

| B19 🔴🟢 | **Triage Xcode 26's "Update to recommended settings" for `Boxer.xcodeproj`** (first-party - actionable, unlike the submodule prompts which are the dirty-submodule trap). **Never blanket-"Perform Changes".** The actual sheet (verified from the Xcode UI, not derivable via CLI): Dead Code Stripping ×4 (Boxer/Standalone/Bundler targets + project), "Use Recommended macOS Deployment Target" ×3, Boxer Standalone code-signing `CODE_SIGN_IDENTITY="-"` ×2, `ENABLE_USER_SCRIPT_SANDBOXING`, String Catalog Symbol Generation, "-target" parallelization, (Asset Symbol Extensions - leave off). **Two mandatory exclusions:** (1) 🛑 `ENABLE_USER_SCRIPT_SANDBOXING` - **do NOT enable**; empirically deadlocks the OpenEmuShaders `ToolDependencies` build (the "Internal inconsistency / never received target ended" failure diagnosed this session; the working build depends on it staying off). (2) 🛑 "Use Recommended macOS Deployment Target" - Xcode recommends a generic floor (~macOS 11/12); the fork's deliberate intent is **26.0** (Phase 1 narrowing). Set deployment target per the plan (26.0), **not** Xcode's recommendation. **Branch constraint:** do this on a `macos26`-derived branch, not a `maddsV2`-derived cleanup branch - on `maddsV2` the deployment target is still the pre-Phase-1 `10.14.4`, so the decision would be made against the wrong baseline and collide at merge. Accept-able subset, each clean-build-verified individually: Dead Code Stripping (**plus a run-a-game smoke test** - link-behavior change for an emulator + vendored C/C++), Standalone `CODE_SIGN_IDENTITY="-"`, String Catalog Symbol Generation, "-target" parallelization. | [project.pbxproj](Boxer.xcodeproj/project.pbxproj) | Medium (per-setting verify; partly fork-narrowing) |

| B20 🟢 | **Replace deprecated `CGCursorIsVisible()` with a tracked cursor hide-state machine** at [BXInputController.m:1030](Boxer/DOS%20window/BXInputController.m:1030) (reshaped out of A25(b) - *not* a mechanical swap, which is why it left the cleanup bundle). `CGCursorIsVisible()` was deprecated because the pattern is wrong: it queries *global* cursor visibility to avoid stacking `[NSCursor hide]` (a balanced hide/unhide stack - the code's own comment at 1027-1029 admits "we have no way of knowing the current stack depth"). Correct fix: track our own hide state in a BOOL ivar so exactly one `hide` balances one `unhide`, applied symmetrically across `-_applyMouseLockState:` lock (1024-1059) and unlock (1060-1099). **Known edge case that must not regress:** the unlock path is *deliberately* asymmetric (guarded hide, unconditional unhide) per the comment at [BXInputController.m:1095](Boxer/DOS%20window/BXInputController.m:1095) - *"we used to check CGCursorIsVisible when unhiding, as with hiding, but this broke with Cmd-Tabbing."* Any replacement must be runtime-verified on the Cmd-Tab-while-mouse-locked path; a build cannot confirm it, and a naive symmetric rewrite risks reintroducing the exact bug the asymmetry works around. | [BXInputController.m](Boxer/DOS%20window/BXInputController.m) | Runtime (manual QA: mouse-lock hide/show + Cmd-Tab during lock) |

| B21 🟢 | **Migrate the gamebox inspector panel off the deprecated `targetPath` legacy API onto `launchers`/`defaultLauncher`** (reshaped out of A25(c); not a mechanical swap, which is why it left the cleanup bundle). `-[BXGamebox targetPath]` ([BXGamebox.h:342](Boxer/BXGamebox.h:342), `__deprecated`) is backed by the legacy `BXTargetProgramGameInfoKey` game-info string and old-style symlink ([BXGamebox.m:1314](Boxer/BXGamebox.m:1314)); `legacyTargetURL` ([BXGamebox.h:148](Boxer/BXGamebox.h:148)) is a read-only reader of that same legacy key, not a writable replacement. The modern model is the `launchers`/`defaultLauncher`/`defaultLauncherIndex` subsystem persisted under a different game-info key (`BXLaunchersGameInfoKey`). Sites in [BXGameboxPanelController.m](Boxer/Inspector%20Panel/BXGameboxPanelController.m): setter at 106, getters at 145 and 238, plus the KVO keypaths `@"content.gamebox.targetPath"` at 62 and 86, which must be re-pointed or the panel stops refreshing. Behavioral change: it moves where the inspector persists the default program (legacy key to launchers array), so it needs back-compat QA against existing gameboxes whose default program lives only in the legacy key/symlink, plus KVO-refresh verification. Decide during implementation whether to migrate-on-write or keep reading the legacy key as a fallback. Deprecated sites also exist outside the inspector: `BXProgramPanelController` sets and reads `targetPath` ([BXProgramPanelController.m:281,284,298,318](Boxer/DOS%20window/BXProgramPanelController.m:281)) and calls deprecated `validateTargetPath:` ([:292](Boxer/DOS%20window/BXProgramPanelController.m:292)). But `BXProgramPanelController` is itself `__deprecated` ([BXProgramPanelController.h:19](Boxer/DOS%20window/BXProgramPanelController.h:19)) and is exactly the class B17 investigates, so B21's scope over it is **contingent on B17**: if B17 finds the class dead or superseded those sites disappear with it; if it stays, B21 must migrate them too. Sequence B21 after B17. | [BXGameboxPanelController.m](Boxer/Inspector%20Panel/BXGameboxPanelController.m), [BXGamebox.m](Boxer/BXGamebox.m), [BXProgramPanelController.m](Boxer/DOS%20window/BXProgramPanelController.m) (contingent on B17) | Medium (behavioral + back-compat QA) |
| B22 🟢 | **Audit ADBToolkit Swift URL helper parity before Swift adoption.** The Swift `URL+ADBFilesystemHelpers` port is currently unused by live code, which still uses the Objective-C `NSURL+ADBFilesystemHelpers` category, so this is a pre-adoption gate rather than a production bug. Before B4 or any later migration relies on the Swift helpers, compare behavior against the Objective-C category and fix confirmed divergence: the relative-path slice upper bound in `pathRelative(to:)`, the non-advancing `componentURLs` loop, and the `conforms(toFileType:)` early return that skips the extension fallback needed for generic folder/data UTIs. Add the smallest feasible tests or manual verification notes. | [URL+ADBFilesystemHelpers.swift:69](Other%20Sources/ADBToolkit/URL+ADBFilesystemHelpers.swift:69), [URL+ADBFilesystemHelpers.swift:108](Other%20Sources/ADBToolkit/URL+ADBFilesystemHelpers.swift:108), [URL+ADBFilesystemHelpers.swift:234](Other%20Sources/ADBToolkit/URL+ADBFilesystemHelpers.swift:234), [NSURL+ADBFilesystemHelpers.m](Other%20Sources/ADBToolkit/NSURL+ADBFilesystemHelpers.m) | Swift migration prerequisite |
| B23 🟢 | **Migrate local user notifications to UserNotifications.framework.** `NSUserNotification` / `NSUserNotificationCenter` are deprecated, but the existing `ADBUserNotificationDispatcher` is a deliberate compatibility abstraction with availability gating, so preserve that shape rather than scattering notification logic through callers. Investigate `UNUserNotificationCenter` authorization behavior in dev and ad-hoc builds, preserve click activation callbacks for import/print notifications, and keep fallback behavior explicit for any supported macOS versions where the old shim is still needed. | [ADBUserNotificationDispatcher.m](Other%20Sources/ADBToolkit/ADBUserNotificationDispatcher.m), [BXSession+BXPrinting.m:152](Boxer/BXSession+BXPrinting.m:152), [BXImportSession.m:1275](Boxer/BXImportSession.m:1275) | Runtime / UX investigate |

**Bundle B scope:** medium refactors, generally one PR per item. Treat Swift, locking, runtime, and visual changes as higher-review work even when the diff is compact.

**Bundle B readiness**

| Item(s) | Readiness | Basis |
|---------|-----------|-------|
| B14, B15 | Ready | B14 depends on A10/A11 and includes prompt-flow handoff code; B15 is copy/locales |
| B3, B16 | Ready (visual QA) | UX-visible refactors; screenshot QA |
| B1, B10, B11, B17, B18, B19, B21 | Investigate | API / locking / defect-class work needing per-item reasoning + tests |
| B9 | Investigate | re-scoped to monitor threading/callback audit |
| B13 | Investigate | arrow-key local monitor needs empirical testing |
| B12 | Investigate (caution) | disabling Force Quit is hostile if Boxer hangs; needs a narrow trigger + escape path |
| B4 | Investigate | Swift 6 bump; do a mandatory Swift-5 `SWIFT_STRICT_CONCURRENCY=complete` pass first |
| B5 | Defer (design) | unified Low Power / thermal power policy (former B5 + B8 merged); warn + observe + throttle designed together |
| B6, B7 | Experiment | integer-scaling / Liquid-Glass HUD audits are measurement / visual dependent |
| B20 | Investigate (runtime QA) | CGCursorIsVisible state machine; Cmd-Tab edge case manual QA |
| B22 | Investigate | latent Swift URL helper parity gate; currently unused by live code |
| B23 | Investigate | UserNotifications authorization and activation behavior differ from `NSUserNotification` |

---

### 🔴 Bundle C: Larger projects, defer (not for cost-efficient-only delegation)

These each warrant their own focused PR with manual testing. A cost-efficient implementation agent may help with small substeps, but should not own the overall design or final review.

Every C item must record an explicit **integration mechanism decision** (which of the five mechanisms in the Third-party integration architecture section it should end up in), not just a version bump. Investigation branches for C items (notably C0 GameController and C1 Sparkle 2) may be started earlier, in parallel with cleanup, as long as they stay investigation-only and are not jammed into Bundle A; this de-risks the larger work without committing to implementation.

| # | Item | Why deferred |
|---|------|--------------|
| C1 🟢 | **Sparkle 1.23 → current Sparkle 2 stable** | Major version, API change (`SUUpdater` → `SPUUpdater`). Security-positive (EdDSA signing, hardened-runtime support, sandbox-friendly XPC services). Large refactor plus auto-update flow testing. Do not hardcode a target version: audit the latest Sparkle 2 release (stable, or a deliberately chosen beta) at implementation time. **Integration mechanism decision:** Sparkle is already SPM (mechanism #3); keep it SPM, pinned to a tag. |
| C2 🟢 | **MT32Emu fork → upstream munt** | Roland MT-32 audio behavior changes. Needs manual audio QA on real games. Current fork not updated since March 2022. Version target (`munt_2_7_0`) is as of plan authoring; revalidate the current upstream munt release at implementation time. **Integration mechanism decision:** MT32Emu is mechanism #2 (nested-subproject submodule); decide submodule-at-tag vs. moving to SPM as part of this work. |
| C3 🟢 | **DOSBox-Staging, investigate eduo's fork** | Boxer's pinned fork (`MaddTheSane/dosbox-staging boxer-compat`) has not been updated since March 2022. Upstream is at 0.82.2 / 0.83-RC1, with multiple releases of emulation improvements since then. The `eduo` fork (`eduo/dosbox-staging`) has updates as of Nov 2025 and existing Boxer contribution history. **First step: read eduo's fork to understand what macOS-specific patches it carries, then propose a path forward. Do not bump the submodule blindly.** This could be a high-impact upstream contribution. Version figures here (0.82.2 / 0.83-RC1; eduo updates "as of Nov 2025") are as of plan authoring; revalidate against upstream and the eduo fork at implementation time. **Integration mechanism decision:** DOSBox-Staging is mechanism #1 (submodule compiled into target); decide submodule-at-tag vs. another mechanism as part of the path proposal. |
| C4 🟢 | Retire `BXDOSWindowControllerLion` subclass. Lion-era fullscreen overrides; modern macOS handles fullscreen natively. Migrate behavior to parent class and rewire `DOSWindow.xib` + `DOSImportWindow.xib`. | Large refactor plus XIB editing. |
| **C0** 🟢 (promoted from C5) | **GameController framework migration** (replace DDHidLib for joystick). Expected benefits include broader modern-controller support, battery-level reporting, and no Input Monitoring prompt for GameController-backed devices. Promote above other C-items if gamepad UX is the goal. Track alongside the existing DDHidLib path during migration, then retire DDHidLib after validation. | Multi-day, high user-perceived impact. |

---

## Third-party integration architecture

The plan above updates *which* third-party components ship; this section is
about *how* they are integrated. Boxer currently uses **five inconsistent
mechanisms**, and that inconsistency is itself debt - it is the multiplier
on every C-item's difficulty (the OpenEmuShaders CMake/dirty-submodule
ordeal, un-scopeable DOSBox warnings, floating SPM deps, unidentifiable
copied-in source all trace to a mechanism choice, not a version).

| # | Mechanism | Components | Auditability |
|---|---|---|---|
| 1 | Submodule source compiled into first-party targets | DOSBox-Staging | SHA only; not isolatable as a unit |
| 2 | Submodule as nested `.xcodeproj` → framework | MT32Emu, DDHidLib, OpenEmuShaders | SHA + its own build system (worst friction) |
| 3 | SPM (`XCRemoteSwiftPackageReference`) | CwlDemangle, Sparkle | Good - pinned; lockfile now tracked |
| 4 | Committed prebuilt binary framework | SDL2, SDL2_net | Opaque - binary in git, version unknowable |
| 5 | Raw source copied in, no upstream link | RegexKitLite, BGHUDAppKit, MCAdditions, YRK, loose `.h/.m` | None - origin/version unrecoverable for several (e.g. `NSData+HexStrings` ships with no copyright at all) |

A standing provenance manifest was deliberately **not** created: it would
be ~60% "unknown", rot against reality, duplicate git history for the one
local-mod worth recording, and be obsoleted by mechanism convergence
(SPM pins record origin/version/license verifiably and automatically).
The provenance investigation's durable conclusions live structurally in
this section and in Bundle D (D4 identifies the unknowns; D5 captures
that `ADBToolkit` is first-party, miscategorized under `Other Sources/`).

**Principle going forward:** SPM pinned to a tag with a committed
lockfile (mechanism #3) is the auditable default. Prefer it. Treat
mechanisms #2 and #5 as the ones to *eliminate over time*, not extend.
**C1/C2/C3 must be integration-aware:** each should ask "should this stay
in its current mechanism, or move to #3 while we're in here?" rather than
just bumping a pinned SHA - otherwise three C-items independently
re-fight the same structural friction.

### 🔴 Bundle D: Converge third-party integration (strategic, deferred)

Not a near-term bundle. Wholesale convergence of the five mechanisms
toward one (SPM-pinned-with-lockfile where possible; submodule-at-tag
otherwise). Multi-week, interleaves with C1/C2/C3, and should only be
undertaken deliberately - doing it half-way (per-component, ad hoc) is
strictly worse than not starting. Sketch, not commitments:

| # | Item | Notes |
|---|---|---|
| D1 | Move SPM deps to tagged versions (not branch-tracked) | CwlDemangle is now `branch=master`; Sparkle is a range. Pin to tags; lockfile already tracked (depends on the committed-`Package.resolved` work). **May be pulled forward independently of the rest of Bundle D:** it is small, self-contained, and a branch-tracked `master` dependency is exactly the fragility this plan otherwise avoids, so it need not wait for the full convergence effort. |
| D2 | Re-evaluate mechanism #2 (nested-subproject submodules) | As C1/C2/C0 land, decide whether MT32Emu/OpenEmuShaders/DDHidLib should become SPM packages or stay submodules-at-tag. DDHidLib is retired by C0 - one fewer. |
| D3 | Replace committed binary SDL frameworks (#4) with a reproducible source/SPM build or a recorded, scripted fetch | Removes opaque binaries from git; makes SDL version auditable and updatable. Interacts with A12 (arch slimming). |
| D4 | Resolve every mechanism-#5 component | First identify origin/version where unrecorded (no standing manifest - record it in the resolving commit/PR, not a rot-prone doc). Dispositions: YRK→B3, BGHUDAppKit→(B7 cross-link), RegexKitLite→explicit decision (remove vs. keep-and-own), MCAdditions→audit (snippet from a defunct tutorial), `NSData+HexStrings`→identify or replace (no copyright/license in source), ScriptingBridge headers (`Finder.h`, `SystemPreferences.h`)→regenerate-on-demand, not vendored. |
| D5 | Recategorize `ADBToolkit` | First-party (Alun Bestor, Boxer's author) - does not belong under `Other Sources/`. Move/relabel so "third-party" actually means third-party. |

**Bundle D is fork-strategic (🔴):** it changes project structure, not
upstream-cherry-pickable behavior. Land after the upstream-friendly work;
keep it off the 🟢 themed branches.

---

### Security note

Security-sensitive items are kept specific enough to guide implementation, but this public roadmap avoids publishing a full exploit recipe before a dedicated fix PR exists. The fix PR should include the reproduction/regression check, expected behavior before and after the patch, and any maintainer-facing disclosure needed for upstream review.

---

## Commit / PR structuring for upstream-friendliness

Goal: land each 🟢 item as a self-contained commit so it can be cherry-picked into an upstream PR. Full branch naming and convention guidance lives in `AGENTS.md`. Short version:

1. **Themed branches, not bundle-as-PR.** Each plan bundle splits into focused themed branches at implementation time. Bundle A breaks into focused branches by failure mode, such as `build/signing-and-notarization`, `build/privacy-usage-strings`, `fix/cue-resource-validation`, and `perf/metal-frame-scheduling`. Bundle B items typically map 1:1 to a branch each. Bundle C items each get their own dedicated branch.
2. **Commits within a branch.** Each commit is a single focused change with a focused message ("Fix dispatch_get_current_queue removed in macOS 10.9", not "Bundle A item 3"). 🔴 fork-specific items live on dedicated `macos26/*` branches, not mixed into the themed 🟢 branches.
3. **Branch off `maddsV2`.** Every topic branch starts from the fork's `maddsV2` (which mirrors upstream). PR target is `macos26` (the personal working branch). This keeps each themed branch cleanly cherry-pickable for upstream later.
4. **Upstream submission.** After a themed branch merges into `macos26`, evaluate whether to send it upstream. Create an `upstream/<topic>` branch from `maddsV2`, cherry-pick or recreate the relevant commits, and follow `AGENTS.md` for upstream AI-assistance disclosure and trailer handling before filing a PR to `MaddTheSane/Boxer:maddsV2`.
5. **Priority order for upstream.** A23 🔒 (CUE resource path validation) is the **next branch to cut, ahead of remaining cleanup**: it is code-backed, isolated, user-impacting, and upstreamable. Land it on its own `fix/cue-resource-validation` branch and propose it upstream first and soon. Remaining cleanup and other 🟢 themed branches follow after.

### Suggested themed branches for Bundle A

Consolidated for solo-dev workflow, but split by failure mode where review risk differs. Each item still lands as its own commit within its branch, so upstream cherry-picks remain per-item.

| Branch | Plan items | Notes |
|--------|-----------|-------|
| `chore/cleanup-and-deps` | A1, A3, A4, A6, A7, A15, A24, A25(a) + the Tier 0+1 hotkey-prompt opt-in change (see [BXKeyboardEventTap.m:107](Boxer/BXKeyboardEventTap.m:107)) | Cleanup, deprecated-API replacements (A25(a) NSReadPixel; A25(b) reshaped to B20 and A25(c) to B21 as non-mechanical), dep refresh, concurrency hot-paths, defense-in-depth, permission-prompt UX. All small, all upstream-friendly individually. Mechanical item set complete. |
| `build/signing-and-notarization` | A8, A9, A13 | Hardened Runtime on (Boxer + Standalone), Standalone entitlements wired. Failure mode: codesign / notarization. Land first: A8 unlocks entitlement enforcement. Must include or integrate with populated JIT/library-validation entitlements, not the empty `maddsV2` stub. |
| `build/privacy-usage-strings` | A10, A11 | TCC usage descriptions in Boxer and Standalone app plists. Failure mode: first-run permission UX. |
| `build/share-workspace-schemes` | A14 | Workspace schemes (unlocks command-line builds without the CI scheme). |
| `feat/game-mode` | A22 | `LSSupportsGameMode` plist (Ready); any GameController framework coupling is Investigate and pairs with C0. Plist-only part can land alone. |
| `perf/metal-frame-scheduling` | A17, A21 | Frame pacing + redraw-skip. Renderer-architecture changes; A21 after design review. Runtime QA. |
| `experiment/metal-color-space` | A18 | Metal color-space comparison. Screenshot / color QA only. |
| `investigate/audio-latency` | A19 | AVAudioEngine I/O buffer size; correct macOS mechanism unverified. Investigation branch. |
| `fix/cue-resource-validation` | A23 🔒 | Security item kept on its own branch for upstream-priority focus. |
| `fix/bundler-pasteboard-secure-decoding` | A26 🔒 | Security item kept on its own branch for upstream-friendly isolation. |
| `macos26/drop-intel-arch` | A12 🔴 | Fork-only narrowing; segregated from upstream-bound work. |

A5 (OpenEmu-Shaders bump) is **deferred to Bundle C**. Empirical research showed the 117-commit jump from `0f9e7e3` → `2ac33a9` removes Obj-C interop on `OEFilterChain`/`OEShaderParameter`/etc., requiring a multi-day rewrite of Boxer's shader integration (8 files, ~1000 LoC affected). Not a small SHA bump. See Bundle C considerations.

Within each branch, commit per item with a focused message (e.g., "Remove orphaned VDKQueue README", not "Bundle A item 1"). This preserves per-item upstream cherry-pick capability.

---

## Verification & benchmarks

Two-track measurement, both committed to the repo so deltas are auditable.

### Track 1: static snapshot (automated)

`tools/bench.sh [label]` runs in ~30 seconds, no submodules or build required. It is a static **inventory** snapshot (file/marker counts, build settings, dependency pins), not a runtime benchmark; the name is historical. Real performance evidence (frame pacing, energy, audio latency) lives in the runtime-capture section and must be measured on hardware. Do not over-read the static deltas as performance results.
Outputs a markdown snapshot covering:
- Source size (LoC, file counts) for Boxer's own code vs. vendored
- Deprecated-API marker counts (`OSSpinLock`, `NSAutoreleasePool`, `WebView`,
  `kAudioUnitSubType_DLSSynth`, `AUGraph`, `@available`, `@synchronized`,
  `NSInvocation`, `Carbon`, `RegexKitLite`)
- Submodule pinned commits + Swift Package versions
- Build settings (`MACOSX_DEPLOYMENT_TARGET`, `SWIFT_VERSION`, `ARCHS`,
  `ENABLE_HARDENED_RUNTIME`, `MTL_LANGUAGE_REVISION`, …)
- Tahoe TCC hygiene (which usage-description plist keys are present,
  `LSSupportsGameMode`, entitlements file populated)
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
- Tahoe TCC rows: all missing to present in both app plists after the privacy usage strings branch. `LSSupportsGameMode` becomes present in both app plists after the Game Mode branch.
- `ARCHS`: (unset) → arm64 only on the fork-specific A12 branch.
- `ENABLE_HARDENED_RUNTIME`: mixed → YES after the hardening branch.
- SDL2 / SDL2_net frameworks: universal → arm64 only on the fork-specific A12 branch (~7 MB saved).

### Track 1b: build wrapper

Use `tools/build.sh` for local and post-merge builds. It keeps the OpenEmuShaders
CMake policy workaround out of the submodule and lets fast Apple Silicon machines
use Xcode's parallel scheduler without hardcoding a job count into project files:

```bash
tools/build.sh --scheme "Boxer CI" --configuration Release --timing
```

By default the script passes `-parallelizeTargets` and `-jobs` using
`hw.activecpu` (falling back to `hw.ncpu`). To tune for a smaller or busier
machine, set `BOXER_XCODE_JOBS`, for example:

```bash
BOXER_XCODE_JOBS=6 tools/build.sh --scheme "Boxer CI" --configuration Release
```

Set `BOXER_XCODE_PARALLEL=0` or pass `--no-parallel` to leave scheduling entirely
to Xcode defaults. `tools/bench.sh --build` calls this wrapper and records the
scheme, job count, and CMake policy value in the benchmark output.

### Pre-merge integration check (disposable macos26 worktree)

Themed branches are `maddsV2`-derived and Phase-1-free by design, so they
do not build standalone on a current Xcode, and a `bench.sh` run on them
shows Phase-1 lineage artifacts, not real deltas. Do not treat
"post-merge on `macos26`" as the first verification point: that discovers
failures after the integration decision. Before opening or merging a
themed PR:

1. Create a disposable worktree from `macos26`.
2. Merge the themed branch into it WITHOUT committing.
3. Run `tools/bench.sh`, the relevant build, and any manual checks there.
4. Record `BENCHMARKS.md` artifacts only from this `macos26` integration
   result, never from the standalone themed branch.
5. Discard the worktree.

Use `tools/premerge-check.sh <topic-branch>` for the automated version of
this workflow. The script uses a managed integration worktree, resets it to
fresh `macos26`, syncs submodules before and after the trial merge, writes the
bench snapshot to an artifact directory outside the topic branch, and runs
`tools/build.sh` there. If the managed worktree is dirty from an interrupted
run, inspect it or rerun with `--reset-managed`. Use `--deep-clean-shaders`
when stale ignored OpenEmuShaders build products are suspected.

Optionally keep a separate static `maddsV2` snapshot if upstream-only
deltas matter: the current `BENCHMARKS.md` baseline is explicitly a
Phase-1 lineage artifact and is not comparable to a `maddsV2`-derived
branch in isolation.

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
   sharply under the existing display-sleep suppression logic. This is now
   residual verification for the removed A20 premise, not an implementation
   milestone.
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
- All TCC plist keys present, `LSSupportsGameMode = true`,
  `ENABLE_HARDENED_RUNTIME = YES` consistently.
- Universal SDL frameworks slimmed to arm64.
- 60 s gameplay frame variance reduced (A17 frame pacing fix).
- Paused-session CPU% dropping below 5 %, verifying existing pause/display-sleep suppression behavior.
- Static-scene games drawing only when frame changes (A21).
- Energy Impact in Activity Monitor stays "Low" / "Medium" during typical
  gameplay; Game Mode (A22) participates in supported macOS scheduling behavior.

---

## Verification (post Bundle A)

1. **Build**: `tools/build.sh --scheme "Boxer CI" --configuration Release --timing` completes cleanly. A nonzero `@available(macOS <26)` marker count is expected and should not be treated as a failure.
2. **Hardened runtime check**: `codesign -d --entitlements - Build/Products/Release/Boxer.app` shows the JIT entitlements are present.
3. **Tahoe TCC flow**:
   - Launch Boxer fresh; import a gamebox from `~/Documents`. TCC prompt appears with custom text from `NSDocumentsFolderUsageDescription`.
   - Insert a USB stick or mount a game CD. TCC prompt for removable volumes appears with custom text.
4. **Joystick flow**: Plug in a gamepad, launch a game that uses it. First-run: TCC "Input Monitoring" prompt appears with custom text. After enabling Boxer in Settings → Privacy → Input Monitoring, gamepad input works.
5. **MIDI audio**: Open a GM-music game; confirm music plays through Apple's General MIDI synth. Check program-change response by listening for instrument changes mid-song.
6. **Update check**: Help → Check for Updates still works (Sparkle 1.x is untouched in Bundle A).

---

## Upstream proposals

Moved to [docs/upstream-proposals.md](upstream-proposals.md): proposals that belong to the upstream maintainer (e.g. UP1, raising the `maddsV2` macOS floor), kept out of the active work plan because they are not action items for cleanup branches.

---

## AI assistance disclosure

Parts of this planning document were drafted with AI assistance and edited by Andy Volk. Implementation PRs should disclose meaningful AI assistance separately and describe the build or manual checks performed.
