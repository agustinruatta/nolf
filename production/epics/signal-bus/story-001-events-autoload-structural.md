# Story 001: Events autoload — structural purity + registration finalization

> **Epic**: Signal Bus
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3 hours (S — surgical changes to existing skeleton + one new test file)
> **Manifest Version**: 2026-04-29

## Context

**GDD**: `design/gdd/signal-bus.md`
**Requirement**: Signal Bus AC 1, AC 2 (Autoload + structural)
*(TR-IDs: read from `docs/architecture/tr-registry.yaml` at /story-readiness time — Signal Bus rows pending registry sweep)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy) + ADR-0007 (Autoload Load Order Registry)
**ADR Decision Summary**: `Events.gd` is a single typed-signal autoload at line 1 of `project.godot` per ADR-0007 §Key Interfaces, registered with `*res://` scene-mode prefix. The bus contains ONLY signal declarations — no methods, no state, no node references. Class declared as `class_name SignalBusEvents extends Node`; autoload key `Events` (intentional class_name/key split per ADR-0002 §Implementation Guideline 2 + ADR-0002 amendment 2026-04-22).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Autoload registration mechanism + `signal` keyword + `Signal.connect/emit/disconnect/is_connected` are all stable Godot 4.0+. No post-cutoff APIs. ADR-0002 G1 + ADR-0007 G(a) + G(b) all closed in Sprint 01 verification — the existing skeleton at `src/core/signal_bus/events.gd` already passes structural purity checks.

**Control Manifest Rules (Foundation)**:
- Required: subscribers connect in `_ready` and disconnect in `_exit_tree` with `is_connected` guards (ADR-0002 IG 3) — applies to consumers, not the bus itself
- Required: enums in signal signatures must be defined on the system class that owns the concept (ADR-0002 IG 2)
- Forbidden: never add methods, state, or query helpers to `events.gd` — pattern `event_bus_with_methods`
- Forbidden: never define enums on `events.gd` — pattern `event_bus_enum_definition`
- Performance: signal bus emit cost bounded by per-signal frequency × subscriber count; all 43 events safe at expected frequencies (ADR-0002 IG 5)

---

## Acceptance Criteria

*From GDD §Acceptance Criteria:*

- [ ] **AC-1**: GIVEN the project is launched, WHEN the autoload list is inspected via `get_tree().root.get_children()`, THEN `Events` is present at the position declared by ADR-0007 (line 1, before `EventLogger` at line 2).
- [ ] **AC-2**: GIVEN `Events.gd` source file, WHEN linted/grepped for `func `, `var `, or `const ` declarations (excluding the `class_name` and `extends` header), THEN zero matches (per ADR-0002 forbidden_pattern `events_with_state_or_methods`).
- [ ] **AC-3**: GIVEN the Sprint 01 verification skeleton at `src/core/signal_bus/events.gd`, WHEN this story's changes ship, THEN the verification-only `smoke_test_pulse` signal declaration is removed (per ADR-0002 Revision History 2026-04-29: "the skeleton's `smoke_test_pulse` signal is verification-only and is removed when the production taxonomy is complete") AND the `events_purity_test.gd` test confirms the file contains zero non-signal declarations.

---

## Implementation Notes

*Derived from ADR-0002 + ADR-0007 Implementation Guidelines:*

The Sprint 01 skeleton at `src/core/signal_bus/events.gd` already establishes:
- `class_name SignalBusEvents extends Node`
- 8 representative signals using only built-in types
- Empty `_ready()` (per-ADR-0007 §Cross-Autoload Reference Safety rule 2: this autoload at line 1 may not reference any later autoload)

This story:
1. Confirms the autoload entry in `project.godot` matches ADR-0007 §Key Interfaces verbatim (`Events="*res://src/core/signal_bus/events.gd"` at line 1 of the `[autoload]` block).
2. Removes the verification-only `smoke_test_pulse` signal from the skeleton (it served Sprint 01's smoke test; production taxonomy uses real domain signals).
3. Adds an automated grep test (`tests/unit/foundation/events_purity_test.gd`) that fails CI if `events.gd` ever gains a `func `, `var `, or `const ` declaration outside the header.
4. Removes the `_ready() pass` from the skeleton if no init logic is needed (Story 003's EventLogger does the heavy lifting; Events itself has nothing to do at `_ready`).

Story 002 (next) populates `events.gd` with the production signal subset.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: built-in-type signal declarations (the actual signal taxonomy — Player, Mission, Documents, Persistence, Settings, etc. domains)
- Story 003: EventLogger debug autoload setup
- Story 005: forbidden-pattern registration + CI grep guards (AC 9, 10, 13, 14)
- All consumer epics: domain-specific signal additions that depend on enum types from non-existent classes (Stealth AI, Combat, Level Streaming, Civilian AI, etc.)

---

## QA Test Cases

**AC-1**: Events autoload is registered at line 1
- **Given**: project boots normally with `project.godot` `[autoload]` block as written
- **When**: a test scene's `_ready()` runs and inspects `get_tree().root.get_children()`
- **Then**: a child Node exists at name `Events` and is of type `SignalBusEvents`; its index in `root.get_children()` precedes `EventLogger`
- **Edge cases**: missing autoload entry (Godot logs "Script not found" — test asserts presence, not absence-of-warnings); script syntax error (autoload nil — test fails clearly with "Events not found")

**AC-2**: events.gd structural purity
- **Given**: `src/core/signal_bus/events.gd` source as committed
- **When**: an automated grep test reads the file and counts non-header declarations
- **Then**: zero `func ` declarations (excluding any standard `_ready` if kept), zero `var ` declarations, zero `const ` declarations beyond the LOG_PREFIX-style debug constants if any are explicitly allowed
- **Edge cases**: comments containing `func`/`var`/`const` keywords (test must respect comment lines); `class_name` line and `extends` line excluded by definition

**AC-3**: smoke_test_pulse cleanup
- **Given**: `src/core/signal_bus/events.gd` post-change
- **When**: the file is grepped for `signal smoke_test_pulse`
- **Then**: zero matches (the verification-only signal is gone)
- **Edge cases**: leftover comment referencing `smoke_test_pulse` (acceptable — comment is not a declaration); residual `EventLogger._on_smoke_test_pulse` handler in EventLogger.gd (out of scope here — Story 003 handles EventLogger cleanup)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/foundation/events_autoload_registration_test.gd` — must exist and pass (AC-1)
- `tests/unit/foundation/events_purity_test.gd` — must exist and pass (AC-2 + AC-3; the same purity test asserts zero `signal smoke_test_pulse` matches alongside its existing func/var/const checks — no new test file required)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (Sprint 01 skeleton already in place)
- Unlocks: Story 002 (signal declarations), Story 003 (EventLogger), Story 004 (lifecycle tests)
