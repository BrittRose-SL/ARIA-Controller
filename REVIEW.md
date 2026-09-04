# Review instructions

This repo is A.R.I.A. (Advanced Roleplay & Interaction Assistant), a modular
RLV/RLVa Second Life controller framed as a sci-fi android/drone, made of
three separate in-world objects (station, unit, wearer HUD). It is not an
OpenCollar fork and contains no OpenCollar source. This file recalibrates
severity for LSL's constraints and adds repo-specific checks grounded in the
actual codebase. It's injected as the highest-priority instruction for every
`/code-review` run — see `CLAUDE.md` for the full architecture reference.

## Revision history

- **2026-09-04 (this revision):** Full rewrite from the actual cloned repo.
  Previous revisions assumed an OpenCollar-fork structure (`vendor/`,
  `plugins/`) that does not exist in this project — void, replaced entirely.
- 2026-09-03 and earlier: superseded.

## Scope

- **`scripts/station/`, `scripts/unit/`, `scripts/wearer_hud/`** — the entire
  project. Review every `.lsl` file fully. There is no vendor/reference tree
  to compare against — everything here is original, review on LSL correctness
  and internal consistency with the rest of this codebase.
- **`scripts/unit/personas/*`** (no `.lsl` extension — plain text) — review as
  content, not code. Check: valid `[CONFIG]`/`[EMOTES]`/`[RESPONSES]` section
  headers, and that the same key set appears across personas that should be
  interchangeable (compare against `Persona_Default` as the baseline — if a
  new persona is missing a key `persona_module.lsl` expects, that's a real
  runtime gap, not a style issue).
- **`CHANGELOG.md`** — project-level SemVer releases. Distinct from each
  script's own `Version X.Y` header (see `CLAUDE.md`). Don't conflate the two
  when checking whether a change was "versioned."
- **`.vscode/sl-vscode-plugin/`** — generated type-definition files for the
  Second Life VS Code extension. Not hand-written, don't review for style.
- **`.github/ISSUE_TEMPLATE/`** — skip, not code.

## What Important means here

Findings that would break in-world behavior, cause a script to silently fail
for some auth level, corrupt or truncate stored data, or cause two scripts to
conflict (constant collision, channel collision, dispatch mismatch). Things
that won't show up as a compile error but will fail quietly in Second Life.

## What Critical means here

Anything that plainly will not compile or run as LSL: ternary operators,
`break`/`continue` statements, non-explicit `if`/`else`, `osGetNotecard()`
calls, `\u####` escape sequences, or a synchronous permission check that
bypasses the existing `AUTH_REQUEST`/`AUTH_REPLY` async pattern.

## What Nit means here

Style preferences that don't affect correctness — comment density, whether a
helper function is split out, missing per-file license header (see
`CLAUDE.md`) — and only when they don't touch anything in the
Critical/Important lists below.

## Repo-specific checks — hard rules (Critical)

- **No ternary operators.** Any `? :` usage — flag regardless of context.
- **No `break`/`continue`.** LSL loops have no such keyword — this will not
  compile. Flag any use inside a loop.
- **Explicit `if`/`else` only.** No shorthand or implicit fallthrough.
- **No `osGetNotecard()`.** Not available in Second Life LSL — flag any
  synchronous notecard read; must go through `llGetNotecardLine()` +
  `dataserver`.
- **No `\u####` Unicode escapes.** Renders as literal text in LSL.
- **No synchronous auth checks.** This codebase standardized on async
  `AUTH_REQUEST`/`AUTH_REPLY` as of `unit_master_kernel.lsl` v12.0
  specifically to remove a synchronous `getAccessLevel()`. Flag any new code
  that blocks waiting for an auth result instead of using the request/reply
  pattern.
- **Version header + CHANGES bullet required.** Every functional change must
  bump the file's `//-- Version X.Y` line and add a `//-- CHANGES vX.Y:`
  bullet. Flag a diff that changes behavior but leaves the header untouched.

## Repo-specific checks — constant/channel collisions (Important)

