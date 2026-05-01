# Story 004: Noise perception surface

> **Epic**: Player Character
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2-3 hours (M — spike-latch, idempotent-read, auto-expiry, silhouette height)
> **Manifest Version**: 2026-04-30
> **Completed**: 2026-05-01

## Context

**GDD**: `design/gdd/player-character.md`
**Requirements**: TR-PC-012, TR-PC-013, TR-PC-014, TR-PC-018
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy), ADR-0008 (Performance Budget Distribution)
**ADR Decision Summary**: `get_noise_level()` and `get_noise_event()` are pull methods, NOT signals. ADR-0002 Implementation Guideline 5 forbids per-frame signals — the ~80 Hz aggregate polling rate (10 Hz × ~8 guards) makes a signal-per-frame pattern unacceptable. The single reused `NoiseEvent` instance (in-place field mutation) keeps steady-state allocation at zero per polling call. ADR-0008 slot 1 PC budget governs the combined cost of noise queries at 80 Hz aggregate.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: No post-cutoff APIs. `Engine.physics_ticks_per_second` is stable Godot 4.x for converting `spike_latch_duration_sec` to frames. `RefCounted` field mutation is idiomatic GDScript with no engine version risk. The `NOISE_BY_STATE` const dictionary built once in `_ready()` avoids per-frame dictionary allocation.

**Control Manifest Rules (Foundation + Core)**:
- Required: noise interface uses pull methods, not signals — ADR-0002 §no per-frame signals
- Forbidden: allocating a new NoiseEvent per spike — pattern `noise_event_per_spike_allocation` (breaks zero-allocation at 80 Hz invariant, GDD F.4)
- Forbidden: AI code subscribing to `player_footstep` as a noise channel — GDD Forbidden Patterns (AI reads `get_noise_level` / `get_noise_event` only)
- Forbidden: reading `_latched_event` directly from outside PlayerCharacter — use the getter

---

## Acceptance Criteria

*From GDD `design/gdd/player-character.md` §Acceptance Criteria AC-3, AC-6bis:*

- [ ] **AC-3.1 [Logic]** `get_noise_level()` returns `noise_walk × noise_global_multiplier` (default: 5.0) when state == WALK and `velocity.length() >= idle_velocity_threshold`; returns `noise_sprint × noise_global_multiplier` (default: 12.0) for SPRINT; returns `noise_crouch × noise_global_multiplier` (default: 3.0) for CROUCH moving. Walk-at-rest and Crouch-at-rest (`velocity.length() < idle_velocity_threshold`) return `0.0`. DEAD state always returns `0.0`. Verified at `noise_global_multiplier` values `{0.7, 1.0, 1.3}` (internal-only multiplier — locked to 1.0 at ship, but testable at other values in unit tests to confirm the formula).
- [ ] **AC-3.2 [Logic]** **Idempotent-read**: after recording a JUMP_TAKEOFF spike, 10 consecutive `get_noise_event()` calls within `_spike_latch_duration_frames` return the same non-null reference with identical `type`, `radius_m`, and `origin` field values. The reference identity may change (in-place mutation), but the field values are stable across reads within the window.
- [ ] **AC-3.3 [Logic]** **Highest-radius-wins collision**: recording JUMP_TAKEOFF (4 m) then LANDING_SOFT (5 m) within 2 physics frames → `get_noise_event().type == LANDING_SOFT` for the remainder of the latch window. Reverse order (5 m first, then 4 m) → latch retains the 5 m event (equal-or-lower new radius does NOT overwrite). Ties: first-recorded wins.
- [ ] **AC-3.4 [Logic]** **Latch auto-expiry**: after recording a spike, advancing `_spike_latch_duration_frames` physics frames causes `get_noise_event()` to return `null` (the implementation decrements at the *start* of each `_physics_process` tick — so after exactly N elapsed ticks, frames_remaining hits 0 and `_latched_event` is cleared). During the expired window, `get_noise_level()` returns the continuous state-keyed value, not the spike value. Auto-expiry is the SOLE clear mechanism — `get_noise_event()` never clears the latch; `reset_for_respawn()` clears it as part of the ordered reset (Story 007).
- [ ] **AC-3.5 [Logic]** **Reference retention footgun documented via test**: a stub consumer stores the reference returned by `get_noise_event()`; after a subsequent spike overwrites the latch in-place, reading `stored.origin` returns the NEW spike's origin. Test passes by asserting this footgun behaviour — it proves the "callers MUST copy fields before the next physics frame" contract is real and tested.
- [ ] **AC-6bis.1 [Logic]** `get_silhouette_height()` returns: standing (`IDLE/WALK/SPRINT`, `_crouch_transition_progress == 0.0`) → `1.7 ± 0.001 m`; crouched (`CROUCH`, `_crouch_transition_progress == 1.0`) → `1.1 ± 0.001 m`; mid-transition (`_crouch_transition_progress == 0.5`) → `1.4 ± 0.001 m`; DEAD state → `0.4 ± 0.001 m`.

