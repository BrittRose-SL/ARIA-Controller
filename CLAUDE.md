# CLAUDE.md — A.R.I.A. (Advanced Roleplay & Interaction Assistant)

This file is auto-loaded by Claude Code at the start of every session in this repo.
It is the source of truth for standards, architecture, and known gotchas. Read it
before editing anything.

## Revision history

- **2026-09-04 (this revision):** Full rewrite from the actual cloned repo
  (`BrittRose-SL/ARIA-Controller`, `main`). Everything in prior revisions about
  an OpenCollar fork, a `vendor/`+`plugins/` split, and a `permissions/`
  subfolder was based on an incorrect assumption and is void — this project
  has no OpenCollar source in it anywhere. Replaced with the real
  station/unit/wearer_hud architecture, the real message-code registry, and
  two confirmed constant collisions found while building that registry.
- 2026-09-03 and earlier: superseded, based on an unrelated OpenCollar-derived
  file set that turned out not to be this project.

## Project Overview

**A.R.I.A.** is a modular RLV/RLVa controller system for Second Life, framed
as a sci-fi android/drone that requires programming (configuration via a
station) and charging (a simulated battery/power system), rather than a
traditional collar. Three separate in-world objects make up the system:

- **Unit Controller** (`scripts/unit/`) — the wearable device itself. Modular:
  a kernel plus hot-swappable feature modules.
- **Programming Station** (`scripts/station/`) — administrative hub for
  configuring a synced unit remotely: personas, permissions, backups,
  diagnostics, module activation.
- **Wearer HUD** (`scripts/wearer_hud/`) — worn by the unit's wearer for
  status display and limited self-service control.
- **Owner HUD** and **External API / web integration** — planned per
  `README.md` and `docs/TESTING.md`, channel numbers already reserved
  (`gOwnerHudChannel = -18795463`), but no code exists for the Owner HUD yet.
  `scripts/unit/unit_api_integration.lsl` is the in-world half of the
  external/web integration (HTTP server via `llRequestURL`-style handling);
  whether a separate Worker/backend repo exists is unconfirmed — ask before
  assuming one does.

**Nothing here is copied OpenCollar source.** There is no `oc_*` file, no GPL
header, no OpenCollar copyright notice anywhere in `scripts/`. Thirteen files'
version headers do say "OPENCOLLAR AUTH INTEGRATION" — that refers to the
auth-level *numbers* (`CMD_OWNER=500`, `CMD_TRUSTED=501`, `CMD_WEARER=503`,
`CMD_EVERYONE=504`, `AUTH_REQUEST=600`/`AUTH_REPLY=601`) being deliberately
chosen to match OpenCollar's own convention, resolved by an original
`CalcAuth()` function in `permission_module.lsl`. That's a design choice, not
a fork — no GPL obligation attaches to matching someone else's numbering
scheme. Treat the repo's own `LICENSE` (GPLv3) as covering everything here;
individual files currently carry no per-file header at all (see Nits below).

## Repo Structure (actual, verified)

```
.
├── CLAUDE.md
├── REVIEW.md
├── README.md
├── CHANGELOG.md          <- project-level SemVer releases (Keep a Changelog format)
├── LICENSE               <- GPLv3
├── .github/ISSUE_TEMPLATE/
├── .vscode/sl-vscode-plugin/   <- SLua type defs for the Second Life VS Code extension
├── docs/TESTING.md
└── scripts/
    ├── station/           (9 files — see table below)
    ├── unit/              (13 files + personas/, see table below)
    └── wearer_hud/        (4 files — see table below)
```

No `vendor/`, `plugins/`, `templates/`, `notecards/`, or `worker/` directory
exists in this repo. If any of those get added later, update this file — don't
assume the old draft's layout still applies.

## Script Inventory (verified: names, versions, line counts as of this pull)

### `scripts/station/`

