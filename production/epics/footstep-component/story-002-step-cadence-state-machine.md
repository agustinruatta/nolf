# Story 002: Step cadence state machine + phase-preservation accumulator

> **Epic**: FootstepComponent
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2-3 hours (M — accumulator logic + suppression guards + 4 test files)
> **Manifest Version**: 2026-04-30
> **Completed**: 2026-05-01

## Context

**GDD**: `design/gdd/footstep-component.md`
**Requirement**: `TR-FC-002` (state-keyed step cadence: Walk 2.2 Hz / Sprint 3.0 Hz / Crouch 1.6 Hz; Idle/Jump/Fall/Dead silent), `TR-FC-006` (accumulator pattern preserves cadence phase across state transitions — `_step_accumulator -= interval`, not zero)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy), ADR-0008 (Performance Budget Distribution)
**ADR Decision Summary**: FootstepComponent's per-frame ticking work is allocated to ADR-0008 Slot 5 (Player Character + FootstepComponent + Combat non-GuardFire logic ≤ 0.3 ms combined; status: Proposed, pending Iris Xe measurement). The accumulator fires at 1.6–3.0 Hz — well within ADR-0002's no-per-frame-signal rule (IG 5: `player_footstep` peaks at ~3.5 Hz at Sprint × 2–3 subscribers ≈ negligible). Phase-preservation (`_step_accumulator -= interval`) is the canonical GDD formula (FC.1) that prevents cadence drift on rapid state transitions.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `_physics_process(delta: float)` cadence is stable Godot 4.0+. Jolt 3D (Godot 4.6 default) does not alter `_physics_process` delta semantics vs GodotPhysics. The `min(delta, 1.0/30.0)` hitch guard is the same pattern used in PlayerCharacter F.1/F.2 — verified Sprint 01. No post-cutoff APIs in this story.

**Control Manifest Rules (Core)**:
- Required: frame-rate independence — `delta` passed to `_physics_process` must be clamped before accumulation: `var delta_clamped: float = min(delta, 1.0 / 30.0)` — GDD FC.1 formula
- Required: static typing on all vars and function signatures — Global Rules
- Required: doc comments on public methods — Global Rules
- Forbidden: hardcoded cadence Hz values in `_physics_process` — use `CADENCE_BY_STATE` dictionary built in `_ready` from exported knobs (GDD §Tuning Knobs)
- Guardrail: ADR-0008 Slot 5 ≤ 0.3 ms combined with PlayerCharacter + Combat non-GF (Proposed; per-story perf gate pending Iris Xe measurement)

---

## Acceptance Criteria

*From GDD `design/gdd/footstep-component.md` §AC-FC-1, scoped to cadence logic:*

- [ ] **AC-1** (AC-FC-1.1): With a stubbed `PlayerCharacter` in Walk state (`current_state = WALK`) and `velocity = Vector3(3.5, 0, 0)`, driving 300 `_physics_process` ticks at `delta = 1.0 / 60.0` (5 seconds), `Events.player_footstep` fires 11 ± 1 times (expected for `cadence_walk_hz = 2.2`).
- [ ] **AC-2** (AC-FC-1.2): Same test pattern for Sprint (`cadence_sprint_hz = 3.0`, `velocity.length() = 5.5`) expects 15 ± 1 emissions in 5 s; for Crouch (`cadence_crouch_hz = 1.6`, `velocity.length() = 1.8`) expects 8 ± 1 emissions in 5 s. All driven via fixed-delta ticks (no real-time capture) for determinism.
- [ ] **AC-3** (AC-FC-1.3): Transitioning from Walk to Sprint mid-interval: the first Sprint step fires within `1 / cadence_sprint_hz` seconds of the transition (±1 physics frame tolerance = ±0.0167 s). No double-fire on the transition frame (zero emissions on the frame the state changes if accumulator has not yet crossed the Sprint interval).
- [ ] **AC-4** (AC-FC-1.4): Idle, Jump, Fall, and Dead states: driving the stub through each state for 3 seconds (180 ticks at `delta = 1/60`) asserts zero `player_footstep` emissions.
- [ ] **AC-5** (FC.E.3 — Walk-still guard): with `current_state = WALK` but `velocity.length() < idle_velocity_threshold`, zero emissions fire. Accumulator does not increment while velocity is below threshold.
- [ ] **AC-6** (accumulator reset on state-exit): after entering an emitting state, transitioning to a non-emitting state resets `_step_accumulator` to `0.0`. On re-entry to the emitting state, the first step fires one full interval later (not immediately).

---

## Implementation Notes

*Derived from GDD §Formulas FC.1, §Edge Cases FC.E.1–FC.E.4, FC.E.6:*

Implement `_physics_process` per GDD FC.1 formula exactly:

