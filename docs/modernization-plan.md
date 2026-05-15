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
| ~~A5~~ 🟢 ⏸️ | ~~Bump OpenEmu-Shaders submodule `0f9e7e3` → `2ac33a9` (Nov 2025)~~ **Deferred to Bundle C.** Empirical attempt showed the 117-commit jump removes Obj-C interop on `OEFilterChain`, `OEShaderParameter`, and the broader shader API surface (8 Boxer files, ~1000 LoC affected). Requires a multi-day rewrite of Boxer's shader integration to Swift or an Obj-C shim layer, not a small SHA bump. **Workaround currently in use:** a local-only `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` edit in `Vendor/OpenEmuShaders/3rdparty/Makefile` to bypass CMake 4.x policy compatibility with the older pin's vendored SPIRV-Tools. The Makefile edit is submodule-local; it does not track in the Boxer repo. | n/a | Deferred → Bundle C |
| A6 🟢 | Switch CwlDemangle SPM from `MaddTheSane@swift5Compat` (2020) → `mattgallagher/CwlDemangle@master` | [project.pbxproj](Boxer.xcodeproj/project.pbxproj) | Small |
| A7 🟢 | **`@synchronized` → `os_unfair_lock` in `BXMIDIDeviceMonitor`** — all 3 sites guarding `_discoveredMT32s` (the reader plus both writer paths), not "line 77 only" as originally scoped. All 3 lock the same list, so converting one in isolation splits mutual exclusion across two mechanisms. The correct conversion intrinsically (a) fixes a latent reassignment race (the KVO `mutableArrayValueForKey:` path reassigns `_discoveredMT32s` on every add/remove, so `@synchronized(_discoveredMT32s)` was already locking on unstable object identities), and (b) restructures the cold writers to mutate the ivar directly with manual `will/didChangeValueForKey:`, because `os_unfair_lock` is non-recursive and `mutableArrayValueForKey:` would re-enter the locked getter and deadlock. Both are unavoidable consequences of doing the conversion correctly, documented in the commit — not scope creep. The `ADBFileHandle.m` `@synchronized(self.sourceHandle)` sites originally listed here are **moved to B11** (the stable-lock-object choice there *is* the close-vs-read race fix; they cannot be separated). | [BXMIDIDeviceMonitor.m](Boxer/BXMIDIDeviceMonitor.m) | Medium (concurrency) |
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
| **A25** 🟢 | **Small first-party deprecated-API swaps** (from a clean-build audit of first-party deprecation warnings, ranked by frequency). Three independent, mechanical replacements, one atomic commit each within `chore/cleanup-and-deps`: (a) `NSReadPixel` (deprecated 10.14) → `-[NSBitmapImageRep colorAtX:y:]` at [CoverArt.swift:234](Boxer/CoverArt.swift:234) — ×2, one-line; (b) `CGCursorIsVisible` (deprecated) at [BXInputController.m:1030](Boxer/DOS%20window/BXInputController.m:1030) — ×2, replace with a tracked cursor-visibility state or `NSCursor`-based check; (c) `targetPath` (deprecated alias/workspace path API) → URL-based resolution — ×6 sites; **enumerate exact sites from a clean build (`grep "'targetPath' is deprecated"`) before editing, do not assume line numbers.** Each is upstream-friendly on its own. | [CoverArt.swift](Boxer/CoverArt.swift), [BXInputController.m](Boxer/DOS%20window/BXInputController.m), + targetPath sites (audit) | Small |

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
| B10 🟢 | **Fix property-based locking on `self.emulator`** at [BXSession.m:2147](Boxer/BXSession.m:2147). `@synchronized(self.emulator)` becomes a silent no-op if `self.emulator` is nil, possible if the property is cleared between the `isEmulating` check at line 2145 and the lock acquisition at 2147. Fix: lock on a stable ivar (a dedicated `_emulatorAccessLock`) or read `_emulator` into a local before locking. (A7 was re-scoped to `BXMIDIDeviceMonitor` only, so it no longer overlaps this `BXSession.m` site — but the *defect class* is identical to A7's reassignment race and B11's nil race: `@synchronized` on a mutable/nillable expression. Worth fixing all three consistently.) | [BXSession.m](Boxer/BXSession.m) | Locking |
| B11 🟢 | **Fix ADBFileHandle close-vs-read race.** [ADBFileHandle.m:823](Other%20Sources/ADBToolkit/ADBFileHandle.m:823) clears `self.sourceHandle = nil` outside any lock; reader at [line 893](Other%20Sources/ADBToolkit/ADBFileHandle.m:893) uses `@synchronized(self.sourceHandle)` which becomes a no-op once nilled. Subsequent method calls on the nil sourceHandle silently return 0, producing wrong-data reads instead of erroring out. Fix: lock on a stable ivar/lock object during both close and read; check for cleared handle inside the lock and error explicitly. **Now also subsumes the `@synchronized` → `os_unfair_lock` conversion of the 893/1019 sites originally scoped under A7** — converting `@synchronized(self.sourceHandle)` to a stable lock object *is* the race fix (same defect class as A7's reassignment race), so the cleanup and the correctness fix here are inseparable and must land together. Note `self.sourceHandle = nil` also occurs at line 975, not only 823. | [ADBFileHandle.m](Other%20Sources/ADBToolkit/ADBFileHandle.m) | Locking |
| B12 🟢 | **Add `NSApplicationPresentationDisableForceQuit` to fullscreen presentation options** (Tier 2 of the Accessibility-prompt reduction work). Boxer already toggles `NSApplicationPresentationDisableProcessSwitching` in `syncApplicationPresentationMode` at [BXBaseAppController.m:286](Boxer/Application%20Delegate/BXBaseAppController.m:286) when the mouse is locked; extend that bitmask to also include `NSApplicationPresentationDisableForceQuit` so a misfired ⌘-⌥-Esc doesn't kill an in-progress DOS session. The flag requires Dock-hide (already set when mouse is locked) so no new constraints. No permission required. Pairs cleanly with whatever currently exists for fullscreen entry/exit. **Follows on from the Tier 0+1 hotkey-prompt opt-in change at [BXKeyboardEventTap.m](Boxer/BXKeyboardEventTap.m:107) and [BXBaseAppController+BXHotKeys.m:390](Boxer/Application%20Delegate/BXBaseAppController+BXHotKeys.m:390).** | [BXBaseAppController.m](Boxer/Application%20Delegate/BXBaseAppController.m) | Small |
| B13 🟢 | **Move arrow-key interception to `NSEvent.addLocalMonitorForEvents`** (Tier 3 of the Accessibility-prompt reduction work). Currently the CGEventTap captures arrow keys (Up/Down/Left/Right) at [BXBaseAppController+BXHotKeys.m:105-108](Boxer/Application%20Delegate/BXBaseAppController+BXHotKeys.m:105) — but macOS doesn't system-globally intercept arrow keys the way it does F-keys, so a local event monitor should suffice and would not require Accessibility. F1-F12 must stay on the event tap because macOS does pre-empt them for brightness/Mission Control/media keys at a level above app delivery. Result: users who don't need F-key pass-through in DOS games (most casual users) never need to grant Accessibility at all. **Empirical testing required**: validate arrow-key behavior in windowed mode (mouse locked & unlocked), fullscreen, mid-Mission-Control gesture, and with VoiceOver running. | [BXInputController.m](Boxer/DOS%20window/BXInputController.m), [BXBaseAppController+BXHotKeys.m](Boxer/Application%20Delegate/BXBaseAppController+BXHotKeys.m) | Medium (empirical) |
| B14 🟢 | **Pre-prompt explainers for TCC permissions.** A10 and A11 add Info.plist usage strings so the *OS dialog itself* has reasonable text, but there's no Boxer-side context shown *before* the OS prompt fires for the first time. Add a one-time, dismissible Boxer sheet at the call sites where TCC-protected APIs first fire — at minimum: first gamebox import that crosses into `~/Documents`/`~/Desktop`/`~/Downloads`, first removable-volume mount (CD/USB), first gamepad connection (Input Monitoring). The sheet should explain (1) what permission is about to be asked, (2) what happens if the user clicks Deny in the OS dialog, (3) how to grant it later via Settings. Boxer already has the equivalent pattern for Accessibility via [hotkeyWarningAlert](Boxer/Application%20Delegate/BXBaseAppController+BXHotKeys.m:341); B14 extends that pattern to filesystem/input prompts. **Depends on A10 and A11 landing first** (so the OS-prompt strings exist before the pre-prompt promises them). | [BXSession.m](Boxer/BXSession.m) (drive imports), [ADBHIDMonitor.m](Other%20Sources/ADBToolkit/ADBHIDMonitor.m) (first HID enumeration), new explainer view/sheet | Small (mostly copy) |
| B15 🟢 | **Tighten the existing hotkey-warning copy.** The current `hotkeyWarningAlert` strings at [BXBaseAppController+BXHotKeys.m:350,357,363](Boxer/Application%20Delegate/BXBaseAppController+BXHotKeys.m:350) say "macOS hotkeys won't interfere with Boxer's game controls" — accurate but vague. Update to: (a) name the specific keys affected (F1-F12), (b) clarify what works without the permission (arrow keys, media keys via `NX_SYSDEFINED` fallback path — see B13's split), (c) make the relationship between Accessibility and the degraded-mode `BXKeyboardEventTapTappingSystemEventsOnly` state visible to the user. Strings live in `Boxer/Resources/<locale>.lproj/Localizable.strings` and the auto-generated `Localizable.xcstrings` — update all locales or mark fallbacks. Pure copy change, no code refactor. **Best done alongside or just after B13** so the wording can accurately describe the post-B13 reality. | [BXBaseAppController+BXHotKeys.m](Boxer/Application%20Delegate/BXBaseAppController+BXHotKeys.m), [Localizable.xcstrings](Boxer/Resources/Localizable.xcstrings) | Small (copy + locales) |

| B16 🟢 | **Migrate legacy `NSCollectionView` grid API → `NSCollectionViewFlowLayout`.** Single highest-frequency first-party deprecation cluster: 24 of ~42 first-party deprecation warnings come from one pre-10.11 API family — `maxNumberOfColumns` (×10), `itemPrototype` (×6), `minItemSize` (×4), `maxItemSize` (×4). It is **one coherent migration, not four fixes**. Sites: [BXDocumentationBrowser.m](Boxer/Documentation%20Panel/BXDocumentationBrowser.m), [BXDocumentationPanelController.m](Boxer/Documentation%20Panel/BXDocumentationPanelController.m), [BXGameboxPanelController.m](Boxer/Inspector%20Panel/BXGameboxPanelController.m), [BXCollectionItemView.m](Boxer/BXCollectionItemView.m). UX-visible (documentation browser, gamebox/inspector panels) → **screenshot QA at common window sizes required**, same review shape as B3/B6/B7. | the 4 files above + their XIBs | Medium + Visual QA |
| B17 🟢 | **Investigate Boxer's self-deprecated classes** `BXProgramPanelController` (×4) and `BXStatusBarController` (×2). These are *Boxer's own* classes annotated `DEPRECATED_ATTRIBUTE`/`__attribute__((deprecated))` yet still referenced — not a macOS-API deprecation. **First step is a "why" pass, not a code swap**: determine whether they were superseded by a newer class (then finish/remove the migration) or whether the deprecation annotation is premature/stale (then drop the annotation). Resolution shape depends entirely on that finding; do not treat as a mechanical replacement. | [BXProgramPanelController](Boxer/DOS%20window/BXProgramPanel.m), [BXStatusBarController](Boxer/DOS%20window/BXStatusBarController.m), + referencing sites | Investigate |
| B18 🟢 | **Replace deprecated `-[NSView dragImage:at:offset:event:pasteboard:source:slideBack:]`** (×2) with `-[NSView beginDraggingSessionWithItems:event:source:]` (`NSDraggingSession`). API-shape change (drag-item providers + `NSDraggingSource` conformance), not a one-liner. Enumerate the 2 sites from a clean build before editing. Modest visual/interaction QA (drag-and-drop still works). | drag sites (audit from build log) | Small–Medium |

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

Consolidated for solo-dev workflow: 5 branches with atomic commits per item (each item lands as its own commit within its branch, so upstream cherry-picks remain per-item). Down from the original 12 themed branches to reduce per-branch ceremony while preserving bisectability and per-item revertability.

| Branch | Plan items | Notes |
|--------|-----------|-------|
| `chore/cleanup-and-deps` | A1, A3, A4, A6, A7, A15, A24, A25 + the Tier 0+1 hotkey-prompt opt-in change (see [BXKeyboardEventTap.m:107](Boxer/BXKeyboardEventTap.m:107)) | Cleanup, deprecated-API replacements (incl. small first-party deprecation swaps A25), dep refresh, concurrency hot-paths, defense-in-depth, permission-prompt UX. All small, all upstream-friendly individually. |
| `build/macos-tahoe-readiness` | A8, A9, A10, A11, A13, A14, A22 | Hardened Runtime on (Boxer + Standalone), entitlements wired, TCC Info.plist strings, workspace schemes, Game Mode. Land first — A8 unlocks entitlement enforcement; A14 unlocks command-line builds without the CI scheme. |
| `perf/runtime-improvements` | A17, A18, A19, A20, A21 | Metal frame pacing, Display-P3, audio buffer, IOPM-on-pause, redraw skipping. Separated from cleanup because each needs empirical verification (gameplay testing, energy captures, frame-pacing measurements) that the cleanup items don't. |
| `fix/cue-resource-validation` | A23 🔒 | Security item kept on its own branch for upstream-priority focus. |
| `macos26/drop-intel-arch` | A12 🔴 | Fork-only narrowing; segregated from upstream-bound work. |

A5 (OpenEmu-Shaders bump) is **deferred to Bundle C**. Empirical research showed the 117-commit jump from `0f9e7e3` → `2ac33a9` removes Obj-C interop on `OEFilterChain`/`OEShaderParameter`/etc., requiring a multi-day rewrite of Boxer's shader integration (8 files, ~1000 LoC affected). Not a small SHA bump. See Bundle C considerations.

Within each branch, commit per item with a focused message (e.g., "Remove orphaned VDKQueue README", not "Bundle A item 1"). This preserves per-item upstream cherry-pick capability.

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