| File | Version | Lines |
|---|---|---|
| `station_main_kernel.lsl` | 1.1 — MODULAR STATION ARCHITECTURE | 390 |
| `module_manager.lsl` | 1.0 — MODULE ACTIVATION/DEACTIVATION | 287 |
| `permissions_manager.lsl` | 1.1 — USER PERMISSION MANAGEMENT | 506 |
| `persona_manager.lsl` | 1.0 — PERSONA INSTALLATION & MANAGEMENT | 337 |
| `persona_editor_manager.lsl` | 1.0 — COMPREHENSIVE PERSONA MANAGEMENT SYSTEM | 984 |
| `charging_system.lsl` | 1.0 — BATTERY CHARGING & POWER MANAGEMENT | 395 |
| `diagnostics_manager.lsl` | 1.0 — STATUS REPORTS & SYSTEM DIAGNOSTICS | 463 |
| `maintenance_manager.lsl` | 1.0 — COMPREHENSIVE SYSTEM MAINTENANCE | 726 |
| `backup_manager.lsl` | 1.0 — CONFIGURATION BACKUP & RESTORE | 634 |

### `scripts/unit/`

| File | Version | Lines |
|---|---|---|
| `unit_master_kernel.lsl` | 12.1 — OPENCOLLAR AUTH INTEGRATION | 617 |
| `permission_module.lsl` | 3.3 — OPENCOLLAR STYLE AUTH SYSTEM | 545 |
| `persona_module.lsl` | 5.1 — OPENCOLLAR AUTH SYSTEM INTEGRATION | 695 |
| `comms_module.lsl` | 3.0 — OPENCOLLAR AUTH INTEGRATION | 481 |
| `interaction_module.lsl` | 3.1 — OPENCOLLAR AUTH SYSTEM INTEGRATION | 799 |
| `interface_module.lsl` | 3.1 — OPENCOLLAR AUTH INTEGRATION | 693 |
| `mobility_module.lsl` | 3.1 — OPENCOLLAR AUTH SYSTEM INTEGRATION | 563 |
| `sensory_module.lsl` | 2.1 — OPENCOLLAR AUTH SYSTEM + ADULT DEVICE INTEGRATION | 639 |
| `speech_module.lsl` | 3.1 — OPENCOLLAR AUTH INTEGRATION | 359 |
| `tether_module.lsl` | 3.1 — OPENCOLLAR AUTH SYSTEM INTEGRATION | 528 |
| `vision_module.lsl` | 3.1 — OPENCOLLAR AUTH INTEGRATION | 602 |
| `wardrobe_module.lsl` | 3.1 — OPENCOLLAR AUTH SYSTEM INTEGRATION | 532 |
| `diagnostics_module.lsl` | 2.1 — OPENCOLLAR AUTH SYSTEM INTEGRATION | 475 |
| `unit_api_integration.lsl` | 1.0 — GRID-WIDE & WEB INTEGRATION | 571 |
| `personas/Persona_Default`, `Persona_Assistant`, `Persona_Companion`, `Persona_Guardian`, `Persona_Sexbot`, `persona_maid` | plain-text data files, not LSL | — |

### `scripts/wearer_hud/`

| File | Lines |
|---|---|
| `wearer_hud_main_kernel.lsl` | 529 |
| `wearer_hud_status_display.lsl` | 590 |
| `wearer_hud_app_interface.lsl` | 593 |
| `wearer_hud_proximity_scanner.lsl` | 641 |

Total: 26 `.lsl` files, ~15,200 lines, plus 6 persona data files.

## Communication Architecture (verified)

Two distinct layers — don't conflate them:

1. **Within a device (intra-object): `llMessageLinked`/`link_message`.**
   Standard LSL, no shared header — every constant is copy-pasted into every
   file that needs it (see registry below).
2. **Between devices (station ↔ unit ↔ HUDs): region-chat channels.**
   Confirmed constants:
   - `gUnitLinkChannel` / `gStationLinkChannel` = `-18795462` (station ↔ unit,
     used consistently across every `station/*.lsl` and referenced in
     `unit_master_kernel.lsl` and `permission_module.lsl`)
   - `gOwnerHudChannel` = `-18795463` (reserved, no Owner HUD code yet)
   - `gWearerHudChannel` = `-18795464` (reserved; `wearer_hud_main_kernel.lsl`
     uses `gCmdChannel = -18795462` — confirm whether the HUD is actually
     supposed to be on `-18795462` or `-18795464` before changing either)
   - `RLV_RELAY_CHANNEL`, `SENSATIONS_CHANNEL`, `AVS_CHANNEL`, `INM_CHANNEL`,
     `LOVENSE_CHANNEL = 1337` (`sensory_module.lsl`) — third-party
     integration channels for existing SL RLV-relay/toy ecosystems. These are
     interoperability points, not internal protocol — don't repurpose them.