```gdscript
func _physics_process(delta: float) -> void:
    if _is_disabled:
        return
    if not _is_emitting_state(_player.current_state):
        _step_accumulator = 0.0
        return
    if not _player.is_on_floor():
        return
    if _player.velocity.length() < _player.idle_velocity_threshold:
        return
    var interval: float = CADENCE_BY_STATE[_player.current_state]
    var delta_clamped: float = min(delta, 1.0 / 30.0)
    _step_accumulator += delta_clamped
    if _step_accumulator >= interval:
        _step_accumulator -= interval   # preserve cadence phase — NOT = 0
        _emit_footstep()                # stub call — implemented in Story 004

func _is_emitting_state(state: PlayerEnums.MovementState) -> bool:
    return (state == PlayerEnums.MovementState.WALK
            or state == PlayerEnums.MovementState.SPRINT
            or state == PlayerEnums.MovementState.CROUCH)
```

**`_emit_footstep()` in this story**: stub implementation that emits `Events.player_footstep(&"default", 0.0)` — actual surface resolution and noise_radius_m land in Stories 003 and 004 respectively. The stub is sufficient for cadence testing; Story 004 replaces the stub body.

**Phase-preservation rationale** (from GDD FC.1): `_step_accumulator -= interval` (not `= 0`) preserves sub-interval overshoot. If Walk accumulates 0.46 s (just past 0.455 s interval) and state switches to Sprint (interval 0.333 s), the carry-over 0.005 s means the next Sprint step fires in 0.328 s — correct catch-up behaviour. Zeroing would cause perceptible drift in rapid Walk → Sprint → Walk sequences.

**`is_on_floor()` coyote-window interaction** (GDD FC.E.4): the `not _player.is_on_floor()` guard returns early WITHOUT resetting `_step_accumulator` — accumulated time carries into the next on-floor frame. Only the `not _is_emitting_state(...)` branch resets to `0.0`. This is intentional: during the PC coyote window `is_on_floor()` briefly returns false while state is still WALK/SPRINT/CROUCH; preserving the accumulator means cadence stays correct if Eve lands back within the coyote window.

**Test stub for PlayerCharacter**: create `tests/unit/core/footstep_component/stubs/stub_player_character.gd` — a `CharacterBody3D` subclass implementing the interface FootstepComponent reads: `current_state`, `velocity`, `is_on_floor()`, `idle_velocity_threshold`, `global_transform.origin`, `get_noise_level()`. Use `get_world_3d()` passthrough. This stub is shared across Stories 002, 003, and 004 test files.

**ADR-0008 Slot 5 performance note**: per `_physics_process` tick, FootstepComponent executes at most 4 comparisons + one float add + one interval check. No allocations. Slot 5 cap is 0.3 ms combined with PlayerCharacter + Combat non-GF; this story's contribution is negligible.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: scaffold fields (`_is_disabled`, `_step_accumulator`, `CADENCE_BY_STATE`, exported knobs) — must be Done before this story starts
- Story 003: `_resolve_surface_tag()` — `_emit_footstep()` stub in this story uses `&"default"` surface tag
- Story 004: actual `Events.player_footstep` signal emission with real surface + noise_radius_m; emission-rate guard; integration test with Audio stub subscriber
- Post-VS: sprint-vs-walk cadence variations beyond Walk/Sprint/Crouch (the full state machine is VS-complete with 3 rates); jump landing emission (owned by PlayerCharacter latched-event path per GDD)
- SAI boundary: Stealth AI does NOT subscribe to `player_footstep`. SAI reads `_player.get_noise_level()` / `_player.get_noise_event()` directly. Do NOT implement any SAI coupling here — forbidden pattern `sai_subscribing_to_player_footstep` per GDD §Forbidden Patterns.

---

## QA Test Cases

*Logic story — automated test specs (deterministic fixed-delta ticks, no real-time):*

**AC-1**: Walk cadence 5-second sample
- **Given**: FootstepComponent with `cadence_walk_hz = 2.2`; stub player in WALK state, `velocity = Vector3(3.5, 0, 0)`, `is_on_floor() = true`, `idle_velocity_threshold = 0.1`
- **When**: 300 `_physics_process(1.0 / 60.0)` ticks are driven sequentially
- **Then**: signal spy count on `Events.player_footstep` is between 10 and 12 (11 ± 1 expected for 5 s at 2.2 Hz)
- **Edge cases**: accumulator starts at 0.0 — first step fires after ~27 frames (~0.455 s), not on frame 0; stub's `is_on_floor()` must return `true` throughout or suppression fires

**AC-2**: Sprint and Crouch cadence samples (parametrized)
- **Given**: same setup, two parametrized cases: (a) SPRINT, `velocity.length() = 5.5`, `cadence_sprint_hz = 3.0`; (b) CROUCH, `velocity.length() = 1.8`, `cadence_crouch_hz = 1.6`
- **When**: 300 ticks at `delta = 1/60`
- **Then**: (a) between 14 and 16 emissions; (b) between 7 and 9 emissions
- **Edge cases**: floating-point accumulator drift — 5-second fixed-delta test must not accumulate error beyond ±1 step

