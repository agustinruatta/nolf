# Story 003: Replay suppression + one-active invariant

> **Epic**: Cutscenes & Mission Cards
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: 3-4 hours (M — `_try_fire_card` logic + dismiss priority table + 4 test files)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/cutscenes-and-mission-cards.md`
**Requirements**: TR-CMC-006, TR-CMC-015
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

- **TR-CMC-006**: Replay-suppression via `MissionState.triggers_fired: Array[StringName]` (read-only from Cutscenes; owned by MLS — sole writer per CR-CMC-21 + ADR-0003).
- **TR-CMC-015**: Save/Load CR-6: F5 silent-drop during `InputContext.CUTSCENE` per ADR-0003 + ADR-0004 modal-dismiss precondition.

**ADR Governing Implementation**: ADR-0004 (UI Framework — InputContext stack) + ADR-0003 (Save Format Contract — MissionState schema) + ADR-0002 (Signal Bus)
**ADR Decision Summary**: The `fires(scene_id, event)` predicate (GDD F.3) is the sole gate deciding whether a card or cinematic is instantiated. It checks three conditions in order: (1) `reason(event) == FORWARD` (CR-CMC-4 unconditional suppress on RESPAWN/NEW_GAME/LOAD_FROM_SAVE); (2) `scene_id NOT IN MissionState.triggers_fired` (CR-CMC-2 replay suppression — read-only access via `MissionLevelScripting.get_mission_state()`); (3) `InputContext.current() != Context.CUTSCENE` (CR-CMC-17 one-active invariant). All three gates are ordered — the unconditional suppress short-circuits before the dict lookup (F.3 clause ordering). F5 quicksave is silently dropped while `InputContext.CUTSCENE` is active per Save/Load CR-6 (enforced at `SaveManager._unhandled_input`, not at Cutscenes).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Array[StringName].has()` is a linear scan over ≤20 entries — O(N) per F.2 formula, 0.001 ms amortised. `MissionLevelScripting.get_mission_state()` must return the **live `MissionState` resource instance** (not a `duplicate()`), per OQ-CMC-6 BLOCKING coord — a stale duplicate would silently break replay suppression. `SceneTree.create_timer(duration, true)` dismiss-gate timer: `process_always = true` second argument defends against any future `SceneTree.paused = true` state (GDD §C.2.1 + VG-CMC-5).

**Control Manifest Rules (Foundation — Signal Bus + Save/Load)**:
- Required: every Node-typed signal payload MUST be checked with `is_instance_valid(node)` before dereferencing (ADR-0002 IG 4)
- Required: `SaveGame.FORMAT_VERSION` const discipline — Cutscenes never writes to save state (ADR-0003 IG 1 — read-only consumer)
- Forbidden: Cutscenes writing to `MissionState.triggers_fired` — sole writer is MLS (CR-CMC-21, ADR-0003); Cutscenes is read-only
- Forbidden: `cmc_publishing_mission_signals` — Cutscenes must never emit Mission-domain signals (CR-CMC-1, FP-CMC-10)
- Guardrail: `triggers_fired` read is O(N) over ≤20 entries (F.2 formula); do not cache the array reference — always read via `MissionLevelScripting.get_mission_state().triggers_fired` at gate-evaluation time (stale cache would break EC-CMC-B.4)

---

## Acceptance Criteria

*From GDD `design/gdd/cutscenes-and-mission-cards.md` AC-CMC-3.1 through AC-CMC-3.5, AC-CMC-5.1 through AC-CMC-5.4, plus EC-CMC-B.4:*

**Replay suppression (F.3 predicate):**

