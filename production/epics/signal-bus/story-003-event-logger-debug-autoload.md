# Story 003: EventLogger autoload — debug subscription + non-debug self-removal

> **Epic**: Signal Bus
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-29

## Context

**GDD**: `design/gdd/signal-bus.md`
**Requirement**: Signal Bus AC 11 (EventLogger debug)

**ADR Governing Implementation**: ADR-0002 §Implementation Guideline 8 + ADR-0007 §Cross-Autoload Reference Safety
**ADR Decision Summary**: `EventLogger.gd` connects to every signal on `Events` at `_ready()` and prints emit timestamps via `print()`. It self-removes in non-debug builds via `OS.is_debug_build()`. Registered as autoload key `EventLogger` at line 2 of `project.godot` per ADR-0007. Cross-autoload reference safety: line 2 may reference line 1 (`Events`) at `_ready()` — this is the canonical safe direction.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: ADR-0007 G(b) was closed in Sprint 01 by the smoke test (`prototypes/verification-spike/signal_bus_smoke.tscn`) — the cross-autoload reference safety pattern is empirically verified. `OS.is_debug_build()` returns true for `--debug` runs and false for release exports; auto-removal in `_ready` runs before any user code emits a signal.

**Control Manifest Rules (Foundation)**:
- Required: subscribers connect in `_ready` and disconnect in `_exit_tree` with `is_connected` guards (this story is the canonical implementation of the lifecycle pattern)
- Required: an autoload's `_ready()` may reference earlier-line autoloads only (Events at line 1 → reachable from EventLogger at line 2)
- Forbidden: production code MUST NOT call `EventLogger` methods (it's debug-only, removable at runtime)
- Performance: connection cost ~25 signals × one Callable each ≈ negligible at startup

---

## Acceptance Criteria

*From GDD §Acceptance Criteria:*

- [ ] **AC-11-A**: GIVEN the project is launched in debug mode, WHEN any `Events` signal is emitted, THEN `EventLogger` prints a timestamped line to the Godot output console with the signal name and arguments.
- [ ] **AC-11-B**: GIVEN the project is launched in non-debug release export, WHEN any `Events` signal is emitted, THEN no `EventLogger` log line is printed (because `EventLogger` self-removed in `_ready` via `OS.is_debug_build()` returning false).

---

## Implementation Notes

*Derived from ADR-0002 IG 8 + Sprint 01 verification:*

The Sprint 01 skeleton at `src/core/signal_bus/event_logger.gd` already implements the basic pattern: `_ready()` connects to `Events.smoke_test_pulse` and prints emissions with the `[EventLogger]` prefix. This story extends to the full subset of signals declared in Story 002.

Implementation steps:

1. In `_ready()`, FIRST check `if not OS.is_debug_build(): queue_free(); return`. The self-removal happens at the start so no further code runs in non-debug builds.
2. Otherwise, connect a single per-signal handler to every signal declared on `Events` (the in-scope ~25 signals from Story 002). Use `Events.<signal>.connect(_on_<signal>)` for each.
3. Each `_on_<signal>(args...)` handler prints a single line: `[EventLogger] <signal_name>(<args formatted as repr>)`. Use `Time.get_datetime_string_from_system()` or `Time.get_ticks_msec()` for timestamping per AC-11-A.
4. Connection bookkeeping: a `_connections: Array[Dictionary]` records `{signal: Signal, callable: Callable}` for each connection so `_exit_tree` can disconnect cleanly even though autoloads typically don't `_exit_tree` during normal play.
5. Do NOT introduce per-domain logger classes or filter logic in this story. EventLogger is a flat "log everything in debug" tool. Per-domain filtering is post-MVP if ever (most likely never — devs use grep on the logged output).
6. The smoke-test pulse signal should be removed from `events.gd` in Story 002; this story removes the `_on_smoke_test_pulse` handler in `event_logger.gd` correspondingly.

Cross-autoload reference safety: this autoload's `_ready()` is permitted to reference `Events` directly (line 1 < line 2 per ADR-0007 §Cross-Autoload Reference Safety rule 2). Empirically verified by Sprint 01 smoke test.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: signal declarations on `Events` (this story consumes them)
- Story 005: forbidden-pattern fence preventing production code from calling `EventLogger` methods (lint rule, separate concern)
- Per-signal handler optimization (e.g., one generic handler with reflection vs ~25 specific handlers) — chose specific for clarity; revisit if EventLogger startup cost becomes measurable

---

## QA Test Cases

**AC-11-A**: Debug-build EventLogger logs every signal
- **Given**: project launched with `--debug` (debug build); Story 002's signals declared
- **When**: a test scene emits `Events.player_health_changed.emit(50.0, 100.0)` (or any in-scope signal)
- **Then**: stdout/Godot console contains a line matching pattern `[EventLogger] player_health_changed(50.0, 100.0)` with a timestamp prefix
- **Edge cases**: signal with no payload (`settings_loaded`) — log line still appears with empty args; signal emitted before EventLogger's `_ready` runs (impossible per autoload init order, but test asserts the line is reachable in test setup); signal emitted from another autoload's `_ready` (sequencing — Events at line 1, EventLogger at line 2; emission from line ≥ 3 is safely after both)

**AC-11-B**: Non-debug build EventLogger self-removes
- **Given**: project exported in non-debug release mode (`OS.is_debug_build()` returns false)
- **When**: a test scene emits `Events.player_health_changed.emit(50.0, 100.0)`
- **Then**: no `[EventLogger]` log line appears in stdout/console; `EventLogger` autoload is no longer in the scene tree (`get_node_or_null("/root/EventLogger") == null` after one frame)
- **Edge cases**: `OS.is_debug_build()` returning unexpected value in some build configs — test asserts behavior in BOTH modes via separate test invocations, not assumes either mode; signal emitted on the same frame as the queue_free (race against frame boundary) — the queue_free + early return pattern eliminates the race because the connect calls never run

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/foundation/event_logger_debug_test.gd` — verifies AC-11-A with debug build mode
- Manual verification doc at `production/qa/evidence/event_logger_release_self_removal.md` — exporting a release build and confirming no `[EventLogger]` lines appear (release-build test cannot be fully automated headlessly)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (signals exist for EventLogger to subscribe to)
- Unlocks: Story 004 (subscriber lifecycle tests can use EventLogger as a real subscriber example), Story 006 (edge case tests verify EventLogger plus another subscriber both receive emissions)