## Message-Code Registry (verified — compiled by grepping every script, 2026-09-04)

This is not exhaustive of every local per-script menu-state enum (those are
fine to duplicate freely — they're private to a single script's own dialog
handling). This *is* the shared cross-script/cross-file protocol space.
**Grep for the literal integer across all of `scripts/` before adding a new
one** — nothing here is compiler-checked.

| Value | Constant | Consistent everywhere? |
|---|---|---|
| 100 | `SET_SPEECH_MODE` | ✅ 3 files, consistent |
| 101 | `UPDATE_BATTERY` | ✅ 13 files, consistent (station + unit) |
| 102 | `UPDATE_CONFIG` | ✅ 3 files, consistent |
| 103 | `UPDATE_UNIT_INFO` | ✅ 3 files, consistent |
| 104 | `UPDATE_PERSONA_STATUS` | ✅ 3 files, consistent |
| 107 | `UPDATE_HOVER_DATA` | ✅ 2 files, consistent |
| 200 | `MODULE_REGISTER` | ✅ 14 files, consistent |
| 201 | `OPEN_MY_MENU` | ✅ 14 files, consistent |
| 300 | `POWER_STATE_CHANGE` | ✅ 13 files, consistent |
| 302 | `RELAY_CHAT_MESSAGE` | ✅ 2 files, consistent |
| 301 | `PERSONA_EMOTE_TRIGGER` | ✅ 1 file so far |
| 404 | `UPDATE_AROUSAL` | ✅ 2 files, consistent |
| 405 | `RLV_COMMAND` | ✅ 2 files, consistent |
| 401 | `UPDATE_STIMULATION` | ✅ 2 files, consistent |
| 402 | `UPDATE_PAIN` | ✅ 2 files, consistent |
| 403 | `UPDATE_STRESS` | ✅ 2 files, consistent |
| 500 | `CMD_OWNER` (unit) / `STATION_MODULE_REGISTER` (station) | ✅ consistent within each device's own space |
| 501 | `CMD_TRUSTED` (unit) / `STATION_OPEN_MENU` (station) | ✅ |
| 502 | `CMD_GROUP` (unit) / `STATION_UPDATE_DATA` (station) | ✅ |
| 503 | `CMD_WEARER` (unit) / `STATION_UNIT_SYNC` (station) | ✅ |
| 504 | `CMD_EVERYONE` (unit) / `STATION_UNIT_STATUS` (station) | ✅ |
| 505 | `STATION_REQUEST_DATA` (station only) | ✅ |
| 598 | `CMD_BLOCKED` | ✅ 13 files, consistent |
| 599 | `CMD_NOACCESS` | ✅ 13 files, consistent |
| 600 | `AUTH_REQUEST` | ✅ 13 files, consistent |
| 601 | `AUTH_REPLY` | ✅ 13 files, consistent |
| 602 | `PERMISSION_DATA_REQUEST` | `permission_module.lsl` only so far |

**Note:** the 500-range numbers are reused between the unit's `CMD_*` auth
levels and the station's `STATION_*` message codes with the *same* integer
values. This isn't a bug today because unit and station scripts never share a
linked-prim `link_message` space with each other (they're separate objects
talking over the region-chat channel instead) — but it means a value like
`503` means "CMD_WEARER" in one device and "STATION_UNIT_SYNC" in the other.
Keep that boundary intact; don't let a unit module and a station module end up
in the same object.

### Resolved protocol collisions

The former `300` collision between `POWER_STATE_CHANGE` and
`RELAY_CHAT_MESSAGE` was resolved by moving `RELAY_CHAT_MESSAGE` to `302`.
The former `400` collision between `RLV_COMMAND` and `UPDATE_AROUSAL` was
resolved by moving `UPDATE_AROUSAL` to `404` and `RLV_COMMAND` to `405`.
These values are propagated to every sender and receiver in `scripts/unit/`.