There is no shared header across files in this codebase — every message code
and channel number is copy-pasted into each file that needs it, so nothing is
caught by the compiler. The two known message-code collisions have been
resolved on the review branch:

- `POWER_STATE_CHANGE` remains `300`; `RELAY_CHAT_MESSAGE` is now `302`.
- `UPDATE_AROUSAL` is now `404`; `RLV_COMMAND` is now `405`.

Future changes must preserve these unique assignments and propagate any
renumbering to every sender and receiver.
- **General rule for any new constant:** grep all of `scripts/` for the
  literal integer before introducing it. This applies to the shared
  100–602 message-code range and to the negative region-chat channels
  (`-18795462` and neighbors) — it does not apply to small per-script local
  menu-state enums (0–10ish), which are legitimately private to each script's
  own dialog handling and fine to duplicate freely.
- **Don't confuse the two numbering spaces.** `500`–`505` mean `CMD_*` auth
  levels in `scripts/unit/` files and `STATION_*` message codes in
  `scripts/station/` files — same integers, different meanings, safe today
  only because unit and station never share a `link_message` space (they're
  separate objects). Flag anything that would put a unit module and a station
  module in the same linked object.

## Repo-specific checks — auth logic (Important)

- **Auth-level comparison direction.** `CMD_OWNER = 500` is *most*
  privileged, `CMD_NOACCESS = 599` is *least* — ascending value means
  descending privilege. `permission_module.lsl`'s `CalcAuth()` and its callers
  use `<=` to mean "at least this privileged" (e.g. `auth <= CMD_OWNER`).
  Flag any new auth check that uses `>=` where `<=` was clearly intended, or
  vice versa — this class of bug silently inverts access control rather than
  failing loudly.
- **Async only.** See Critical rules above — this is worth a second mention
  here because it's an easy mistake to reintroduce piecemeal (e.g. a new
  module polling for a cached auth value instead of listening for
  `AUTH_REPLY`).

## Repo-specific checks — persona data integrity (Important)

- Compare any new or edited persona file's key set against `Persona_Default`.
  A persona missing an `[EMOTES]` or `[RESPONSES]` key that `persona_module.lsl`
  looks up will produce an empty or garbled in-world response, not a compile
  error — flag missing keys explicitly, don't just note "looks incomplete."
- `[CONFIG]` section fields (`Name`, `OutfitFolder`, `ChatPrefix`,
  `EmoteStyle`, `ResponseTone`) should be present and non-empty in every
  persona file.

## What NOT to flag

- **Sci-fi android/drone framing** in strings, persona content, and comments
  — this is the intentional creative direction for the whole project, not an
  inconsistency.
- **Adult-content persona material** (e.g. `Persona_Sexbot`, the
  arousal/stimulation emote categories) — intentional content for this
  project, review it the same way as any other persona file (structural
  completeness), not as something to question the presence of.
- **The `500`–`505` numeric overlap** between unit `CMD_*` and station
  `STATION_*` constants — safe as explained above; don't flag it as a
  collision on its own. Only flag if a change would actually put both in the
  same linked object.
- **Missing per-file license headers** — Nit-level only (see `CLAUDE.md`);
  the repo-level `LICENSE` (GPLv3) already covers this. Don't block a review
  on it.
- **No automated test suite** — LSL cannot be unit tested outside Second
  Life; `docs/TESTING.md` is the manual checklist. Don't suggest adding
  automated tests; validation happens in-world.
- **A separate Cloudflare Worker / external backend** — `unit_api_integration.lsl`
  is the in-world half of external/web integration, but whether a backend
  repo actually exists is unconfirmed. Don't flag its absence from this repo
  as a gap; it may live elsewhere or not exist yet.

## Style conventions (Nit-level only)

- Keep the existing `//-- Version X.Y - DESCRIPTION` / `//-- CHANGES vX.Y:`
  header format consistent across files.
- Comments should explain *why*, especially around the auth comparison
  direction and the two known constant collisions, not just restate the line.
