# Story 007: F.3 accumulator decay + de-escalation timers

> **Epic**: Stealth AI
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2-3 hours (M — decay table, timer tests, Pillar 3 reversibility)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/stealth-ai.md`
**Requirement**: `TR-SAI-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy)
**ADR Decision Summary**: De-escalation signals (`alert_state_changed`, `actor_lost_target`) emit through `Events` autoload. Severity for de-escalation transitions is computed by `StealthAI._compute_severity()` — SUSPICIOUS→UNAWARE is MINOR (no brass-punch stinger, preserving Pillar 1 comedy). SEARCHING→SUSPICIOUS is MINOR. COMBAT→SEARCHING is MAJOR.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Decay is pure per-frame arithmetic — no post-cutoff engine APIs. `Δt_clamped = min(delta, 1.0/30.0)` hitch guard applies to decay as well as fill. Timers (SUSPICION_TIMEOUT_SEC etc.) are implemented as float countdown fields decremented by `delta` each physics frame — NOT Godot `Timer` nodes, which would require deferred signals and complicate the synchronous state machine.

**Control Manifest Rules (Feature/Foundation)**:
- Required: decay rates are `@export var` — data-driven, never hardcoded in logic
- Guardrail: accumulators must never go below `0.0` (floored by max with 0); never exceed `1.0` (clamped on fill, Story 004/005)
- Note: no Feature-layer rules in the manifest yet; Foundation rules apply globally

---

## Acceptance Criteria

*From GDD §Formulas §F.3 + §Detailed Rules (State de-escalation rule, COMBAT recovery pacing spec) + TR-SAI-009:*

- [ ] **AC-1** (AC-SAI-2.4): F.3 decay parametrized over 4 states. For each state `s ∈ {UNAWARE, SUSPICIOUS, SEARCHING, COMBAT}`, starting at `_sight_accumulator = 1.0` with no stimulus, after 1 simulated second (60 physics ticks at delta=1/60): assert `_sight_accumulator ≈ 1.0 - SIGHT_DECAY[s] × 1.0` within 0.01 tolerance. Decay rate table:
  - UNAWARE: SIGHT_DECAY=0.5, SOUND_DECAY=0.4
  - SUSPICIOUS: SIGHT_DECAY=0.3, SOUND_DECAY=0.25
  - SEARCHING: SIGHT_DECAY=0.15, SOUND_DECAY=0.12
  - COMBAT: SIGHT_DECAY=0.05, SOUND_DECAY=0.05
  Additionally assert accumulator never goes negative across 10 simulated seconds of decay-only input.
- [ ] **AC-2** (AC-SAI-1.2): GIVEN guard in SUSPICIOUS with both accumulators below `T_DECAY_UNAWARE (0.1)`, WHEN `SUSPICION_TIMEOUT_SEC (4.0 s)` elapses with no new stimulus, THEN guard transitions to UNAWARE, emits `alert_state_changed(guard, SUSPICIOUS, UNAWARE, MINOR)` + `actor_lost_target(guard, MINOR)`. Patrol resumes from nearest patrol node.
- [ ] **AC-3**: GIVEN guard in SEARCHING that has arrived at LKP and completed sweep with no new stimulus, WHEN `SEARCH_TIMEOUT_SEC (12.0 s)` elapses, THEN both `_sight` and `_sound` are set to `T_DECAY_SEARCHING (0.35)` (not zero), guard transitions to SUSPICIOUS, emits `alert_state_changed(guard, SEARCHING, SUSPICIOUS, MINOR)`. Guard remains edgy (accumulators at 0.35, not 0) for the SUSPICIOUS phase.
- [ ] **AC-4** (AC-SAI-1.6): GIVEN guard in COMBAT with `_sight = 0.9`, WHEN sight is removed (Eve hidden — LOS breaks, no new fill) AND no damage taken for `COMBAT_LOST_TARGET_SEC (8.0 s)`, THEN guard transitions to SEARCHING, `_sight` is set to `T_SEARCHING - 0.01 (= 0.59)`, emits `alert_state_changed(guard, COMBAT, SEARCHING, MAJOR)` + `actor_lost_target(guard, MAJOR)`. COMBAT → UNAWARE direct transition does NOT exist — must verify guard reaches SEARCHING, not UNAWARE.
- [ ] **AC-5** (Pillar 3 reversibility — AC-SAI-4.2): Integration test. Guard escalates to SUSPICIOUS from sight fill, then Eve hides behind an occluder (LOS breaks). After 10 simulated seconds with no sight or sound, guard returns to UNAWARE. No accumulated state persists after the timeout. `current_alert_state == UNAWARE` and `patrol` behavior resumes.
- [ ] **AC-6**: Decay applies each physics frame regardless of stimulus presence. Decay uses `Δt_clamped = min(delta, 1.0/30.0)` — the hitch guard prevents runaway decay during frame spikes. Assert: at `delta = 1.0 / 30.0` (maximum clamped frame), 10 seconds of decay does not overshoot — accumulator reaches `0.0` cleanly and does not produce negative values.
- [ ] **AC-7**: De-escalation timer resets correctly when a new stimulus arrives during the countdown. GIVEN guard in SUSPICIOUS with timeout at T-minus 2 s (2 s remaining), WHEN new sight fill arrives (accumulator bumped above `T_SUSPICIOUS`), THEN the timeout is cancelled (guard escalates instead of de-escalating). Timer does NOT fire de-escalation if the guard has already escalated to SEARCHING or COMBAT before the timeout completes.