## LSL Coding Standards (non-negotiable)

- **No ternary operators.** Use explicit `if`/`else`. Support is inconsistent
  across LSL engines (SL Mono / OpenSim / legacy LSO).
- **No `break`/`continue`.** LSL loops have no such keyword — code using them
  will not compile.
- Explicit, complete `if`/`else` blocks — no shorthand, no fallthrough.
- **Always output the full, complete script** on any change, even a one-line
  fix. No placeholders, no `// ... rest unchanged`.
- Comments explain *why*, not just *what*.

### Version header format (the real, existing convention — keep using it)

```lsl
//-- A.R.I.A. [Module Display Name]
//-- Version X.Y - SHORT ALL-CAPS DESCRIPTION
//-- One-line description of what this script does
//-- CHANGES vX.Y:
//--   - Bullet describing this version's change
//--   - Another bullet if needed
```

This is a single-line-per-entry header, distinct from the project-level
`CHANGELOG.md` (which uses Keep a Changelog + SemVer format for release-level
tracking, e.g. `[1.0.0] - 2025-09-07`). The two are independent counters —
bumping a file's `Version X.Y` does not require touching `CHANGELOG.md`, and
vice versa. Bump the in-file version and add a `CHANGES` bullet for every
functional change, however small.

**Gap worth closing (Nit, not urgent):** no `.lsl` file currently carries any
license/copyright header — the repo's `LICENSE` (GPLv3) covers everything by
default, but GPLv3's own recommended practice is a short per-file notice.
Consider a short standard header for new/touched files; don't retrofit every
existing file just for this.

## Architecture Patterns & Conventions

- **Hot-swappable modules.** The station's `module_manager.lsl` can remotely
  activate/deactivate a synced unit's modules without a full reset — this is
  real, implemented functionality, not just README marketing copy.
- **Async auth, not sync.** `unit_master_kernel.lsl`'s v12.0 changelog
  explicitly removed a synchronous `getAccessLevel()` in favor of the
  `AUTH_REQUEST`/`AUTH_REPLY` async pattern. Don't reintroduce a synchronous
  auth check — match the existing async request/reply flow.
- **Auth-level ordering is numeric and ascending-worse.** `CMD_OWNER = 500`
  is the *most* privileged; `CMD_NOACCESS = 599` the least. `permission_module.lsl`'s
  `CalcAuth()` and its callers compare with `<=` (e.g. `auth <= CMD_OWNER`
  means "at least owner-level"). Get comparison direction right — flipping
  `<=`/`>=` here silently inverts who's allowed to do what.
- **Personas are data, not logic.** `scripts/unit/personas/*` are plain-text
  `[CONFIG]`/`[EMOTES]`/`[RESPONSES]` files consumed by `persona_module.lsl`
  and `persona_editor_manager.lsl`. Editing a persona is a content-completeness
  task (are all expected keys present, valid section headers), not an LSL
  correctness task.
- **Third-party RLV/toy relay channels are fixed integration points.**
  (`RLV_RELAY_CHANNEL`, `LOVENSE_CHANNEL`, etc.) — don't renumber these even
  if they look inconsistent with the rest of the scheme; they're matching an
  external protocol this project doesn't control.

## When Writing Or Fixing Code

1. Grep all of `scripts/` for any constant/channel number before introducing
   a new one — see the registry above for what's already claimed, and note it
   was compiled by grep, not guaranteed complete for every local enum.
2. Preserve the async `AUTH_REQUEST`/`AUTH_REPLY` pattern for anything
   permission-related; don't add a synchronous auth check.
3. Keep the existing version-header format (`//-- Version X.Y - DESC` +
   `//-- CHANGES vX.Y:` bullets) for every functional change.
4. Return the complete file, not a diff or excerpt.
5. If a change touches `persona_module.lsl`, `sensory_module.lsl`, or any
   persona data file, treat the emote/response key set as a contract other
   files may depend on — don't rename or remove a key without checking who
   reads it.
