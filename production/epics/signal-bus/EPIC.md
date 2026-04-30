# Epic: Signal Bus

> **Layer**: Foundation
> **GDD**: `design/gdd/signal-bus.md`
> **Architecture Module**: Signal Bus (Events + EventLogger autoloads — `architecture.md` §3.1)
> **Engine Risk**: LOW
> **Status**: Ready
> **Stories**: 6 stories created 2026-04-29 (run `/story-readiness production/epics/signal-bus/story-001-*.md` to validate before implementation)
> **Manifest Version**: 2026-04-29

## Overview

Signal Bus is the project's typed event hub — a single autoload (`Events.gd`)
where every cross-system event in *The Paris Affair* is declared and dispatched.
Publishers emit typed signals directly; subscribers connect via the standard
`_ready`/`_exit_tree` lifecycle. The bus contains only signal declarations —
no methods, no state, no node references — to prevent the autoload-singleton-
coupling anti-pattern. A debug-only companion autoload `EventLogger` self-
removes in non-debug builds and connects to every signal at startup for
runtime tracing.

This epic implements the contract locked in ADR-0002 (Signal Bus + Event
Taxonomy) and the autoload registration order locked in ADR-0007 (Autoload
Load Order Registry). It is the foundational event-routing infrastructure
on which every other gameplay system depends — every cross-system reaction
in the game flows through this autoload.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0002: Signal Bus + Event Taxonomy | Single typed-signal autoload (`Events.gd`) with flat namespace + `subject_verb_past` naming; subscribers connect/disconnect on `_ready`/`_exit_tree`; enums owned by their concept's class, not the bus; `EventLogger` debug autoload self-removes in non-debug builds | LOW |
| ADR-0007: Autoload Load Order Registry | `Events` at autoload line 1; `EventLogger` at line 2; `*res://` scene-mode prefix on every entry; cross-autoload reference safety rules (no `_init()` cross-refs; `_ready()` may reference earlier-line autoloads only) | LOW |

## GDD Requirements

The `signal-bus.md` GDD is design-level rationale + acceptance criteria for the
ADR-0002 contract. Implementation requirements derive from ADR-0002 §Key
Interfaces (the 43-signal taxonomy, currently a representative skeleton in
`src/core/signal_bus/events.gd`) and ADR-0002 §Implementation Guidelines (8
rules covering autoload registration, enum ownership, subscriber lifecycle,
node payload validity, high-frequency event routing, engine-signal
non-re-emission, the `setting_changed` Variant exception, and the EventLogger
debug pattern).

Specific requirement traces are tracked in `docs/architecture/tr-registry.yaml`
under Signal Bus / `events.gd` ownership; story creation will pull current
TR-IDs from there.

## Definition of Done

This epic is complete when:

- All stories are implemented, reviewed, and closed via `/story-done`.
- All acceptance criteria from `design/gdd/signal-bus.md` are verified.
- The `Events` autoload's signal taxonomy matches ADR-0002 §Key Interfaces verbatim (43+ signals across 11 domains, owned-class enum types correctly resolved at parse time).
- `EventLogger` connects to every Events signal at `_ready()` and self-removes via `OS.is_debug_build()` in non-debug builds.
- The 5 forbidden patterns from ADR-0002 (`event_bus_with_methods`, `event_bus_wrapper_emit`, `event_bus_request_response`, `event_bus_engine_signal_reemit`, `event_bus_enum_definition`) are registered in the architecture registry.
- Every Logic story has a passing unit test in `tests/unit/foundation/` covering the publisher/subscriber pattern, lifecycle disconnect, and node-payload validity guards.
- Integration test exists demonstrating cross-autoload reference safety (Events line 1 → EventLogger line 2 connection at `_ready()` succeeds without null-deref).

## Verification Spike Status (Sprint 01, 2026-04-29)

A representative-subset skeleton of `events.gd` is in place at
`src/core/signal_bus/events.gd` with 8 signals plus a `smoke_test_pulse`
verification signal. The smoke test pipeline (emit → EventLogger prints →
subscriber receives) has been verified end-to-end on Godot 4.6.2 stable via
`prototypes/verification-spike/signal_bus_smoke.tscn` (closed ADR-0002 G1 +
ADR-0007 G(b)). The full 43-signal taxonomy lands incrementally as each
consumer class (`StealthAI`, `CombatSystemNode`, `LevelStreamingService`,
etc.) is implemented in its own epic; each addition is a paired commit and
the skeleton's `smoke_test_pulse` signal is removed when the production
taxonomy is complete.

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Events autoload — structural purity + registration finalization | Logic | Ready | ADR-0002 + ADR-0007 |
| 002 | Built-in-type signal declarations on `events.gd` | Logic | Ready | ADR-0002 |
| 003 | EventLogger autoload — debug subscription + non-debug self-removal | Integration | Ready | ADR-0002 |
| 004 | Subscriber lifecycle pattern + Node payload validity guard | Logic | Ready | ADR-0002 |
| 005 | Anti-pattern enforcement — forbidden patterns + CI grep guards | Config/Data | Ready | ADR-0002 |
| 006 | Edge case dispatch behavior — no-dedup + continue-on-error tests | Logic | Ready | ADR-0002 |

**Story sequencing**: 001 → 002 → 003 (sequential — 003 needs signals from 002 to subscribe to). 004, 005, 006 can run in parallel after 002+003 are done.

**Cross-epic deferred work for AC-3 (full 40-signal taxonomy)**: ~15 typed signals depend on enum classes that don't exist yet (`StealthAI.AlertState`, `CombatSystemNode.DeathCause`, `LevelStreamingService.TransitionReason`, `CivilianAI.WitnessEventType`, `SaveLoad.FailureReason`, `InputContext.Context`). Each consumer epic includes a story to add its domain's typed signals to `events.gd` in a paired commit. Signal Bus epic is COMPLETE when (a) all 6 stories above land + (b) the cross-epic AC-3 obligation closes (verified at the end of Foundation + Core + Feature implementation).

## Next Step

Run `/story-readiness production/epics/signal-bus/story-001-events-autoload-structural.md` to validate the first story is implementation-ready, then `/dev-story` to begin implementation.