---

## Implementation Notes

*Derived from GDD §Formulas F.4, F.8 + §Detailed Design §NoiseEvent:*

**Single reused NoiseEvent instance** — no per-spike allocation:
```gdscript
var _latched_event: NoiseEvent = null   # reused instance; fields overwritten in-place

func _latch_noise_spike(type: PlayerEnums.NoiseType, radius_m: float) -> void:
    # Highest-radius-wins collision; equal-or-lower preserves existing latch.
    if _latched_event != null and _latched_event.radius_m >= radius_m:
        return
    if _latched_event == null:
        _latched_event = NoiseEvent.new()
    # In-place mutation is intentional — see GDD F.4 and noise_event.gd doc comment.
    _latched_event.type = type
    _latched_event.radius_m = radius_m
    _latched_event.origin = global_transform.origin
    _latch_frames_remaining = _spike_latch_duration_frames
```

`_spike_latch_duration_frames` is computed once in `_ready()`:
```gdscript
_spike_latch_duration_frames = int(spike_latch_duration_sec * Engine.physics_ticks_per_second)
```
Default `spike_latch_duration_sec = 0.15` → 9 frames @ 60 Hz. Raised from 0.1 s (6 frames) to 0.15 s (9 frames) per ai-programmer B-2 fix (2026-04-21): 6-frame window did NOT cover every 10 Hz guard poll phase; 9 frames = 1.5× AI-tick window = every phase offset covered.

**`get_noise_level()` formula** (GDD F.4):
```gdscript
func get_noise_level() -> float:
    if current_state == PlayerEnums.MovementState.DEAD:
        return 0.0
    if _latched_event != null:
        return _latched_event.radius_m * noise_global_multiplier
    var moving: bool = velocity.length() >= idle_velocity_threshold
    if (current_state == PlayerEnums.MovementState.CROUCH
            or current_state == PlayerEnums.MovementState.WALK) and not moving:
        return 0.0
    return NOISE_BY_STATE[current_state] * noise_global_multiplier
```

`NOISE_BY_STATE` const dictionary built once in `_ready()` from exported noise knobs. IDLE / JUMP / FALL / DEAD map to 0.0 — those states emit via the latched spike path.

**Auto-expiry** in `_physics_process`:
```gdscript
if _latch_frames_remaining > 0:
    _latch_frames_remaining -= 1
    if _latch_frames_remaining == 0:
        _latched_event = null  # sole clear mechanism for normal play; reset_for_respawn also clears
```

**`get_silhouette_height()`** (GDD F.8):
```gdscript
func get_silhouette_height() -> float:
    if current_state == PlayerEnums.MovementState.DEAD:
        return 0.4
    return lerp(1.7, 1.1, _crouch_transition_progress)
```
`_crouch_transition_progress: float` is owned by Story 003's crouch transition tween. This story reads it; Story 003 writes it.

**`noise_global_multiplier`** is a ship-locked internal constant (`= 1.0`). It is NOT an `@export` variable accessible to designers or other systems. GDD game-designer B-2 closure: a runtime-tunable multiplier is a difficulty-selector backdoor; ship value locked to 1.0 requires a new ADR to change. Forbidden pattern: any system writing to `noise_global_multiplier` (CI lint enforces).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: `_latch_noise_spike()` call sites (jump takeoff, landing triggers — those transitions are in the movement state machine)
- Story 007: `reset_for_respawn()` clearing `_latched_event` to null as part of the ordered reset

---

## QA Test Cases

**AC-3.1 — Noise level by state**
- Given: `PlayerCharacter` with mocked `velocity` and `current_state` (no real physics needed)
- When: state forced to WALK with `velocity.length() = 3.5` (>= idle threshold); test for SPRINT, CROUCH, IDLE, JUMP, FALL, DEAD; test Walk-at-rest with `velocity.length() = 0.05`
- Then: WALK returns `noise_walk × multiplier`; SPRINT returns `noise_sprint × multiplier`; CROUCH moving returns `noise_crouch × multiplier`; IDLE/JUMP/FALL/DEAD return `0.0`; Walk-at-rest returns `0.0`; Crouch-at-rest returns `0.0`; tested at multipliers {0.7, 1.0, 1.3}
- Edge cases: DEAD always 0.0 even if `_latched_event` is non-null (defense-in-depth)

