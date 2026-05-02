# Story 007: LOADING context gate integration

> **Epic**: Input
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 2-3 hours (S-M — 1 integration test file; LOADING enum value already present in ADR-0004)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/input.md`
**Requirements**: `TR-INP-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 (UI Framework — Theme + InputContext + FontRegistry) + ADR-0002 (Signal Bus + Event Taxonomy)
**ADR Decision Summary**: `InputContext.LOADING` was added to the `Context` enum in ADR-0004 Amendment A6 (2026-04-28). Push/pop authority: `LevelStreamingService` (autoload line 5) is the sole pusher/popper of `LOADING` (per ADR-0004 IG 13 push/pop authority table). During `LOADING`, ALL gameplay input is swallowed — Combat's `_unhandled_input` `is_active(GAMEPLAY)` check returns `false`, Save/Load's quicksave handler gates on LOADING and returns early. The GDD AC-INPUT-8.1 previously marked this story "BLOCKED pending ADR-0004 LOADING amendment" — that amendment has been applied (2026-04-28) and this story is **unblocked**.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `InputContext.LOADING` enum value is present in the ADR-0004 §Key Interfaces `Context` enum as of 2026-04-28. Verify it is present in `events.gd` (signal `ui_context_changed` enum type must include `LOADING`) and in the production `InputContextStack` implementation from Story 002. `Input.parse_input_event()` for synthetic event injection is the correct test API. The LOADING context gate behavior (swallowing all gameplay input) is pure GDScript logic in handlers' `is_active()` checks — no engine-specific risk beyond what Story 002 already covers.

**Control Manifest Rules (Core)**:
- Required: subscribers connect in `_ready` and disconnect in `_exit_tree` with `is_connected` guards (ADR-0002 IG 3)
- Required: `InputContext` line 4 — MUST reference `LevelStreamingService` (line 5) only via signals, never via direct `_ready()` reference (ADR-0007 IG 4 cross-autoload reference safety — `InputContext` at line 4 cannot reference line 5 in `_ready()`)
- Required: push/pop authority for `LOADING` is `LevelStreamingService` — this story uses a test fixture standing in for LevelStreamingService; the production implementation lives in the Level Streaming epic
- Forbidden: `cross_context_event_consumption` — handlers consuming without context check (this story tests that the context check properly swallows events during LOADING)

---

## Acceptance Criteria

*From GDD `design/gdd/input.md` §Acceptance Criteria, scoped to this story:*

- [ ] **AC-INPUT-8.1 [Integration] BLOCKING**: Level Streaming fixture pushes `InputContext.LOADING` (test stand-in for LevelStreamingService); test injects `InputEventKey` for `fire_primary` during the LOADING context; Combat fixture's `_unhandled_input` handler's `InputContext.is_active(GAMEPLAY)` check returns `false` — no shot fires (subscriber-call-count = 0 on Combat handler); test injects `InputEventKey` for `quicksave` (F5); Save/Load fixture's quicksave handler returns early — save is NOT triggered (call-count = 0 on save handler). Test then pops `LOADING`; re-injects `fire_primary`; Combat handler fires (call-count = 1). Evidence: `tests/integration/core/input/loading_context_gate_test.gd`.
- [ ] **LOADING enum present [Logic] BLOCKING** (implied by AC-INPUT-8.1 feasibility): `InputContext.Context.LOADING` resolves without error in GDScript; `InputContext.push(InputContext.Context.LOADING)` executes without assert. Evidence: covered within `loading_context_gate_test.gd`.

---

## Implementation Notes

*Derived from ADR-0004 §Key Interfaces (LOADING context push/pop authority) + GDD §Detailed Rules Core Rule 3 + §Edge Cases:*

**LOADING context push/pop authority** (ADR-0004 IG 13):
- Pusher: `LevelStreamingService` (sole authority)
- Popper: `LevelStreamingService` (sole authority)
- Pop timing: at transition step 11, when `section_entered` fires

This story uses a minimal test fixture as a `LevelStreamingService` stand-in that calls `InputContext.push(InputContext.Context.LOADING)` and `InputContext.pop()`. The production `LevelStreamingService` autoload implementation lives in the Level Streaming epic.

**Test fixtures needed**:

1. **Level Streaming fixture** — calls `InputContext.push(Context.LOADING)` and `InputContext.pop()`
2. **Combat fixture** — `_unhandled_input()` checks `is_active(Context.GAMEPLAY)` before processing `fire_primary`; emits a signal when it would fire
3. **Save/Load fixture** — `_unhandled_input()` checks `is_active(Context.GAMEPLAY)` (or a separate LOADING check) before processing `quicksave`; emits a signal when it would save

```gdscript
# Combat fixture — minimal stand-in
extends Node

signal shot_fired

func _unhandled_input(event: InputEvent) -> void:
    if not InputContext.is_active(InputContext.Context.GAMEPLAY):
        return
    if event.is_action_pressed(&"fire_primary"):
        get_viewport().set_input_as_handled()
        shot_fired.emit()

# Save/Load fixture — minimal stand-in
extends Node

signal save_triggered

func _unhandled_input(event: InputEvent) -> void:
    if not InputContext.is_active(InputContext.Context.GAMEPLAY):
        return
    if event.is_action_pressed(&"quicksave"):
        get_viewport().set_input_as_handled()
        save_triggered.emit()
```

**`Events.ui_context_changed` during LOADING**: the push to `LOADING` and pop back to the previous context both emit `Events.ui_context_changed(new, old)` per `InputContextStack.push()` and `pop()` implementations. Subscribers (HUD Core, Audio duck) observe these events. This is tested passively by the existing stack tests in Story 002; Story 007 focuses on the handler gate behavior.