- [ ] **AC-1**: GIVEN `MissionState.triggers_fired` does NOT contain `&"mc_briefing_paris_affair"` AND `reason == FORWARD` AND `InputContext.current() == GAMEPLAY`, WHEN `_try_fire_card(&"mc_briefing_paris_affair", CardType.MISSION_BRIEFING, TransitionReason.FORWARD)` is called, THEN `_open_card()` is called and `InputContext.CUTSCENE` is pushed. (AC-CMC-3.1)
- [ ] **AC-2**: GIVEN `MissionState.triggers_fired` already contains `&"mc_briefing_paris_affair"`, WHEN `_try_fire_card(&"mc_briefing_paris_affair", CardType.MISSION_BRIEFING, TransitionReason.FORWARD)` is called, THEN `_open_card()` is NOT called, `InputContext` is not pushed, no CanvasLayer instanced. (AC-CMC-3.2)
- [ ] **AC-3**: GIVEN `triggers_fired` does NOT contain `&"ct_03_kitchen_egress"`, WHEN `_try_fire_card(&"ct_03_kitchen_egress", CardType.CINEMATIC, TransitionReason.RESPAWN)` is called, THEN the function returns immediately before any `triggers_fired.has()` check. `_open_card()` NOT called. Spy on `MissionState.triggers_fired.has()` records zero calls (RESPAWN branch short-circuits per CR-CMC-4 before CR-CMC-2). (AC-CMC-3.3)
- [ ] **AC-4**: GIVEN `triggers_fired` does NOT contain `&"ct_04_the_rappel"`, WHEN `_try_fire_card` is called with `reason == NEW_GAME` then `reason == LOAD_FROM_SAVE`, THEN both calls suppress unconditionally; spy on `triggers_fired.has()` records zero calls for both. (AC-CMC-3.4)
- [ ] **AC-5**: GIVEN `Events.game_loaded` fires with loaded `triggers_fired` containing `&"mc_briefing_paris_affair"` and `&"ct_03_kitchen_egress"`, WHEN `_on_game_loaded()` executes, THEN: (a) `InputContext.is_active(CUTSCENE) == false`; (b) `_open_card()` spy records zero calls; (c) a subsequent `Events.mission_started.emit(...)` is suppressed by CR-CMC-2 (briefing card in `triggers_fired`). (AC-CMC-3.5)

**One-active invariant (CR-CMC-17):**

- [ ] **AC-6**: GIVEN `InputContext.CUTSCENE` already on stack, WHEN any second trigger handler fires (any of `_on_mission_started`, `_on_mission_completed`, `_on_objective_started`, `_on_section_entered`), THEN handler checks `InputContext.is_active(CUTSCENE)` first, returns immediately without calling `_open_card()` or `_start_cinematic()`, and emits `push_warning("[Cutscenes] drop: [scene_id] — context already CUTSCENE")` in debug builds. (AC-CMC-5.1) — BLOCKED on OQ-CMC-1
- [ ] **AC-7**: GIVEN `mission_started` and `objective_started` dispatched same-frame in sequential synchronous order (mission_started emitted first per MLS dispatch contract), WHEN both handlers execute, THEN Mission Card wins: `_open_card` called once with Mission Card `scene_id`; `push_warning` spy records one drop message for the objective card; `_current_scene_id` == Mission Card scene_id. (AC-CMC-5.2)
- [ ] **AC-8**: GIVEN cinematic active (CT-03/04/05 pushed CUTSCENE), WHEN `objective_started` fires for an opt-in objective, THEN handler finds CUTSCENE active and drops silently; `push_warning` contains dropped scene_id; `_current_scene_id` unchanged. (AC-CMC-5.3)
- [ ] **AC-9**: GIVEN `CUTSCENE` on stack and `_context_pushed == true`, WHEN `_cleanup()` called from any exit path, THEN `InputContext.pop()` called once and `_context_pushed = false`. GIVEN `_context_pushed == false` when `_cleanup()` called, THEN `InputContext.pop()` NOT called. (AC-CMC-5.4) — BLOCKED on OQ-CMC-1

**EC-CMC-B.4 — BLOCKING for VS DOD:**

- [ ] **AC-10**: GIVEN `CutscenesAndMissionCards` subscribes to `game_loaded` and reads `MissionState` via live reference from `MissionLevelScripting.get_mission_state()`, WHEN New Game on slot 1 initialises fresh `MissionState` and then slot 5 is loaded (replacing the live `MissionState` reference in `MissionLevelScripting`), THEN `_try_fire_card` subsequently reads slot 5's `triggers_fired` exclusively — slot 1's empty `triggers_fired` never contaminates slot 5's replay-suppression gate. Verification: after slot 5 load, `triggers_fired.has(&"mc_briefing_paris_affair") == true` (slot 5 has fired briefing card), and a subsequent `mission_started` signal is suppressed. (EC-CMC-B.4, CR-CMC-21)

---

## Implementation Notes

*Derived from ADR-0004, ADR-0003 Implementation Guidelines + GDD §C.10 (replay suppression pseudocode):*

