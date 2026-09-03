# CLAUDE.md — OpenCollar Custom Build

This file is auto-loaded by Claude Code at the start of every session in this repo.
It is the source of truth for standards, architecture, and known gotchas. Read it
before editing anything.

## Project Overview

A heavily customized OpenCollar (OC) collar system for Second Life, built on the
OpenCollar 8.3 framework. Designed to be configured by an owner and worn by a
submissive partner. Extends stock OpenCollar with:

- A suite of proprietary LSL plugins (see `plugins/`)
- A Discord webhook integration layer for logging/alerts
- A Cloudflare Worker–based remote control web API (`worker/`)
- A Notion workspace for project management (Session Log, To-Do, Features &
  Roadmap, Bugs & Issues)

Goal: a fully pre-configured, feature-rich collar system with remote monitoring,
enforcement, and control capabilities.

## Repo Structure

```
.
├── CLAUDE.md               <- this file
├── README.md
├── CHANGELOG.md
├── vendor/opencollar-8.3/  <- STOCK framework, reference only. DO NOT EDIT.
├── plugins/                <- Custom proprietary scripts. Source of truth.
├── templates/              <- oc_addon_template.lsl / oc_plugin_template.lsl
├── worker/                 <- Cloudflare Worker remote-control backend (JS)
├── notecards/              <- .settings / .webhooks templates (no real secrets)
└── docs/                   <- Lovense API docs, architecture notes, RLV reference
```

### vendor/ vs plugins/ — read this before touching anything

`vendor/opencollar-8.3/` is an unmodified copy of the stock framework
(`oc_core.lsl`, `oc_api.lsl`, `oc_auth.lsl`, `oc_dialog.lsl`, `oc_settings.lsl`,
etc.). It exists purely as a reference so custom plugins stay compatible with
core dispatch, auth, and settings behavior. **Never edit files in `vendor/`.**
If a fix requires changing core behavior, it belongs in a plugin or gets flagged
as a deliberate core fork — call this out explicitly, don't do it silently.

`plugins/` holds the actual custom scripts that get distributed in the collar.
These are the ones with real version headers and changelogs. This is where all
day-to-day work happens.

Some plugin files coexist in both trees under the same filename (e.g.
`oc_spy.lsl`, `oc_shocker.lsl`, `oc_garble.lsl` started as stock OC apps and were
heavily customized). When editing, always work from `plugins/`, never `vendor/`.

## LSL Coding Standards (non-negotiable)

- **No ternary operators.** Use explicit `if`/`else`.
- **No `break` statements.** LSL doesn't support them the way C-family languages
  do inside loops in the way people expect — restructure with explicit
  conditionals/state flags instead.
- Explicit, complete `if`/`else` blocks — no shorthand, no fallthrough assumptions.
- **Always output the full, complete script** on any change, even a one-line or
  one-variable fix. No placeholders, no `// ... rest unchanged`, no diffs-only.
- Every script carries a semantic version header and a changelog block. Bump the
  version and add a changelog line for every functional change, however small.
- Comments explain *why*, not just *what* — especially around RLV quirks, dispatch
  behavior, and anything that previously caused a bug (see gotchas below).

### Version header format

```lsl
// ============================================================
// oc_spy.lsl — v1.5.2
// Part of: [Collar Project Name] custom plugin suite
//
// CHANGELOG:
// v1.5.2 - 2026-XX-XX - Fixed X, changed Y because Z
// v1.5.1 - ...
// ============================================================
```

## Critical Technical Gotchas (hard-won — do not relitigate these)

1. **CMD_ZERO dispatch mismatch.** `oc_core` dispatches Apps submenu button
   clicks with `iNum = 0`, not the auth constant. Every custom app script must
   handle `iNum == 0` explicitly and infer the auth level from the clicker's
   identity, since `oc_core` pre-validates access before dispatching. This was a
   systemic bug across the entire plugin suite — check for it in any new app
   script.
2. **`llParseString2List` truncation.** Using `=` or `_` as a delimiter
   truncates values that themselves contain that character (e.g. Discord
   webhook tokens with base64 padding, settings values with underscores). Use
   `llSubStringIndex` / `llGetSubString` for key=value parsing instead.
3. **`osGetNotecard()` is OSSL-only** — not available in Second Life LSL.
   Notecards must be read asynchronously via `llGetNotecardLine()` and a
   `dataserver` event handler.
4. **RLV restrictions are binary.** No price-awareness or conditional logic;
   `@buy=n` blocks all purchases regardless of cost. RLV relay does not need to
   be active for curfew force-TPs to work.
5. **RLVa vs base RLV.** `@chatshout=n` (shout-only blocking) is RLVa-exclusive
   (Firestorm). Unsupported restrictions fail silently in base RLV viewers — no
   special error handling needed for that case.
6. **LSL Unicode escapes unsupported.** `\u####` syntax renders as literal text
   in LSL. Use direct UTF-8 characters in string literals instead.