**Note on `LOADING` vs `GAMEPLAY` for Save/Load**: the GDD says Save/Load's quicksave handler "gates on LOADING" and returns early. The fixture implements this as "gates on GAMEPLAY" (i.e., checks `is_active(GAMEPLAY)` — if not in GAMEPLAY, returns). This is equivalent because LOADING is not GAMEPLAY. The exact Save/Load gating logic is defined in the Save/Load epic — this story's fixture demonstrates the required behavior.

---

## Out of Scope

*Handled by neighbouring stories / epics — do not implement here:*

- Level Streaming epic: production `LevelStreamingService` autoload with the real push/pop at transition steps 1 and 11
- Save/Load epic: production quicksave handler with LOADING gate (this story uses a minimal fixture only)
- Combat epic: production `fire_primary` handler (this story uses a minimal fixture only)
- Story 002: `InputContext.LOADING` enum value must already be present in the production implementation — if Story 002 shipped before the ADR-0004 Amendment A6 was applied, verify the enum was updated
- AC-INPUT-10.1 (quicksave diegetic feedback via HUD Core): forward dependency on HUD Core epic — when HUD Core is authored, its integration test covers F5 toast rendering. The Input epic's contribution is AC-INPUT-1.1 (F5 fires the `quicksave` action, covered in Story 001). AC-INPUT-10.1 is NOT a story in this epic.

---

## QA Test Cases

**AC-INPUT-8.1 — LOADING context gates all gameplay input**
- **Given**: Level Streaming fixture, Combat fixture, Save/Load fixture all in scene tree; `InputContext.current() == GAMEPLAY` (base state); GUT signal subscriptions on `shot_fired` and `save_triggered`
- **When**: Level Streaming fixture calls `InputContext.push(InputContext.Context.LOADING)`; then `InputEventKey(KEY_NONE for fire_primary action)` injected — verify: `shot_fired` call count = 0
- **When**: `InputEventKey(KEY_F5 for quicksave action)` injected during LOADING
- **Then**: `save_triggered` call count = 0
- **When**: Level Streaming fixture calls `InputContext.pop()` (back to GAMEPLAY)
- **When**: `fire_primary` event re-injected
- **Then**: `shot_fired` call count = 1 (handler fires correctly after LOADING lifted)
- **Edge cases**: LOADING pushed twice (Level Streaming fixture error) → `pop()` returns to LOADING, not GAMEPLAY; test must pop twice to return to base. The assert in `pop()` only fires on underflow (size ≤ 1), not on double-LOADING.

**LOADING enum presence**
- **Given**: `InputContextStack` production implementation from Story 002
- **When**: GDScript accesses `InputContext.Context.LOADING`
- **Then**: no GDScript parse error; `InputContext.push(InputContext.Context.LOADING)` executes without crash or assert
- **Edge cases**: if the enum was not updated in Story 002's implementation (enum only had the original 5 values), this test fails with a GDScript identifier error — fix by verifying Story 002 includes all 7 enum values from ADR-0004 §Key Interfaces

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/core/input/loading_context_gate_test.gd` — must exist and pass (AC-INPUT-8.1)

**Status**: [x] Complete — 6 tests; suite 693/693 PASS exit 0.

---

## Completion Notes

**Completed**: 2026-05-02
**Criteria**: 2/2 PASSING (AC-8.1, LOADING enum presence)

**Test Evidence**: `tests/integration/core/input/loading_context_gate_test.gd` (NEW, 6 tests):
- LOADING enum resolves at parse time
- push(LOADING) executes without crash
- AC-8.1: fire_primary swallowed during LOADING
- AC-8.1: quicksave swallowed during LOADING
- AC-8.1: handlers fire normally after pop returns to GAMEPLAY
- ui_context_changed emits both transitions (GAMEPLAY→LOADING and LOADING→GAMEPLAY)

Suite: **693/693 PASS** exit 0 (baseline 687 + 6 new IN-007 tests).

**Files Modified / Created**: 1 new test file. No production code changes (Story 002 already had the LOADING enum value per ADR-0004 Amendment A6 from Sprint 02; this story validates the gate behavior using fixtures stand-in for LevelStreamingService / Combat / Save-Load).

**INPUT EPIC COMPLETE**: All Sprint 04 Input stories (IN-003, IN-004, IN-005, IN-006, IN-007) now closed. Sprint progress 15/16; only PC-006 remains.

---

## Open Questions

| Question | Owner | Status |
|---|---|---|
| Does `InputMap.has_event(event)` exist as a top-level API in Godot 4.6 (needed by Story 006 AC-INPUT-4.2a), or must the implementation iterate over all actions? | Lead Programmer | Open — verify against `docs/engine-reference/godot/` before Story 006 sprint |
| Headless CI `OS.is_debug_build()` — does the GUT runner run as debug or release? Affects Story 002's debug-action registration test. | Lead Programmer | Open — document in CI configuration or add a build-mode flag to the test runner |

---

## Dependencies

- Depends on: Story 001 (InputActions constants, including `QUICKSAVE` and `FIRE_PRIMARY`), Story 002 (InputContextStack with full 7-value `Context` enum including `LOADING`)
- Unlocks: Level Streaming epic (production implementation of LOADING push/pop; its integration tests verify the real LevelStreamingService pushes LOADING at step 1 and pops at step 11); Save/Load epic (production quicksave handler gate against LOADING context)