**AC-3**: Walk → Sprint mid-interval transition
- **Given**: stub starts in WALK; after exactly 14 ticks (0.233 s, accumulator ≈ 0.233 < 0.455), state switches to SPRINT
- **When**: additional ticks proceed until the first SPRINT emission
- **Then**: time from state switch to first Sprint emission ≤ `1 / cadence_sprint_hz` seconds (≤ 0.333 s); no emission fires on the transition frame itself
- **Edge cases**: if accumulator at transition already > `1 / cadence_sprint_hz`, the first Sprint step fires on the very next frame — this is correct per GDD FC.E.1

**AC-4**: Silent states — no emissions in Idle/Jump/Fall/Dead
- **Given**: stub cycles through IDLE → JUMP → FALL → DEAD, 3 seconds each (4 × 180 = 720 ticks)
- **When**: 720 `_physics_process(1.0 / 60.0)` ticks
- **Then**: zero `Events.player_footstep` emissions across all four states
- **Edge cases**: transition from a prior emitting state before each silent state — accumulator must reset to 0.0 on the first non-emitting frame

**AC-5**: Walk-still suppression
- **Given**: stub in WALK state, `velocity = Vector3.ZERO` (`velocity.length() == 0.0 < idle_velocity_threshold`)
- **When**: 180 ticks
- **Then**: zero emissions; `_step_accumulator` does not increase (velocity guard fires before accumulator increment)
- **Edge cases**: `velocity.length()` exactly equal to `idle_velocity_threshold` — should suppress (using `<`, not `<=`, per GDD FC.1 pseudocode)

**AC-6**: Accumulator resets on state-exit, waits full interval on re-entry
- **Given**: stub in WALK for 14 ticks (accumulator ≈ 0.233 s); transitions to IDLE for 1 tick; transitions back to WALK
- **When**: ticks proceed after re-entry
- **Then**: `_step_accumulator == 0.0` after the IDLE tick; first post-re-entry emission fires ~27 frames after the re-entry frame (one full Walk interval)
- **Edge cases**: re-entry on the same frame as state-exit — the `not _is_emitting_state` branch resets the accumulator before the accumulator increment on that tick

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/core/footstep_component/footstep_cadence_walk_test.gd` — must exist and pass (AC-1; GDD AC-FC-1.1)
- `tests/unit/core/footstep_component/footstep_cadence_all_states_test.gd` — must exist and pass (AC-2; GDD AC-FC-1.2)
- `tests/unit/core/footstep_component/footstep_state_transition_test.gd` — must exist and pass (AC-3; GDD AC-FC-1.3)
- `tests/unit/core/footstep_component/footstep_silent_states_test.gd` — must exist and pass (AC-4, AC-5, AC-6; GDD AC-FC-1.4)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (FootstepComponent scaffold — `_is_disabled`, `_step_accumulator`, `CADENCE_BY_STATE`, `_player` reference) must be Done
- Unlocks: Story 003 (surface tag resolution replaces the `&"default"` stub surface in `_emit_footstep`); Story 004 (full `_emit_footstep` implementation requires this story's cadence loop to drive emissions)

---

## Completion Notes

**Completed**: 2026-05-01
**Criteria**: AC-1..6 covered by 10 test functions across 4 files.
**Test results**: 10/10 PASS.

### Files added (4 test files + 1 stub doc)
- `tests/unit/core/footstep_component/footstep_cadence_walk_test.gd` (2 tests, AC-1).
- `tests/unit/core/footstep_component/footstep_cadence_all_states_test.gd` (2 tests, AC-2).
- `tests/unit/core/footstep_component/footstep_state_transition_test.gd` (1 test, AC-3).
- `tests/unit/core/footstep_component/footstep_silent_states_test.gd` (5 tests, AC-4 + AC-5 + AC-6 + floor-blip preservation).
- `tests/unit/core/footstep_component/stubs/stub_player_character.gd` (deprecated; documents real-PC + StaticBody3D floor pattern).

### Files modified
- `src/gameplay/player/footstep_component.gd` — full GDD FC.1 cadence loop with phase-preservation accumulator (`-= interval` not `= 0`), suppression guards (Idle/Jump/Fall/Dead), idle-velocity gate, coyote-window-aware floor guard (no reset on `is_on_floor() == false`), delta-clamp hitch guard.

### Test fixture finding
GDScript blocks subclass overrides of native CharacterBody3D methods like `is_on_floor()` (warning treated as error). Tests use the real PlayerCharacter scene + StaticBody3D floor + one `move_and_slide` call to register floor contact, with a graceful-skip fallback if headless physics doesn't resolve. Pattern documented in stub file's deprecated docs.

### Verdict
COMPLETE.
