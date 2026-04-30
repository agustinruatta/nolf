# Story 005: F.5 thresholds + combined score + state escalation/de-escalation

> **Epic**: Stealth AI
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 3-4 hours (L — transition matrix test, 19-edge reversibility matrix, combined score)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/stealth-ai.md`
**Requirement**: `TR-SAI-002`, `TR-SAI-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy)
**ADR Decision Summary**: All `alert_state_changed`, `actor_became_alerted`, and `actor_lost_target` emissions go through `Events` autoload — never node-to-node. Enum types (`AlertState`, `AlertCause`, `Severity`) live on `StealthAI`. Propagation (`actor_became_alerted`) is suppressed when `cause == ALERTED_BY_OTHER` — the one-hop invariant (F.4, deferred post-VS). Severity is derived by `_compute_severity()` per Story 002 — callers never pass hardcoded severity.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: State-machine logic is pure GDScript — no post-cutoff engine APIs involved. Signal `emit()` is synchronous depth-first in GDScript. `current_alert_state` mutation must happen BEFORE any signal emits (no `call_deferred` on state mutation — AC-SAI-1.11 synchronicity guarantee).

**Control Manifest Rules (Feature/Foundation)**:
- Required (ADR-0002): signals fire through `Events`, not direct node connections
- Required (ADR-0002): `is_instance_valid(node)` checked before dereferencing any Node-typed signal payload by subscribers
- Forbidden: `call_deferred` for `current_alert_state` mutation — synchronous mutation is the contract
- Guardrail: combined score formula is `max(_sight, _sound) + 0.5 × min(_sight, _sound)` — do NOT store `combined` as a field; compute it derived per-frame

---

## Acceptance Criteria

*From GDD §Formulas §F.5 + §Detailed Rules (State escalation/de-escalation rules) + §States and Transitions + TR-SAI-011:*

- [ ] **AC-1** (AC-SAI-1.1): GIVEN a guard in UNAWARE with `_sight_accumulator = 0.35` (above `T_SUSPICIOUS = 0.3`, `combined = 0.35`), WHEN escalation is evaluated in a single physics frame, THEN `alert_state_changed(guard, UNAWARE, SUSPICIOUS, MINOR)` emits exactly once AND `actor_became_alerted(guard, SAW_PLAYER, stimulus_position, MINOR)` emits exactly once, in that order.
- [ ] **AC-2** (AC-SAI-1.2): GIVEN a guard in SUSPICIOUS, WHEN `combined < T_DECAY_UNAWARE (0.1)` for `SUSPICION_TIMEOUT_SEC (4.0 s)`, THEN guard transitions to UNAWARE AND emits `alert_state_changed(guard, SUSPICIOUS, UNAWARE, MINOR)` + `actor_lost_target(guard, MINOR)`.
- [ ] **AC-3** (AC-SAI-1.3 — 19-edge reversibility matrix): Parametrized test covering all legal directed edges from the transition table. For VS scope, the live-to-live edges tested are: (UNAWARE→SUSPICIOUS), (UNAWARE→SEARCHING), (UNAWARE→COMBAT), (SUSPICIOUS→SEARCHING), (SUSPICIOUS→UNAWARE), (SUSPICIOUS→COMBAT), (SEARCHING→SUSPICIOUS), (SEARCHING→COMBAT), (COMBAT→SEARCHING). Forbidden paths verified: (COMBAT→UNAWARE direct), (COMBAT→SUSPICIOUS direct), (SEARCHING→UNAWARE direct). Note: terminal-state edges (→UNCONSCIOUS, →DEAD, UNCONSCIOUS→SUSPICIOUS wake-up) are declared in the test matrix but marked as post-VS pending (Story 006/010 scope).
- [ ] **AC-4** (AC-SAI-2.7 — combined score): Parametrized over 5 ordered pairs:
  - `(0.25, 0.25)` → combined = 0.375 → crosses T_SUSPICIOUS, transitions UNAWARE → SUSPICIOUS
  - `(0.3, 0.0)` → combined = 0.3 → AT threshold → transitions (threshold is `>=`)
  - `(0.0, 0.3)` → combined = 0.3 → AT threshold → transitions
  - `(0.15, 0.3)` → combined = 0.3 + 0.5×0.15 = 0.375 → crosses T_SUSPICIOUS
  - `(0.6, 0.0)` → combined = 0.6 → AT T_SEARCHING threshold → transitions to SEARCHING
  Formula verified: `combined = max(_sight, _sound) + 0.5 × min(_sight, _sound)`.