---

## Implementation Notes

*Derived from GDD §F.3 + §Detailed Rules:*

Decay implementation (per physics frame, before accumulator is used for escalation eval):
```gdscript
var delta_clamped := minf(delta, 1.0 / 30.0)
if not _sight_refreshed_this_frame:
    _sight_accumulator = maxf(0.0, _sight_accumulator - SIGHT_DECAY[current_alert_state] * delta_clamped)
if not _sound_refreshed_this_poll:
    _sound_accumulator = maxf(0.0, _sound_accumulator - SOUND_DECAY[current_alert_state] * delta_clamped)
```

`_sight_refreshed_this_frame` and `_sound_refreshed_this_poll` are boolean flags set to `true` when F.1 or F.2 updates the accumulator in the current frame/poll, and reset to `false` at the start of the next frame/poll respectively.

De-escalation timers are float countdown fields, not `Timer` nodes:
```gdscript
var _suspicion_timeout_remaining: float = 0.0
var _search_timeout_remaining: float = 0.0
var _combat_lost_target_remaining: float = 0.0
```

Timer logic in `_physics_process`:
- SUSPICIOUS state: decrement `_suspicion_timeout_remaining` by `delta`. Reset to `SUSPICION_TIMEOUT_SEC` whenever combined rises above `T_DECAY_UNAWARE`. When `_suspicion_timeout_remaining <= 0` AND `combined < T_DECAY_UNAWARE`: de-escalate to UNAWARE.
- SEARCHING state: managed separately; timer resets on new stimulus during sweep (GDD E.4).
- COMBAT state: `_combat_lost_target_remaining` tracks no-sight-no-damage window. Reset when sight confirms or damage taken. On expiry: de-escalate to SEARCHING.

Serialised fields (for save/load, Story 010 scope): `search_timeout_remaining` and `combat_lost_target_remaining` are included in the live guard save schema per GDD §Death and save-state.

COMBAT recovery pacing: the GDD §COMBAT → UNAWARE recovery pacing spec specifies vocal and music beats. This story implements the mechanical timer only. Dialogue/Audio beats are Dialogue & Subtitles forward dep — placeholder in VS (Pillar 1 comedy is authored later).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: accumulator fill (the source values that decay reduces)
- Story 005: escalation thresholds (the upward transitions that counteract decay)
- Story 006: state-driven movement behavior (what the guard does while in each state)
- Post-VS (TR-SAI-008): F.3 decay interaction with `_sound_accumulator` filled by F.2 (sound fill deferred)
- Post-VS: save/load serialisation of `search_timeout_remaining` and `combat_lost_target_remaining` — struct fields are declared here but serialisation wiring is deferred to save/load integration story
- Post-VS: COMBAT recovery pacing vocal beats (Dialogue & Subtitles forward dep)

---

## QA Test Cases

**AC-1 — F.3 decay rate table (AC-SAI-2.4)**
- Given: guard in each state `s`; `_sight_accumulator = 1.0`; no stimulus for 60 physics ticks (1 s)
- When: 60 ticks of `_physics_process(1.0/60.0)` run
- Then: `_sight_accumulator ≈ 1.0 - SIGHT_DECAY[s]` within 0.01; accumulator is `>= 0.0`
- Edge cases: state changes mid-decay → decay rate switches to new state's rate; hitch frame (delta > 1/60) → clamped at 1/30

**AC-2 — SUSPICIOUS → UNAWARE timeout**
- Given: guard in SUSPICIOUS; `_sight_accumulator = 0.05`, `_sound_accumulator = 0.05` (both below `T_DECAY_UNAWARE = 0.1`)
- When: 4.1 simulated seconds elapse with no new stimulus
- Then: `current_alert_state == UNAWARE`; `alert_state_changed(_, SUSPICIOUS, UNAWARE, MINOR)` emitted once; `actor_lost_target(_, MINOR)` emitted once
- Edge cases: stimulus arrives at T-minus 0.5 s → timer cancelled, guard stays SUSPICIOUS or escalates

