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
| Permission prompts | Accessibility (the keyboard event tap in `Boxer/BXKeyboardEventTap.m` asks with the system prompt), Input Monitoring (HID devices in `Other Sources/ADBToolkit/ADBHIDMonitor.m`), and access to Desktop, Documents, Downloads, removable volumes and network volumes (plan items A10 and A11 in `docs/modernization-plan.md`). `maddsV2` has no usage strings, so macOS shows its default text. |
| Last audit | 2026-11-15: AI-assisted read-only audit at `51ace60f`, revised after an adversarial review. |
| Owner review | None recorded. Add the date when the owner reviews this page. |

## What Leaves The Device

| Destination | Transport | What is sent | When | On by default | In policy | In label |
| --- | --- | --- | --- | --- | --- | --- |
| `updates.boxerapp.com/appcast-dev` (Sparkle update feed; Sparkle resolved through SwiftPM from 1.23.0 up to the next major version) | HTTPS | An update-check request; system profiling is off (`SUEnableSystemProfiling` false) | Automatically, once a day (`SUScheduledCheckInterval` 86400) | Yes (`SUEnableAutomaticChecks` true) | No policy | Not recorded |
| `boxerapp.com/report-an-issue`, opened in the browser | HTTP | After an emulation error, if the user chooses to report it: the error message, the full stack trace, the gamebox name, the gamebox file path (which usually contains the user's account name) and the running DOS programs with their arguments, all in the URL query (`Boxer/Application Delegate/BXBaseAppController.m`). The server receives them when the page loads, before the user submits anything. From the Help menu, the page opens with no details | User action | User action | No policy | Not recorded |
| Yahoo image search | HTTP | "dos" plus the game's name plus "cover" | From the import-finished panel and the gamebox inspector | User action | No policy | Not recorded |
| MobyGames and ReplacementDocs searches | HTTP | The gamebox name | From the Help menu | User action | No policy | Not recorded |
| `boxerapp.com` home and donation pages | HTTP | A plain page request | From the "Donate to Boxer" and website menu items and the About window | User action | No policy | Not recorded |
| The user's mail app | Mail | A new message to the support address in `Info.plist`, with a prefilled subject | When the user chooses to email support | User action | No policy | Not recorded |

Who operates the `boxerapp.com` hosts has not been verified for this fork. The update
check runs without any user action, so it reveals the user's IP address and app
version to that host every day.

Boxer Standalone, the app that runs bundled gameboxes, has no update feed, no
report URL and no search URLs in its `Info.plist`. On user action it opens the
organization website that the Bundler writes into an exported app
(`BXOrganizationWebsiteURL`).

The DOSBox core at the recorded submodule commit `0ae2d171` compiles in modem and
IPX networking (`C_MODEM` and `C_IPX` in its `config.h`). Boxer's
`Resources/Configurations/Preflight.conf` turns IPX off and sets the serial ports to
dummy or disabled. A user or gamebox configuration can turn them on, and guest
software can then open network connections. This networking has not been fully
reviewed.

The 2026-11-15 audit searched the Objective-C and Swift sources outside the
`DOSBox-Staging/` and `Frameworks/` directories for URL loading, sockets, Bonjour,
web views, crash reporters and analytics, and found nothing beyond the rows above.

## Privacy Rule Documents

None for product behavior. `AGENTS.md` has rules for repository content only.

## Privacy Decisions

Newest first. Add a row for every privacy change, looser or stricter, at the time
it is made.

| Date | Decision | Direction | Chosen by | Records updated |
| --- | --- | --- | --- | --- |
| 2026-11-15 | Privacy rules change only by the owner's choice, in either direction. Each change is recorded here, in the affected docs, in any public privacy policy, and in any App Store privacy label, as each applies. | Process | Fork owner, stated 2026-11-15 | This file only |

## Checks That Run

| Check | What it guards | Where it runs |
| --- | --- | --- |
| `tools/git-hooks/pre-commit` | Rejects staged `/Users/` and `/home/` paths, common secret formats and private keys. It does not check host names, email addresses or IP addresses | Locally, once `tools/setup-git-hooks.sh` sets `core.hooksPath` |

## Other Branches

- `macos26` adds usage strings for Desktop, Documents, Downloads, Input Monitoring,
  network volumes and removable volumes.
- `macos11` and `macos26` carry CI workflows, including `macos-release.yml`.

## Known Gaps

- Decide whether the automatic update check stays on, and which feed it uses. The
  Sparkle 2 migration is plan item C1 in `docs/modernization-plan.md`.
- The issue report sends local file paths and program details in a plain-HTTP URL
  when the page opens. Whether to change that is the owner's choice.
- Review the emulator's modem and IPX networking before any public release.