- [ ] **AC-5**: AlertCause tie-break rule: if `_sight >= _sound`, cause derives from the last sight stimulus (`SAW_PLAYER`); if `_sound > _sight`, cause derives from the last sound stimulus (`HEARD_NOISE`). Unit test: set `_sight = 0.4`, `_sound = 0.2` → escalation uses `SAW_PLAYER` cause. Set `_sight = 0.2`, `_sound = 0.4` → escalation uses `HEARD_NOISE` cause.
- [ ] **AC-6**: `force_alert_state(new_state: StealthAI.AlertState, cause: StealthAI.AlertCause) -> bool` (AC-SAI-3.5): escalation allowed (new_state > current via lattice order), de-escalation rejected (returns false, no signal). `force_alert_state(DEAD, _)` and `force_alert_state(UNCONSCIOUS, _)` always return false — terminal states reachable only via takedown/damage. `force_alert_state(SEARCHING, SCRIPTED)` on UNAWARE guard transitions and emits `actor_became_alerted(_, SCRIPTED, guard.global_position, MAJOR)`. Propagation is NOT fired for `cause == SCRIPTED`.
- [ ] **AC-7**: F.5 thresholds are `@export var` with defaults and safe-range `@export_range` annotations, never hardcoded in logic:
  - `T_SUSPICIOUS: float = 0.3` (safe [0.2, 0.4])
  - `T_SEARCHING: float = 0.6` (safe [0.5, 0.75])
  - `T_COMBAT: float = 0.95` (safe [0.9, 1.0])
  - `T_DECAY_UNAWARE: float = 0.1` (safe [0.05, 0.2])
  - `T_DECAY_SEARCHING: float = 0.35` (safe [0.25, 0.45])
- [ ] **AC-8** (AC-SAI-1.11 — synchronicity): `current_alert_state` is mutated synchronously BEFORE any signal fires. Unit test: pre-connect a one-shot lambda to `Events.actor_became_alerted` BEFORE calling the escalation logic; lambda captures `guard.current_alert_state` at handler invocation time; assert it equals the expected post-mutation state (SUSPICIOUS after UNAWARE→SUSPICIOUS transition). Lambda observed `guard.current_alert_state == SUSPICIOUS` at signal-handler time, not UNAWARE.

---

## Implementation Notes

*Derived from GDD §Detailed Rules (Channel combination score, State escalation rule, State de-escalation rule) + GDD §States and Transitions:*

Combined score computation (derived value, not stored):
```gdscript
func _compute_combined() -> float:
    return max(_sight_accumulator, _sound_accumulator) + 0.5 * min(_sight_accumulator, _sound_accumulator)
```

Escalation evaluation (called each physics frame after accumulator updates):
```gdscript
func _evaluate_transitions() -> void:
    var combined := _compute_combined()
    match current_alert_state:
        StealthAI.AlertState.UNAWARE:
            if combined >= T_COMBAT:
                _transition_to(StealthAI.AlertState.COMBAT)
            elif combined >= T_SEARCHING:
                _transition_to(StealthAI.AlertState.SEARCHING)
            elif combined >= T_SUSPICIOUS:
                _transition_to(StealthAI.AlertState.SUSPICIOUS)
        StealthAI.AlertState.SUSPICIOUS:
            if combined >= T_COMBAT:
                _transition_to(StealthAI.AlertState.COMBAT)
            elif combined >= T_SEARCHING:
                _transition_to(StealthAI.AlertState.SEARCHING)
            # de-escalation handled by timeout in _evaluate_de_escalation()
        StealthAI.AlertState.SEARCHING:
            if combined >= T_COMBAT:
                _transition_to(StealthAI.AlertState.COMBAT)
            # de-escalation: SEARCHING → SUSPICIOUS handled by SEARCH_TIMEOUT_SEC timer
        StealthAI.AlertState.COMBAT:
            # de-escalation: COMBAT → SEARCHING handled by COMBAT_LOST_TARGET_SEC timer (Story 007)
```

`_transition_to(new_state)` must mutate `current_alert_state` FIRST, then emit signals:
```gdscript
func _transition_to(new_state: StealthAI.AlertState) -> void:
    var prev_state := current_alert_state
    current_alert_state = new_state  # mutation BEFORE any emit
    var cause := _determine_cause()
    var severity := StealthAI._compute_severity(new_state, cause)
    Events.alert_state_changed.emit(self, prev_state, new_state, severity)
    if cause != StealthAI.AlertCause.ALERTED_BY_OTHER:
        Events.actor_became_alerted.emit(self, cause, _last_stimulus_position, severity)
```

Timers (de-escalation) for VS: `SUSPICION_TIMEOUT_SEC = 4.0 s`, `SEARCH_TIMEOUT_SEC = 12.0 s`, `COMBAT_LOST_TARGET_SEC = 8.0 s`. These are `@export var` fields.

