## Upstream proposals (maintainer's call, NOT action items)

Decisions that belong to the upstream maintainer (`MaddTheSane/Boxer`),
recorded here so they're visible but explicitly **not** to be acted on by
cleanup branches. These are *proposals to raise in an upstream
discussion/PR*, not changes to make on `maddsV2`-derived work.

### UP1: Raise upstream `maddsV2` minimum macOS to 11 (Big Sur)

`maddsV2` inherits a **10.14.4** floor set by C.W. Betts in 2021
(`11ea9a41`). By 2026 that floor is 5 years past security updates and
9 years behind current. Therefore, in UP1 I propose an update to the **upstream** `maddsV2` layer's macOS floor (10.14.4 to 11).

For readers who haven't been through the full history of this project, I'll start with a recap of Boxer's macOS build floor history, then go into the macOS 11 build floor proposal, and the projected impact on Boxer and its users:

**History** (traced from git)

| Era | Floor | Who / when |
|---|---|---|
| Alun Bestor (Boxer ~1.0) | Leopard/Snow-Leopard; `31952311` "So long, Leopard support."; early bumps in `7ac66bb1` | Alun Bestor, ~2011–2013 |
| Modernization | 10.8 (`f5eaa13a`, `a35660dd`) to 10.9 (`84f47a44`, `d52cc23f`, `9fd68261`) to 10.10 (`85d3a9fe`, per-target) | C.W. Betts et al., 2015-2020 |
| Current upstream | **10.14.4** (`11ea9a41`) | C.W. Betts, 2021-03-08 |
| Fork narrowing (not upstream) | **26.0** (`b226a00c`, Phase 1) | this fork, `macos26` only |

So far, the `downtempo/maddsV2` fork has added **no** deployment-target change to `maddsV2` itself:
its only `maddsV2` commit is project-meta. (The 26.0 target is exclusively a separate
`macos26` layer.)

**Proposal and Rationale**

Bump up the upstream macOS minimum to **macOS 11 Big Sur**.

11 is the Apple-Silicon floor (every Apple Silicon Mac is
macOS 11 or newer; the only machines excluded are Intel capped at 10.15 or older, i.e.
2012-2013 hardware ~14 yrs old in 2026).

It is the single biggest modern-AppKit API watershed (`UTType`, SF Symbols, unified image/Apple Silicon APIs) so it unlocks the most `@available`/shim deletion per version-step. It also removes a security-stale floor. (10.15 is the ultra-conservative alternative, nearly zero adoption cost but far less cleanup payoff, while 11 is the point where the value curve is steep and the adoption curve is still flat.)

**Impact on this plan's work**

UP1 is a beneficiary, not a prerequisite.

The deprecated-API and modernization items (A25, B7, B16, the
`@available`-guard pruning, RegexKitLite/legacy-API removal) are what
make UP1 both *low-risk to propose* and *high-payoff if accepted*. They
remove the pre-11 compat cruft that would otherwise be the friction in
raising the floor, and they leave the codebase in a state where an 11
floor immediately unlocks unguarded use of the macOS 11-and-earlier API surface those
same items touch.

Concretely: every guard for APIs introduced in macOS 11 or earlier that the
cleanup work would otherwise have to keep becomes deletable under UP1,
and items currently written deployment-target-agnostic (so they
cherry-pick to 10.14.4) could be written against 11 APIs directly and
still be upstream-eligible. This plan's cleanup is the groundwork; UP1
is the multiplier on it, not a replacement for any of it. Conversely,
none of the planned work *depends* on UP1: it all stands at 10.14.4,
so UP1 staying unaccepted invalidates nothing.

**Constraints:**
(1) this is a project-direction decision for the
upstream maintainer, not a cleanup change. Do **not** set it on any
`maddsV2`-derived branch (would taint every cherry-pick)

(2) Orthogonal to and independent of the fork's `macos26` 26.0 narrowing. They coexist as separate layers

(3) If pursued, it gets its own focused upstream discussion/PR with the adoption analysis, not a bundled build tweak.

(4) Not a universal unlock, only the macOS 11-and-earlier API surface. APIs above
11 still need guards or stay fork-only: Game Mode/A22 (macOS 14),
Low Power/B5/B8 (macOS 12), Tahoe TCC/A10–A11 (macOS 26).
