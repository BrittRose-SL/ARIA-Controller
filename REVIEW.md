# Review instructions

This repo is a custom LSL plugin suite for Second Life (OpenCollar 8.3 base)
plus a Cloudflare Worker backend. This file recalibrates severity for LSL's
constraints, scopes review away from stock reference code, and adds
repo-specific checks that a generic reviewer won't know to look for. It's
injected as the highest-priority instruction for every `/code-review` run —
see `CLAUDE.md` for the full standards and architecture reference this draws
from.

## Scope

- **`plugins/`** — primary review target. This is the actual custom code that
  ships on the collar. Review every file here fully.
- **`vendor/opencollar-8.3/`** — stock, unmodified reference only. Never
  propose fixes here and never flag it as if it needs updating — it exists so
  plugin changes can be checked for compatibility against core dispatch/auth/
  settings behavior, not to be edited itself. If a plugin's behavior only
  makes sense in light of something in `vendor/`, cross-reference it, don't
  flag the vendor file.
- **`templates/`** — check that placeholder/example content stays valid as a
  starting point (e.g. correct message-map skeleton), not as if it were a
  finished plugin. Don't flag "incomplete" logic that's an intentional
  template gap.
- **`worker/`** — JavaScript/Cloudflare Worker code, not LSL. Apply normal JS
  and web-security review standards here (secrets handling, input validation,
  KV access patterns), not the LSL-specific rules below.
- **`notecards/*.example`** — documentation placeholders, skip entirely.

## What Important means here

Reserve **Important** for findings that would break in-world behavior, cause
scripts to silently fail for some auth level or RLV client, corrupt or
truncate stored settings, or cause two scripts to conflict with each other
(channel collision, constant collision, dispatch mismatch). These are things
that won't show up as a compile error but will fail quietly in Second Life.

## What Critical means here

Reserve **Critical** for anything that plainly will not compile or run as
LSL, or that has already caused the systemic bugs documented below and is
recurring: ternary operators, `break` statements, non-explicit `if`/`else`,
`osGetNotecard()` calls, `\u####` escape sequences, or a missing `CMD_ZERO`
handler in a new app script.

## What Nit means here

Style preferences that don't affect correctness: comment density, naming
consistency, whether a helper function is split out — and only when they
don't touch anything in the Critical/Important lists below.

## Repo-specific checks — hard rules (Critical)

- **No ternary operators.** Any `? :` usage — flag regardless of context.
- **No `break` statements.** Restructure with explicit conditionals or state
  flags instead — flag any `break` found inside a loop.
- **Explicit `if`/`else` only.** No shorthand or implicit fallthrough.
- **No `osGetNotecard()`.** Not available in Second Life LSL — notecards must
  be read via `llGetNotecardLine()` + a `dataserver` event handler. Flag any
  synchronous notecard read attempt.
- **No `\u####` Unicode escapes.** They render as literal text in LSL — flag
  and require direct UTF-8 characters instead.
- **Version header + changelog required.** Every functional change must bump
  the in-file semantic version and add a changelog line. Flag a diff that
  changes behavior but leaves the version header untouched.

## Repo-specific checks — known systemic bugs (Important)

These have each caused real bugs across this suite before. Check for
recurrence on every touched file, not just new code:

- **CMD_ZERO dispatch.** `oc_core` dispatches Apps submenu clicks with
  `iNum = 0`, not an auth constant. Any app script handling menu button
  clicks must explicitly handle `iNum == 0` and infer auth level from the
  clicker's identity. Flag any new/changed dispatch handler that doesn't.
- **Delimiter truncation.** `llParseString2List` with `=` or `_` as a
  delimiter truncates values containing that character (webhook tokens,
  settings values). Flag any use of `=`/`_` as a list-parse delimiter;
  `llSubStringIndex`/`llGetSubString` should be used for key=value parsing
  instead.
- **`llLoopSound()` ordering.** Calling `llLoopSound()` before dispatching
  `ANIM_START` can abort the event handler early. Flag any script where a
  sound call precedes animation dispatch in the same handler.
- **RLV restrictions are binary.** No price-awareness or conditional logic is
  possible with restrictions like `@buy=n`. Flag any code that assumes
  partial/conditional RLV restriction behavior.
- **RLVa-only restrictions fail silently by design.** `@chatshout=n` and
  similar RLVa-exclusive restrictions simply do nothing on base-RLV viewers —
  this is expected. Do not flag the absence of error handling for unsupported
  RLVa restrictions; do flag it if new code assumes such a restriction always
  succeeds.
- **Weld persistence.** Weld state must be written to both the settings store
  and the prim description to remain durable. Flag any weld-related change
  that only updates one of the two.

## Cross-script consistency checks (Important)

Single-file review won't catch these — check across all of `plugins/`
together, not just the file being changed:

- **Settings key naming.** A key written by one script must match exactly
  what any other script (or `oc_core`/`oc_settings` in `vendor/`) expects to
  read. Flag mismatched or newly-introduced key names that don't match
  existing conventions.
- **`link_message` channel collisions.** Two plugins listening on or sending
  to the same channel with overlapping message content can cross-talk. Flag
  any new channel number that's already in use elsewhere in `plugins/` or
  `vendor/`.
- **`listen()` filter overlaps.** Same channel + overlapping name/id filters
  across scripts can cause one script to consume a chat command meant for
  another. Flag overlaps.
- **`CMD_*` constant reuse.** Message-map constants (`CMD_OWNER`, `CMD_WEARER`,
  etc., and any custom `CMD_*` added by a plugin) must not collide with
  constants used elsewhere in the suite for a different purpose. Flag reused
  integer values with different meanings.

## What NOT to flag

Patterns that look like problems to a generic reviewer but are correct or
intentional in this codebase:

- Asynchronous notecard reads via a `dataserver` event chain — this is the
  correct (only) LSL pattern, not a code smell.
- Public local-chat announcements instead of private IMs for punishment/status
  events — an intentional roleplay-visibility choice, not an oversight.
- No automated test suite — LSL cannot be unit tested outside Second Life;
  don't suggest adding one. Validation happens in-world.
- RLVa-exclusive restrictions with no fallback behavior for base RLV viewers —
  see above, this is by design.

## Style conventions (Nit-level only)

- Prefer consolidating related functionality into one script over splitting
  it across multiple app entries.
- Keep menu hierarchies shallow — minimize click depth.
- Comments should explain *why*, especially near anything on the systemic-bug
  list above, not just restate what the line does.