**`_try_fire_card` pseudocode** (GDD §C.10 — implement this exactly):

```gdscript
func _try_fire_card(scene_id: StringName, card_type: CardType,
        reason: LevelStreamingService.TransitionReason) -> void:
    # CR-CMC-17 — one-active invariant (first check)
    if InputContext.is_active(InputContext.Context.CUTSCENE):
        push_warning("[Cutscenes] drop: %s — context already CUTSCENE at dispatch time" % scene_id)
        return

    # CR-CMC-4 — unconditional suppress on non-FORWARD (second check — short-circuits before dict lookup)
    if reason in [LevelStreamingService.TransitionReason.RESPAWN,
                   LevelStreamingService.TransitionReason.NEW_GAME,
                   LevelStreamingService.TransitionReason.LOAD_FROM_SAVE]:
        return

    # CR-CMC-2 — replay suppression (third check — reads live reference)
    var state := MissionLevelScripting.get_mission_state()
    if state == null or state.triggers_fired == null:
        push_warning("[Cutscenes] drop: %s — MissionState/triggers_fired null; suppressing" % scene_id)
        return
    if scene_id in state.triggers_fired:
        return  # already fired; suppress silently

    # All gates passed
    _open_card(scene_id, card_type)
```

**Clause ordering is the contract** (F.3): RESPAWN/NEW_GAME/LOAD_FROM_SAVE suppress BEFORE the `triggers_fired` dict lookup. AC-3 and AC-4 spy on `dict.has()` to verify short-circuit. A naive implementation that checks `triggers_fired` first and then checks `reason` would fail AC-3/AC-4 (extra dict call logged by spy).

**Null-guard on `get_mission_state()`** (EC-CMC-B.8): if MissionState is not yet initialized (pre-mission_started boot, corrupt save), suppress silently and log. Do not crash.

**Live-reference contract** (OQ-CMC-6 BLOCKING — MLS must satisfy this): `MissionLevelScripting.get_mission_state()` returns the live `MissionState` resource, never a `duplicate()`. EC-CMC-B.4's slot-contamination safety depends on this. If MLS returns a duplicate, slot 1's state would persist in Cutscenes' call even after slot 5 is loaded — this would be a silent replay-suppression bug that AC-10 catches.

**dismiss-gate timer** (F.4 — used in `_open_card`):

```gdscript
func _open_card(scene_id: StringName, card_type: CardType) -> void:
    InputContext.push(InputContext.Context.CUTSCENE)
    _context_pushed = true
    _current_scene_id = scene_id
    _dismiss_gate_active = true
    var gate_duration: float = _gate_duration_for(card_type)
    get_tree().create_timer(gate_duration, true).timeout.connect(
        func(): _dismiss_gate_active = false)
    # ...populate Labels via tr() per CR-CMC-15...
    _show_card(card_type)

func _gate_duration_for(card_type: CardType) -> float:
    match card_type:
        CardType.MISSION_BRIEFING: return 4.0
        CardType.MISSION_CLOSING: return 5.0
        CardType.OBJECTIVE_OPT_IN: return 3.0
        _: return 4.0
```

`process_always = true` second arg to `create_timer` is defensive against future `SceneTree.paused` states (VG-CMC-5 Advisory).

**F5 quicksave silent-drop** (TR-CMC-015): This is enforced at `SaveManager._unhandled_input`, NOT at Cutscenes. Cutscenes pushes `InputContext.CUTSCENE`; `SaveManager` checks `InputContext.is_active(CUTSCENE)` and returns before calling `quicksave()`. This is a Save/Load epic concern, but AC-CMC-2.4 in the GDD verifies the gate exists at `SaveManager`. Cutscenes' role is only to have `InputContext.CUTSCENE` on the stack. Verify via code-review grep: `tools/ci/check_save_input_gate.sh` confirms the gate exists in `SaveManager._unhandled_input`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: `_open_card` visual rendering (labels, PPS sepia-dim, hard-cut entry, dismiss-to-gameplay flow)
- Story 005: CI forbidden-pattern shell script (`check_forbidden_patterns_cutscenes.sh`) that verifies no Mission-domain emit in Cutscenes source
- MLS epic story: `triggers_fired` write on `cutscene_ended` receipt (TR-CMC-008 MLS side)
- Save/Load epic: `SaveManager._unhandled_input` F5 gate enforcement (TR-CMC-015 enforcement site)
- Objective opt-in card handling (deferred post-VS per epic VS-narrowing; `_try_fire_card` plumbing lands here but no objective card visual content)