7. **Settings store underscore bug.** `LM_SETTING_RESPONSE` parsing with
   underscore as a delimiter truncates stored values — recurring issue, fix
   consistently wherever settings are parsed (see gotcha #2, same root cause).
8. **`llLoopSound()` before `ANIM_START`** can abort the event handler early in
   SL's LSL runtime. Sound calls should follow animation dispatch, not precede it.
9. **Weld state durability.** Collar weld persists via both the settings store
   and the prim description, making it significantly more durable than a simple
   lock flag alone.

## Architecture Patterns & Conventions

- **Single-script consolidation.** Related functionality stays in one script
  rather than being split across multiple app entries.
- **Roleplay-oriented UX.** Public local chat announcements are preferred over
  private IMs for visibility. Keep menu hierarchies clean and minimize click depth.
- **Pre-configuration via `.settings` notecard.** The collar is configured
  before distribution — lock state, weld, owner UUID, etc. are pre-loadable.
- **Cross-script auditing.** Before writing any change that touches shared
  subsystems (`oc_core`, `oc_auth`, `oc_settings`, `oc_dialog`, or the settings
  store format), check it against every plugin that depends on that behavior.
  Claude Code should grep the whole `plugins/` and `vendor/` trees for related
  usage before proposing a fix, not just the one file being edited.
- **Notion as living tracker.** Bugs, sessions, features, and roadmap items are
  logged in Notion (IDs below), not just in git commit messages.

## Custom Plugin Suite

| Script | Version (last known) | Purpose | In this repo? |
|---|---|---|---|
| `oc_spy.lsl` | v1.5.1 | Location tracking, local/attachment chat capture, Discord webhook delivery, GPS alerts w/ SLURLs, "No IM" mode | Needs pull from Drive (custom version, not stock) |
| `oc_wearermsg.lsl` | v1.1.0 | Ownership status display, lock date, days-enslaved counter | **Not in Project knowledge — pull from Drive** |
| `oc_shocker.lsl` | v1.3.3 | "Punish" app: Shock/Tighten/Spikes modes, animations, public announcements | Needs pull from Drive (custom version, not stock) |
| `oc_curfew.lsl` | v1.0.2 | SLT time-of-day curfew enforcer with RLV force-TP | **Not in Project knowledge — pull from Drive** |
| `oc_credits.lsl` | v1.1.2 | RLV `@pay`/`@buy` restriction toggles with timed expiration | **Not in Project knowledge — pull from Drive** |
| `oc_garble.lsl` | unconfirmed | Speech garbling: Standard, Puppy, Kitten modes | Needs pull from Drive (custom version, not stock) |
| `oc_lovense.lsl` | unconfirmed | External addon bridging to LoveBridge API for Lovense toy control | **Not in Project knowledge — pull from Drive** |
| `oc_remote.lsl` | not yet built | In-world LSL counterpart to the Cloudflare Worker remote control API (Track A) | Next build target |
| `oc_anim.lsl` | v1.0.1 | (confirm whether this has custom changes beyond stock or is unmodified) | Stock version present; verify against Drive |

**Action item:** pull the current versioned files for the "not in Project
knowledge" rows above from Google Drive into `plugins/` before doing any further
work on them — do not edit the stock `vendor/` copies under those filenames.

## In Progress / Roadmap

- Cloudflare Worker backend (v2.0.0) deployed, mid five-step validation
  sequence. Supports multi-collar-per-user and multi-user-per-collar with
  owner/controller/viewer roles, flat KV schema, per-collar token generation.
- `oc_remote.lsl` — next build target once Worker validation passes.
- Custom domain for the Worker via Cloudflare Pages, planned post-testing (to
  avoid exposing the Cloudflare username in the worker subdomain).
- RLVa `@chatshout=n` shout-blocking — evaluated for integration into one or
  more existing scripts; target script(s) not yet finalized.
- Blacklisted sims feature using RLV `@tpto` — logged as a backlog item in Notion.
- Outstanding: update the `.webhooks` notecard in-world to change `trace=` to `gps=`.
- Pending: in-world validation of `oc_shocker` v1.3.3 shock animation fix.

## External Systems

- **Notion workspace** (project hub `32f5b830-d652-81a5-ac12-e4ab7a048888`):
  Session Log `4b948561`, To-Do List `ed4df4e4`, Features & Roadmap `55b30dbd`,
  Bugs & Issues `9d9c0046`. Log bugs/features/sessions here as work happens —
  git commit messages are not a substitute for this.
- **Google Drive** — legacy script storage using a versioned-file +
  `CURRENT`-alias pattern. Being retired in favor of this git repo. During
  migration, Drive is still the authoritative source for the four plugins not
  yet pulled into `plugins/` (see table above).
- **Discord webhooks** — spy/GPS report delivery via rich embeds; webhook URLs
  live in the in-world `.webhooks` notecard, never commit real webhook URLs to
  this repo. Use `notecards/.webhooks.example` with placeholder values.
- **LoveBridge API** — Lovense toy control bridge used by `oc_lovense.lsl`.
- **Cloudflare Workers + KV** — remote control backend; deployed via Wrangler CLI
  from `worker/`.

## Versioning Convention (git)

This replaces the old Drive versioned-file + `CURRENT` alias pattern entirely.

- Bump the in-file version header and add a changelog entry for every functional
  change (see format above).
- Commit messages reference the script and version, e.g.
  `oc_spy v1.5.2: fix GPS alert SLURL truncation on long region names`.
- Tag stable, in-world-validated releases per script:
  `git tag oc_spy-v1.5.2`. Don't tag until it's been tested in-world — LSL can't
  be validated by CI, so a git tag here means "confirmed working in SL," not
  just "compiles."

## When Writing Or Fixing Code

1. Search `plugins/` and `vendor/` for related usage before proposing a fix —
   don't reason about one file in isolation, especially for anything touching
   `oc_core`, `oc_auth`, `oc_settings`, or `oc_dialog` behavior.
2. Check the change against the gotchas list above before finalizing.
3. Return the complete file, not a diff or excerpt.
4. Bump version + changelog in the file header.
5. Flag explicitly if a fix requires deviating from documented RLV/RLVa
   semantics, or if it touches `vendor/` reference behavior rather than a
   plugin.
