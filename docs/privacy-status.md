# Privacy Status

One page showing where this fork's privacy stands today. Every privacy change,
looser or stricter, is the fork owner's choice. Record it in
[Privacy decisions](#privacy-decisions) in the same change that updates the affected
docs, any public privacy policy and any App Store privacy label.

## At A Glance

| Item | Status |
| --- | --- |
| Distribution | Not stated in this fork's docs. `maddsV2` has no CI workflows. |
| Public privacy policy | None, and no in-app privacy link. |
| App Store privacy label | Not recorded. |
| Apple privacy manifest | None. |
| Permission prompts | None on `maddsV2`. Folder and volume access strings exist on the `macos26` branch. |
| Last reviewed | 2026-11-15, read-only audit at `51ace60f` (`maddsV2`). Owner review pending. |

## What Leaves The Device

| Destination | What is sent | When | On by default | In policy | In label |
| --- | --- | --- | --- | --- | --- |
| `updates.boxerapp.com/appcast-dev` (Sparkle 1.x update feed) | An update-check request; system profiling is off (`SUEnableSystemProfiling` false) | Automatically, once a day (`SUScheduledCheckInterval` 86400) | Yes (`SUEnableAutomaticChecks` true) | No policy | Not recorded |
| `boxerapp.com/report-an-issue`, opened in the browser | The error's title and details, placed in the URL query | When the user chooses to report an issue | User action | No policy | Not recorded |
| Web pages opened in the browser: `boxerapp.com`, MobyGames, Yahoo image search, ReplacementDocs | Search terms built from the game's name, where a template includes them | When the user chooses those menu items | User action | No policy | Not recorded |

Who operates the `boxerapp.com` hosts has not been verified for this fork. The update
check runs without any user action, so it reveals the user's IP address and app
version to that host every day. The emulator's own networking (modem and IPX
emulation) was not reviewed.

## Privacy Rule Documents

None.

## Privacy Decisions

Newest first. Add a row for every privacy change, looser or stricter, at the time
it is made.

| Date | Decision | Direction | Chosen by | Records updated |
| --- | --- | --- | --- | --- |
| 2026-11-15 | Privacy rules change only by the owner's choice, in either direction. Each change is recorded here, in the affected docs, in any public privacy policy, and in any App Store privacy label, as each applies. | Process | Fork owner | This file |

## Checks That Run

| Check | What it guards | Where it runs |
| --- | --- | --- |
| `tools/git-hooks/pre-commit` | Rejects staged personal paths, common secret formats and private keys | Locally, once `core.hooksPath` is set |

## Known Gaps

- Decide whether the automatic update check stays on, and which feed it uses. The
  Sparkle 2 migration is plan item C1 in `docs/modernization-plan.md`.
- Review the emulator's networking before any public release.
