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
| Public privacy policy | None in this repository, and no in-app privacy link. |
| App Store privacy label | Not recorded. |
| Apple privacy manifest | None. |
| Permission prompts | Accessibility (the keyboard event tap in `Boxer/BXKeyboardEventTap.m` asks with the system prompt), Input Monitoring (HID devices in `Other Sources/ADBToolkit/ADBHIDMonitor.m`), and access to Desktop, Documents, Downloads, removable volumes and network volumes. `maddsV2` has no usage strings, so macOS shows its default text. Plan items A10 and A11 in `docs/modernization-plan.md` are marked done, but their strings landed on other branches, not on `maddsV2`. |
| Last audit | 2026-11-15: read-only audit by an AI agent at `51ace60f`. The same agent wrote this page and revised it after adversarial review. |
| Owner review | None recorded. Add the date when the owner reviews this page. |

## What Leaves The Device

| Destination | Transport | What is sent | When | On by default | In policy | In label |
| --- | --- | --- | --- | --- | --- | --- |
| `updates.boxerapp.com/appcast-dev` (Sparkle update feed; Sparkle resolved through SwiftPM from 1.23.0 up to the next major version) | HTTPS | An update-check request; system profiling is off (`SUEnableSystemProfiling` false). When an update exists, Sparkle shows its update window, which can load release notes linked from the feed. It downloads the update archive when the user chooses to install; the repository sets no automatic-install key | Automatically, at most once a day while Boxer is running (`SUScheduledCheckInterval` 86400), or from Check for Updates in the Boxer menu | Yes (`SUEnableAutomaticChecks` true) | No policy | Not recorded |
| `boxerapp.com/report-an-issue`, opened in the browser | HTTP | After an emulation error, if the user chooses to report it: the error message, the full stack trace, the gamebox name, the gamebox file path (which usually contains the user's account name) and the running DOS programs with their arguments, all in the URL query (`Boxer/Application Delegate/BXBaseAppController.m`). The server receives them when the page loads, before the user submits anything. From Report a Bug in the Boxer menu, the page opens with no details | User action | User action | No policy | Not recorded |
| Yahoo image search | HTTP | "dos" plus the game's name plus "cover" | From the import-finished panel and the gamebox inspector | User action | No policy | Not recorded |
| MobyGames and ReplacementDocs searches | HTTP | The gamebox name | From the Help menu | User action | No policy | Not recorded |
| `boxerapp.com` home and donation pages | HTTP | A plain page request | From Donate to Boxer in the Boxer menu, Boxer Website in the Help menu, and the About window | User action | No policy | Not recorded |
| The user's mail app | Mail | A draft to the support address in `Info.plist`, with a subject that includes the app version and build number. Nothing is sent until the user sends it | From Send Feedback in the Boxer menu | User action | No policy | Not recorded |
| MIDI devices and apps (CoreMIDI) | MIDI | At launch, an MT-32 identity request to each MIDI destination that has a matching input (`Boxer/BXMIDIDeviceMonitor.m`, started from `BXBaseAppController.m`). During play, the game's music, when an external MIDI device is in use. Destinations can include other apps' virtual ports and network or Bluetooth MIDI sessions | Probe: automatically at every launch, in Boxer and Boxer Standalone. Music: during play | Yes | No policy | Not recorded |
| A printer the user picks | Print | A DOS program's printed output, through the macOS print dialog (`Boxer/BXSession+BXPrinting.m`) | After a DOS print job, when the user confirms in the print dialog | User action | No policy | Not recorded |
| Network peers through DOSBox IPX, modem, null-modem or NE2000 emulation | UDP and TCP, or raw Ethernet frames for NE2000 | Whatever the DOS guest sends over the emulated network or serial link | See below | No. NE2000 is enabled but opens no interface | No policy | Not recorded |

Who operates the `boxerapp.com` hosts has not been verified for this fork. The update
check runs without any user action, so it reveals the user's IP address and app
version to that host about once a day.

The DOSBox core at the recorded submodule commit `0ae2d171` sets these network and
device flags in its `config.h`, and no other network features (`C_PRINTER`, for
printing, is covered above):

- IPX (`C_IPX`): off in the core's defaults and in Boxer's
  `Resources/Configurations/Preflight.conf`.
- Modem and null-modem serial connections over TCP (`C_MODEM`), and direct serial to
  a local host serial device, which is not a network path (`C_DIRECTSERIAL`):
  `Preflight.conf` sets the serial ports to dummy or disabled.
- NE2000 Ethernet passthrough (`C_NE2000`): on in the core's defaults, and Boxer
  does not configure it. The default `realnic=list` only lists the Mac's network
  interfaces and opens none. A `realnic` setting that names an interface opens it
  through libpcap in promiscuous mode, which puts the DOS guest on the real
  network. Whether macOS permissions allow that capture was not verified.

Three DOS commands that ship with Boxer turn networking on when the user runs them
(`Resources/DOS Toolkit/UTILS/`, with identical copies in
`Standalone/Resources/DOS Toolkit/UTILS/`):

- `HOST` turns IPX on, starts an IPX server on UDP port 2130 and listens for a
  null-modem serial connection on TCP port 2131, on all network interfaces. The
  user's arguments, or the `IPXPORT` and `SERIALPORT` variables, can change the ports.
- `JOIN` turns IPX on and connects over IPX and a null-modem serial link to an
  address the user enters.
- `NETWORK` is a menu for the two, plus a status choice that also turns IPX on.

A user or gamebox configuration can also turn any of these on. macOS may ask whether
to accept incoming connections when a listener starts. The core was checked through
its build flags, its default settings and Boxer's configuration, not by a full
source review.

Boxer Standalone, the app that runs bundled gameboxes, has no update feed, no
report URL and no search URLs in its `Info.plist`. On user action it opens the
organization website and any help links that the Bundler writes into an exported
app (`BXOrganizationWebsiteURL`, `BXHelpLinks`). It compiles the same DOSBox
networking code and ships the same DOS commands, with the same defaults, so
exported games carry the same networking described above.

Boxer also accepts AppleScript commands from other apps (`NSAppleScriptEnabled`).
Boxer sends nothing off the device this way. Other Macs can send it commands only if
the user turns on Remote Apple Events.

The 2026-11-15 audit searched the app's own Objective-C and Swift sources and the
`Vendor/` submodules at their recorded commits for URL loading, sockets, Bonjour,
web views, CoreMIDI, printing, crash reporters and analytics. It excluded
`Frameworks/` and the DOSBox core, which is covered above. It found nothing beyond the rows above, apart from the
Standalone About window's web view, which shows a bundled credits page and sends
link clicks to the browser.

## Privacy Rule Documents

None for product behavior. `AGENTS.md` covers the pre-commit leak check and the
rules for security and runtime-behavior items.

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
- Review the emulator's IPX, modem, serial and NE2000 networking, including the
  `HOST` and `JOIN` commands, before any public release.
- The MT-32 probe goes to MIDI destinations at every launch, with no setting to turn
  it off. Whether to change that is the owner's choice.