**AC-4 — COMBAT → SEARCHING (AC-SAI-1.6)**
- Given: guard in COMBAT, `_sight_accumulator = 0.9`; sight blocked (F.1 returns 0 fill); no damage
- When: 8.01 simulated seconds elapse
- Then: `current_alert_state == SEARCHING`; `_sight_accumulator == T_SEARCHING - 0.01 (0.59)`; `alert_state_changed(_, COMBAT, SEARCHING, MAJOR)` + `actor_lost_target(_, MAJOR)` emitted
- Edge cases: damage taken at T-minus 1 s → timer resets (guard stays COMBAT); COMBAT→UNAWARE direct → assert does NOT occur

**AC-5 — Pillar 3 reversibility integration**
- Given: a full perception loop (guard + Eve) where Eve then hides behind an occluder
- When: 10 simulated seconds with no sight and no sound
- Then: `current_alert_state == UNAWARE`; patrol behavior resumed; no persistent alert state
- Edge cases: accumulators not at zero when de-escalation fires → test asserts `< T_DECAY_UNAWARE` threshold satisfied, not exact zero

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/feature/stealth_ai/stealth_ai_decay_test.gd` — AC-SAI-2.4 (4-state decay table)
- `tests/unit/feature/stealth_ai/stealth_ai_combat_to_searching_test.gd` — AC-SAI-1.6
- `tests/integration/feature/stealth_ai/stealth_ai_pillar3_reversibility_test.gd` — AC-SAI-4.2

**Status**: [x] Complete — 25 new tests across 3 files; suite 607/607 PASS exit 0.

---

## Completion Notes

**Completed**: 2026-05-02
**Criteria**: 7/7 PASSING

**Test Evidence**:
- `tests/unit/feature/stealth_ai/stealth_ai_decay_test.gd` (NEW) — AC-1 + AC-6 + AC-7 decay rate table verification (4 states × sight + sound; never-negative invariant; hitch-clamp test; timer reset on stimulus)
- `tests/unit/feature/stealth_ai/stealth_ai_combat_to_searching_test.gd` (NEW) — AC-4 COMBAT → SEARCHING via combat_lost_target_sec timer; sight reset to t_searching - 0.01 (0.59); alert_state_changed + actor_lost_target signals; verifies COMBAT → UNAWARE direct never occurs
- `tests/integration/feature/stealth_ai/stealth_ai_pillar3_reversibility_test.gd` (NEW) — AC-5 full reversibility loop (escalate → hide → no-stimulus decay + timer ticks → return to UNAWARE)
- Suite: **607/607 PASS** exit 0 (baseline 582 + 25 new SAI-007 tests; zero errors / failures / flaky / orphans / skipped)

**Files Modified / Created**:
- `src/gameplay/stealth/perception.gd` (modified) — added 8 decay rate exports (sight + sound × 4 states); added `_sight_refreshed_this_frame` / `_sound_refreshed_this_poll` flags; added `apply_decay(current_alert_state, delta)` public method with delta-clamp + max(0.0) floor; added `_sight_decay_for_state()` / `_sound_decay_for_state()` private lookups; modified `process_sight_fill` to set `_sight_refreshed_this_frame = true` when actual fill occurred (rate > 0)
- `src/gameplay/stealth/guard.gd` (modified) — added 3 timer-remaining fields (_suspicion_timeout_remaining, _search_timeout_remaining, _combat_lost_target_remaining); added `tick_de_escalation_timers(delta)` public method handling SUSPICIOUS/SEARCHING/COMBAT countdown logic; added `_initialize_timer_for_state(new_state)` private helper called from both `_transition_to` and `_de_escalate_to` after state mutation; AC-3 sets accumulators to t_decay_searching (0.35) before SEARCHING → SUSPICIOUS de-escalation; AC-4 sets sight to t_searching - 0.01 (0.59) before COMBAT → SEARCHING de-escalation
- 3 new test files (25 tests total)

**Code Review**: Self-reviewed inline (decay arithmetic verified via 4-state table; timer reset semantics verified via stimulus-cancellation tests; Pillar 3 reversibility verified via full simulation loop)

**Deviations Logged**:
- **F.2 sound fill remains post-VS**. Sound accumulator decay tested by manually seeding `sound_accumulator` (no F.2 fill source in VS).
- **Save/load timer serialisation deferred**. Timer fields are declared on Guard but not serialised in SaveGame yet — follows Out of Scope §post-VS save/load integration.
- **COMBAT recovery pacing vocal beats**: Dialogue & Subtitles forward dep; placeholder only. Mechanical timer + state transition fully verified.

**Tech Debt Logged**: None.

**Unlocks**: Story 008 (full reversibility loop is now in place — Audio stinger subscriber can test the full escalate-de-escalate cycle), Story 010 (perf harness has full decay + timer + transition loop to measure)

---

## Dependencies

- Depends on: Story 004 DONE (accumulator fill sets the starting values decay reduces), Story 005 DONE (state determines which decay rate applies)
- Unlocks: Story 008 (full reversibility loop needed for Audio integration test), Story 010 (performance test runs full perception + decay loop)