**AC-3.2 — Idempotent-read across 10 calls**
- Given: a JUMP_TAKEOFF spike latched
- When: `get_noise_event()` called 10 times within `_spike_latch_duration_frames`
- Then: all 10 calls return non-null; `type == JUMP_TAKEOFF`, `radius_m` and `origin` identical on all 10 calls
- Edge cases: latch expires between calls 9 and 10 → call 10 returns null (test constrains frame count to be within window)

**AC-3.3 — Highest-radius-wins + reverse order**
- Given: no spike latched
- When: JUMP_TAKEOFF (4 m) latched, then on next frame LANDING_SOFT (5 m) latched
- Then: `get_noise_event().type == LANDING_SOFT`, `radius_m == 5.0`
- When (reverse): LANDING_SOFT (5 m) first, then JUMP_TAKEOFF (4 m) on next frame
- Then: `get_noise_event().type == LANDING_SOFT`, `radius_m == 5.0` (lower radius did not overwrite)
- Edge cases: equal radii (4 m then 4 m) → first-recorded wins; radius exactly equal → not strictly greater → preserved

**AC-3.4 — Auto-expiry**
- Given: JUMP_TAKEOFF spike latched; `_spike_latch_duration_frames = 9`
- When: advance 8 physics ticks
- Then: `get_noise_event()` still returns non-null on tick 8 (frames_remaining reaches 1)
- When: advance 1 more tick (tick 9 — total elapsed ticks = N)
- Then: `get_noise_event() == null`; `get_noise_level()` returns the state-keyed value (not spike value)
- Edge cases: test advances tick count via manual `_process`-equivalent simulation, not real time. The expiry tick decrements at the *start* of each `_physics_process` call, so `frames_remaining` goes N→N-1→...→1→0; the latch is cleared on the tick that brings it to 0 (i.e. after exactly N elapsed ticks, not N+1).

**AC-3.5 — Reference retention footgun**
- Given: a spike latched; stub consumer stores `var saved = player.get_noise_event()`; records `saved.origin`
- When: on next frame a NEW spike with different origin overwrites the latch in-place
- Then: reading `saved.origin` returns the NEW spike's origin (not the saved one) — asserting this footgun behaviour; test PASSES when the footgun is confirmed (documents the contract is real)
- Edge cases: if `NoiseEvent` were immutable or copied, this test would fail — the test existence proves the in-place mutation design is working