Lattice order for `force_alert_state` escalation-only check: UNAWARE(0) < SUSPICIOUS(1) < SEARCHING(2) < COMBAT(3). DEAD(4) and UNCONSCIOUS(5) are never forced via this method.

The SEARCHING → SUSPICIOUS de-escalation: on arrival at LKP + completed sweep + no new stimulus for `SEARCH_TIMEOUT_SEC`, both `_sight` and `_sound` are set to `T_DECAY_SEARCHING` (not zero) — the guard is still on-edge briefly. Emit `alert_state_changed(_, SEARCHING, SUSPICIOUS, MINOR)`.

No state-machine dwell floor (per GDD §Detailed Rules "No state-machine dwell floor"): comedy-mutter timing is owned by Dialogue & Subtitles via non-preemptive vocal scheduling. Do NOT add a dwell floor to the state machine.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: accumulator fill (the source of `_sight_accumulator` and `_sound_accumulator` values)
- Story 007: F.3 accumulator decay + de-escalation timer mechanics
- Story 006: patrol/investigation/combat behavior dispatched by state
- Post-VS (TR-SAI-010): F.4 alert propagation (`actor_became_alerted` triggering `_sound_accumulator` bumps on nearby guards)
- Post-VS: UNCONSCIOUS/DEAD state transitions (live-to-terminal edges) — no chloroform gadget or damage routing in VS
- Post-VS: `SAW_BODY` cause (no dead bodies in VS); `HEARD_GUNFIRE` cause; `CURIOSITY_BAIT` cause

---

## QA Test Cases

**AC-1 — UNAWARE to SUSPICIOUS transition**
- Given: guard in UNAWARE, `_sight_accumulator` injected to 0.35, `_sound_accumulator = 0.0`; `CountingRaycastProvider` injected
- When: `_evaluate_transitions()` is called
- Then: `current_alert_state == SUSPICIOUS`; `Events.alert_state_changed` emitted once with `(guard, UNAWARE, SUSPICIOUS, MINOR)`; `Events.actor_became_alerted` emitted once with `(guard, SAW_PLAYER, stimulus_pos, MINOR)`
- Edge cases: `_sight = 0.29` → no transition; `_sight = 0.30` → transition (AT threshold is `>=`)

**AC-3 — Reversibility matrix (legal live-to-live edges only)**
- Given: parametrized over 9 live-to-live edges; each row sets guard to source state and sets accumulators to trigger the target state
- When: `_evaluate_transitions()` runs
- Then: guard transitions to target state; correct signals emitted; no skipped states; no forbidden transitions fire
- Edge cases: COMBAT→UNAWARE direct attempt → no transition (no direct edge); assert `current_alert_state` unchanged

**AC-4 — Combined score formula**
- Given: `_sight_accumulator` and `_sound_accumulator` set to each of 5 (sight, sound) pairs
- When: `_compute_combined()` called
- Then: result matches `max + 0.5 × min` within 0.001 tolerance; threshold comparison correctly gates transitions
- Edge cases: both 1.0 → combined = 1.5 (intentional over-1.0 ceiling for decisive cross-channel confirmation); both 0.0 → combined = 0.0

**AC-8 — Synchronicity guarantee (pre-connected lambda)**
- Given: one-shot lambda connected to `Events.alert_state_changed` BEFORE the escalation call
- When: escalation logic fires the UNAWARE→SUSPICIOUS transition
- Then: lambda observes `guard.current_alert_state == SUSPICIOUS` (post-mutation) at handler invocation time, NOT UNAWARE; confirms `call_deferred` was NOT used
- Edge cases: lambda connected AFTER the call → lambda fires in next frame (wrong); test must use BEFORE pattern exclusively

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/feature/stealth_ai/stealth_ai_unaware_to_suspicious_test.gd` — AC-SAI-1.1
- `tests/unit/feature/stealth_ai/stealth_ai_suspicious_to_unaware_test.gd` — AC-SAI-1.2
- `tests/unit/feature/stealth_ai/stealth_ai_reversibility_matrix_test.gd` — AC-SAI-1.3 (VS subset)
- `tests/unit/feature/stealth_ai/stealth_ai_combined_score_test.gd` — AC-SAI-2.7
- `tests/unit/feature/stealth_ai/stealth_ai_force_alert_state_test.gd` — AC-SAI-3.5
- `tests/unit/feature/stealth_ai/stealth_ai_receive_damage_synchronicity_test.gd` — AC-SAI-1.11 (synchronicity only; damage routing deferred post-VS)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 DONE (enums + signals), Story 004 DONE (accumulators populated by F.1)
- Unlocks: Story 006 (state determines patrol/investigate/combat behavior), Story 007 (de-escalation timers share state machine context), Story 008 (signal consumer wires here)
