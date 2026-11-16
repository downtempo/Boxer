# Privacy Status

One page showing where this fork's privacy stands today. Every privacy change,
looser or stricter, is the fork owner's choice. Record it in
[Privacy decisions](#privacy-decisions) in the same change that updates the affected
docs, any public privacy policy and any App Store privacy label.

This page describes the `maddsV2` branch at the audited commit. Other branches
differ: see [Other branches](#other-branches).

## At A Glance

| Item | Status on `maddsV2` |
| --- | --- |
| Distribution | Not stated in this fork's docs. `maddsV2` has no CI workflows. |
| Public privacy policy | None, and no in-app privacy link. |
| App Store privacy label | Not recorded. |
| Apple privacy manifest | None. |
| Permission prompts | Accessibility (the keyboard event tap in `Boxer/BXKeyboardEventTap.m` asks with the system prompt), Input Monitoring (HID devices in `Other Sources/ADBToolkit/ADBHIDMonitor.m`), and access to Desktop, Documents, Downloads, removable volumes and network volumes. `maddsV2` has no usage strings, so macOS shows its default text. Plan items A10 and A11 in `docs/modernization-plan.md` are marked done, but their strings landed on other branches, not on `maddsV2`. |
| Last audit | 2026-11-15: read-only audit by an AI agent at `51ace60f`. The same agent wrote this page and revised it after adversarial review. |
| Owner review | None recorded. Add the date when the owner reviews this page. |

## What Leaves The Device

| Destination | Transport | What is sent | When | On by default | In policy | In label |
| --- | --- | --- | --- | --- | --- | --- |
| `updates.boxerapp.com/appcast-dev` (Sparkle update feed; Sparkle resolved through SwiftPM from 1.23.0 up to the next major version) | HTTPS | An update-check request; system profiling is off (`SUEnableSystemProfiling` false). When an update exists, Sparkle also fetches the release notes and the update archive from URLs in the feed | Automatically, once a day (`SUScheduledCheckInterval` 86400), or from Check for Updates in the Boxer menu | Yes (`SUEnableAutomaticChecks` true) | No policy | Not recorded |
| `boxerapp.com/report-an-issue`, opened in the browser | HTTP | After an emulation error, if the user chooses to report it: the error message, the full stack trace, the gamebox name, the gamebox file path (which usually contains the user's account name) and the running DOS programs with their arguments, all in the URL query (`Boxer/Application Delegate/BXBaseAppController.m`). The server receives them when the page loads, before the user submits anything. From Report a Bug in the Boxer menu, the page opens with no details | User action | User action | No policy | Not recorded |
| Yahoo image search | HTTP | "dos" plus the game's name plus "cover" | From the import-finished panel and the gamebox inspector | User action | No policy | Not recorded |
| MobyGames and ReplacementDocs searches | HTTP | The gamebox name | From the Help menu | User action | No policy | Not recorded |
| `boxerapp.com` home and donation pages | HTTP | A plain page request | From Donate to Boxer in the Boxer menu, Boxer Website in the Help menu, and the About window | User action | No policy | Not recorded |
| The user's mail app | Mail | A new message to the support address in `Info.plist`, with a subject that includes the app version and build number | From Send Feedback in the Boxer menu | User action | No policy | Not recorded |
| Network peers through DOSBox IPX or serial emulation | UDP and TCP | Whatever the DOS game sends over the emulated network or serial link | See below | No | No policy | Not recorded |

Who operates the `boxerapp.com` hosts has not been verified for this fork. The update
check runs without any user action, so it reveals the user's IP address and app
version to that host every day.

The DOSBox core at the recorded submodule commit `0ae2d171` compiles in modem, IPX
and direct serial support (`C_MODEM`, `C_IPX` and `C_DIRECTSERIAL` in its
`config.h`). Boxer's `Resources/Configurations/Preflight.conf` turns IPX off and sets
the serial ports to dummy or disabled. Three DOS commands that ship with Boxer turn
networking on when the user runs them (`Resources/DOS Toolkit/UTILS/`):

- `HOST` turns IPX on, starts an IPX server on port 2130 and listens for a null-modem
  serial connection on port 2131, unless the user gives other ports.
- `JOIN` turns IPX on and connects over IPX and a null-modem serial link to an
  address the user enters.
- `NETWORK` is a menu for the two.

A user or gamebox configuration can also turn these on. macOS may ask whether to
accept incoming connections when a listener starts. This networking has not been
fully reviewed.

Boxer Standalone, the app that runs bundled gameboxes, has no update feed, no
report URL and no search URLs in its `Info.plist`. On user action it opens the
organization website and any help links that the Bundler writes into an exported
app (`BXOrganizationWebsiteURL`, `BXHelpLinks`).

Boxer also accepts AppleScript commands from other apps on the Mac
(`NSAppleScriptEnabled`). That is local and sends nothing off the device.

The 2026-11-15 audit searched the app's own Objective-C and Swift sources and the
`Vendor/` submodules at their recorded commits for URL loading, sockets, Bonjour,
web views, crash reporters and analytics. It excluded `Frameworks/` and the DOSBox
core, which is covered above. It found nothing beyond the rows above, apart from the
Standalone About window's web view, which shows a bundled credits page and sends
link clicks to the browser.

## Privacy Rule Documents

None for product behavior. `AGENTS.md` has rules for repository content only.

## Privacy Decisions

Newest first. Add a row for every privacy change, looser or stricter, at the time
it is made.

| Date | Decision | Direction | Chosen by | Records updated |
| --- | --- | --- | --- | --- |
| 2026-11-15 | Privacy rules are defaults, not bans. They change only by the owner's choice, in either direction, and each change is recorded here, in the affected docs, in any public privacy policy, and in any App Store privacy label, as each applies. | Process | Fork owner, in a 2026-11-15 working session; wording transcribed by an AI agent | This file only |

## Checks That Run

| Check | What it guards | Where it runs |
| --- | --- | --- |
| `tools/git-hooks/pre-commit` | Its privacy checks reject staged `/Users/` and `/home/` paths, common secret formats and private keys. They do not check host names, email addresses or IP addresses. The hook also blocks commits on protected branches and rejects conflict markers | Locally, once `tools/setup-git-hooks.sh` sets `core.hooksPath` |

## Other Branches

- `macos11` and `macos26` add usage strings for Desktop, Documents, Downloads,
  Input Monitoring, network volumes and removable volumes.
- `macos11` and `macos26` carry CI workflows, including `macos-release.yml`.

## Known Gaps

- Decide whether the automatic update check stays on, and which feed it uses. The
  Sparkle 2 migration is plan item C1 in `docs/modernization-plan.md`.
- The issue report sends local file paths and program details in a plain-HTTP URL
  when the page opens. Whether to change that is the owner's choice.
- Review the emulator's modem, IPX and serial networking, including the `HOST` and
  `JOIN` commands, before any public release.