---

## QA Test Cases

*Solo mode — test cases derived from GDD ACs and ADR rules.*

**AC-1: First-arrival forward fires card**
- Given: `MissionState.triggers_fired = []`; `InputContext.current() == GAMEPLAY`; `reason = FORWARD`
- When: `_try_fire_card(&"mc_briefing_paris_affair", MISSION_BRIEFING, FORWARD)` called
- Then: `_open_card` spy records 1 call; `InputContext.is_active(CUTSCENE) == true`
- Edge cases: `triggers_fired` with 1 entry (different scene_id) — should still fire; `triggers_fired` null — suppresses with push_warning (null-guard)

**AC-2: Already-fired suppresses**
- Given: `triggers_fired = [&"mc_briefing_paris_affair"]`; `reason = FORWARD`
- When: `_try_fire_card(&"mc_briefing_paris_affair", MISSION_BRIEFING, FORWARD)` called
- Then: `_open_card` spy records 0 calls; `InputContext.is_active(CUTSCENE) == false`
- Edge cases: `triggers_fired` with 19 entries (all different) — card for 20th scene_id fires correctly (near-max-size array)

**AC-3: RESPAWN short-circuits before dict lookup**
- Given: `triggers_fired = []`; `reason = RESPAWN`
- When: `_try_fire_card(&"ct_03_kitchen_egress", CINEMATIC, RESPAWN)` called
- Then: spy on `triggers_fired.has()` records 0 calls; `_open_card` 0 calls
- Edge cases: `reason = NEW_GAME` and `reason = LOAD_FROM_SAVE` both short-circuit identically (AC-4)

**AC-6: One-active invariant drops second trigger with debug warning**
- Given: `InputContext.CUTSCENE` on stack (from first card); `_context_pushed == true`
- When: `Events.mission_completed.emit(...)` arrives at `_on_mission_completed`
- Then: `push_warning` called with string containing `"drop"` and `scene_id`; `_open_card` spy records 0 additional calls
- Edge cases: same-frame collision logs exactly one drop message per dropped trigger

**AC-10: EC-CMC-B.4 — no slot contamination on load**
- Given: Slot 1 `MissionState.triggers_fired = []` (no cards fired); `_context_pushed == false`
- When: Slot 5 loaded — `MissionLevelScripting.get_mission_state()` now returns slot 5 state with `triggers_fired = [&"mc_briefing_paris_affair"]`
- When: `Events.game_loaded.emit()` fires; then `Events.mission_started.emit(...)` fires
- Then: `_open_card` spy records 0 calls (briefing card suppressed by slot 5's `triggers_fired`); `InputContext.is_active(CUTSCENE) == false`
- Edge cases: `get_mission_state()` must return live reference (not cached); if it returned a duplicate, slot 1's empty `triggers_fired` would persist — test would catch this as a false-positive fire

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/presentation/cutscenes_and_mission_cards/replay_suppression_test.gd` — must exist and pass (AC-1, AC-2, AC-3, AC-4)
- `tests/unit/presentation/cutscenes_and_mission_cards/one_active_invariant_test.gd` — must exist and pass (AC-6, AC-7, AC-8, AC-9)
- `tests/integration/presentation/cutscenes_and_mission_cards/slot_contamination_ec_b4_test.gd` — must exist and pass (AC-5, AC-10 — EC-CMC-B.4 BLOCKING for VS DOD)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (scene scaffold DONE — `_try_fire_card` is a method on `CutscenesAndMissionCards`); Story 002 (signal domain DONE — `game_loaded` subscription wired)
- BLOCKED on: OQ-CMC-1 (`InputContext.Context.CUTSCENE` enum value) for AC-6 and AC-9; OQ-CMC-6 (MLS `get_mission_state()` live-reference contract) for AC-10 full verification in integration context
- EC-CMC-B.4 test (AC-10) is BLOCKING for VS DOD — must pass before epic can be closed
- Unlocks: Story 004 (card visuals — `_open_card` stub needed before rendering can land on top); Story 005 (CI fences — replay suppression logic must be established first)