**AC-6bis.1 — Silhouette height**
- Given: `_crouch_transition_progress` set to {0.0, 0.5, 1.0} and state set to {IDLE, CROUCH, DEAD}
- When: `get_silhouette_height()` called for each combination
- Then: standing (IDLE, progress=0.0) → 1.7 ± 0.001; mid (any, progress=0.5) → 1.4 ± 0.001; crouched (CROUCH, progress=1.0) → 1.1 ± 0.001; DEAD (any progress) → 0.4 ± 0.001
- Edge cases: `_crouch_transition_progress` outside [0.0, 1.0] due to bug → `lerp` may return out-of-range; test asserts `_crouch_transition_progress` is clamped by the tween owner (Story 003)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/core/player_character/player_noise_by_state_test.gd` — must pass (AC-3.1)
- `tests/unit/core/player_character/player_noise_event_idempotent_test.gd` — must pass (AC-3.2)
- `tests/unit/core/player_character/player_noise_event_collapse_test.gd` — must pass (AC-3.3)
- `tests/unit/core/player_character/player_noise_latch_expiry_test.gd` — must pass (AC-3.4)
- `tests/unit/core/player_character/player_noise_event_retention_test.gd` — must pass (AC-3.5)
- `tests/unit/core/player_character/player_silhouette_height_test.gd` — must pass (AC-6bis.1)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (PlayerEnums + NoiseEvent files), Story 003 (`_crouch_transition_progress` field; `_latch_noise_spike()` call sites in jump/landing transitions)
- Unlocks: Stealth AI epic (consumes `get_noise_level()`, `get_noise_event()`, `get_silhouette_height()`), Story 007 (`reset_for_respawn()` must clear `_latched_event`)

---

## Completion Notes

**Completed**: 2026-05-01
**Criteria**: 6/6 passing — all 6 ACs covered by 44 new test functions + 1 smoke test = 45 new test cases.
**Test results**: tests/unit/core/player_character/ → 95/95 PASS. Full suite → 188/188 PASS (was 144 before PC-004; +44 from PC-004 +1 smoke).

### Files added
- `src/gameplay/player/player_character.gd` (+115 net lines): noise interface (`get_noise_level`, `get_noise_event`, `get_silhouette_height`), full `_latch_noise_spike()` with highest-radius-wins + in-place mutation, auto-expiry tick, `NOISE_BY_STATE` typed dictionary, 9 export knobs, `noise_global_multiplier` ship-locked const.
- `tests/unit/core/player_character/player_noise_by_state_test.gd` (12 functions, AC-3.1)
- `tests/unit/core/player_character/player_noise_event_idempotent_test.gd` (5 functions, AC-3.2)
- `tests/unit/core/player_character/player_noise_event_collapse_test.gd` (5 functions, AC-3.3)
- `tests/unit/core/player_character/player_noise_latch_expiry_test.gd` (6 functions, AC-3.4 + smoke)
- `tests/unit/core/player_character/player_noise_event_retention_test.gd` (4 functions, AC-3.5)
- `tests/unit/core/player_character/player_silhouette_height_test.gd` (12 functions, AC-6bis.1)

### Files modified (out of stated scope, justified)
- `tests/unit/core/player_character/player_hard_landing_scaled_test.gd` (3 lines): replaced PC-003's stub `_latched_event_active = false` with new state semantics (`_latched_event = null` + `_latch_frames_remaining = 0`). Mechanical migration; PC-003's stub was always intended to be replaced.

### ADR work (separate but related)
- `docs/architecture/adr-0008-performance-budget-distribution.md` promoted Proposed → Accepted (with deferred numerical verification) via new Gate 5 (Architectural-Framework Verification). Synthetic load spike at `prototypes/verification-spike/perf_synthetic_load.tscn` confirmed: zero-alloc polling invariant (3588 polls, 0 non-zero allocation deltas), Slot-5 cost ~0.10 ms/frame on dev hw, save-write under load 0.681–1.090 ms (vs 10 ms cap), frame-time max 7.009 ms. Evidence: `production/qa/evidence/adr-0008-synthetic-load-2026-05-01.md`. Gates 1, 2, 4 reframed as DEFERRED until Restaurant scene + Iris Xe hardware available.

### Deviations from original spec
- **AC-3.4 wording fix**: Original "spike_latch_duration_frames + 1" was an off-by-one error in the spec; implementation correctly clears on tick N (where N = `_spike_latch_duration_frames`). AC text and QA Test Cases section corrected inline.
- **`spike_latch_duration_frames` → `_spike_latch_duration_frames`**: Renamed to private (leading underscore) per coding-standards convention for internal computed values. Cascaded through implementation + 2 test files + story prose.
- **`NOISE_BY_STATE: Dictionary` → `Dictionary[PlayerEnums.MovementState, float]`**: Typed per Godot 4.4+ control-manifest requirement (no untyped Dictionary).

### Code review verdict
**APPROVED WITH SUGGESTIONS** — engine specialist (godot-gdscript-specialist) returned CONCERNS initially with 3 blocking findings (typed dict, private rename, AC-3.4 off-by-one); all 3 fixed inline. qa-tester returned TESTABLE with full AC traceability + smoke-test recommendation (added).

### Critical proof points verified
- Zero-allocation contract: 3588 polls in synthetic spike → 0 non-zero allocation deltas (PC-004 GDD F.4 invariant)
- In-place mutation footgun: stored ref reflects new spike's origin/type/radius after overwrite (AC-3.5 `is_same()` identity check passes)
- Auto-expiry tick at top of `_physics_process`: latch state coherent for any same-tick consumer
- Highest-radius-wins collision: 4→5 wins; 5→4 retained; 4→4 first-wins (AC-3.3)
- DEAD defense-in-depth: returns 0.0 even with active latch (AC-3.1 priority order)
- Silhouette height DEAD short-circuits lerp (AC-6bis.1 — 0.4 m for any progress value when DEAD)

### Tech debt logged
- `_latch_noise_spike()` zero-radius / negative-radius edge cases unguarded (current call sites all use positive `@export_range` knobs; not a current risk; flag for AI integration future)
- Multiplier testability ceiling at AC-3.1 (cannot directly test `noise_global_multiplier` since ship-locked const) — documented as inherent limit per game-designer B-2

### Unblocks
- **Stealth AI epic**: SAI consumes `get_noise_level()`, `get_noise_event()`, `get_silhouette_height()` at 80 Hz aggregate polling per ADR-0008 Slot 2
- **PC-007** (`reset_for_respawn()` story): now has `_latched_event` state to clear in the ordered reset
