# Story 003: Movement state machine + locomotion

> **Epic**: Player Character
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3-4 hours (L — 7-state machine, F.1/F.2/F.3 formulas, coyote time, crouch transition, ceiling check)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/player-character.md`
**Requirements**: TR-PC-003, TR-PC-004, TR-PC-005
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006 (Collision Layer Contract), ADR-0008 (Performance Budget Distribution)
**ADR Decision Summary**: Movement uses `velocity + move_and_slide()` in `_physics_process` at 60 Hz per Godot 4.6 / Jolt default. Collision layer constants from `PhysicsLayers.*` — zero bare integer literals. ADR-0008 slot 1 PC budget: steady-state 0.55 ms target for the combined movement state machine + `_physics_process`. The `Δt_clamped = min(delta, 1.0/30.0)` hitch guard in F.1 and F.2 prevents loading spikes from fabricating false noise spikes via F.3.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `CharacterBody3D.move_and_slide()`, `is_on_floor()`, `ShapeCast3D.force_shapecast_update()`, and Jolt physics are all available in Godot 4.6. Jolt's `is_on_floor()` has documented stochastic edge behavior at ledge edges (GDD AC-2.1 widens apex tolerance to ±0.05 m for this reason). The `ShapeCast3D` only updates during its own `_physics_process` tick otherwise — `force_shapecast_update()` is mandatory for same-frame ceiling queries. `Vector2(velocity.x, velocity.z)` intermediate for planar velocity is required because GDScript does not support `.xz` swizzle assignment (GDD F.1 Session F fix).

**Control Manifest Rules (Core)**:
- Required: `_physics_process(delta)` — movement runs at 60 Hz physics tick rate
- Required: `Δt_clamped = min(delta, 1.0/30.0)` applied in F.1 and F.2 (hitch guard)
- Required: `move_and_slide()` for collision-resolved movement; no direct `position +=` in movement
- Forbidden: no stamina meter, no sprint cooldown, no air control, no double-jump (TR-PC-005 / Pillar 5)
- Forbidden: no CrouchSprint state (GDD rejected features)

---

## Acceptance Criteria

*From GDD `design/gdd/player-character.md` §Acceptance Criteria AC-1, AC-2, §States and Transitions:*

- [ ] **AC-1.1 [Logic]** Walking on flat terrain with `input_magnitude == 1.0`: `velocity.length()` reaches `walk_speed ± 0.1 m/s` within 9 physics frames (0.15 s @ 60 Hz) of key-press. Default `walk_speed = 3.5 m/s`.
- [ ] **AC-1.2 [Logic]** Sprint from rest reaches `sprint_speed ± 0.1 m/s` within 12 physics frames (0.20 s). Default `sprint_speed = 5.5 m/s`.
- [ ] **AC-1.3 [Logic]** Crouch-walk reaches `crouch_speed ± 0.1 m/s` within 9 physics frames (0.15 s); `CapsuleShape3D.height == 1.1 m` at the end of the 120 ms crouch transition (ease-in-out).
- [ ] **AC-2.1 [Logic]** At defaults (`gravity=12.0, jump_velocity=3.8`), flat-ground jump apex ∈ [0.55, 0.65] m. Apex = `max(global_position.y)` − `global_position.y at takeoff`. Tolerance widens to ±0.05 m for Jolt stochastic `is_on_floor()` edge behavior.
- [ ] **AC-2.2 [Logic]** Safe-range invariants — parametrized test sweeping `gravity ∈ {11, 12, 13}` × `jump_velocity ∈ {3.5, 3.8, 4.2}` (9 combinations): (a) for all 9: `0.45 m ≤ apex ≤ 0.80 m`; (b) for all 9: flat-ground jump landing does NOT latch `LANDING_HARD` — at the first `is_on_floor()` frame after Jump, `get_noise_event() == null` OR `get_noise_event().type != NoiseType.LANDING_HARD`.
- [ ] **AC-2.3 [Logic]** Hard landing with `|velocity.y| > v_land_hard`: `get_noise_event().type == LANDING_HARD` AND `radius_m == 8.0 × clamp(|velocity.y| / v_land_hard, 1.0, 2.0)` within ±0.1 m tolerance. Verified at three impact speeds (1.0×, 1.5×, 2.0× `v_land_hard`) with expected radii (8.0, 12.0, 16.0).
- [ ] **AC-state-machine [Logic]** State transitions follow the GDD table: Idle → Walk (movement input), Walk → Sprint (+ Shift), Ground → Crouch (Ctrl toggle, blocked if ceiling), Ground → Jump (Space + `_can_jump()`; blocked in Crouch), Jump → Fall (`velocity.y ≤ 0`), Fall → Ground states (`is_on_floor()`), Any → Dead (handled by Story 006). Coyote time: `_can_jump()` returns true for `coyote_time_frames` (default 3) after the last `is_on_floor()` == true frame.
- [ ] **AC-ceiling-check [Logic]** Uncrouch blocked by ceiling: after crouching below a 1.4 m ceiling, pressing Ctrl to uncrouch triggers `ShapeCast3D.force_shapecast_update()` then reads `is_colliding()`; if blocked, state stays CROUCH, soft head-bump SFX is requested, no visual UI feedback.

---

## Implementation Notes

*Derived from GDD §Detailed Design §Formulas F.1/F.2/F.3 + §States and Transitions:*

**F.1 Horizontal velocity blend** (ground states only — IDLE/WALK/SPRINT/CROUCH):
```gdscript
func _apply_horizontal_velocity(delta: float) -> void:
    var planar_velocity := Vector2(velocity.x, velocity.z)
    var planar_target := Vector2(v_target.x, v_target.z)
    var rate_time: float
    if input_magnitude > 0.0:
        rate_time = max(accel_time, 0.001)
    else:
        rate_time = max(decel_time, 0.001)
    var delta_clamped: float = min(delta, 1.0 / 30.0)
    var step: float = (1.0 / rate_time) * max_speed * delta_clamped
    planar_velocity = planar_velocity.move_toward(planar_target, step)
    velocity.x = planar_velocity.x
    velocity.z = planar_velocity.y
```
`Vector2(velocity.x, velocity.z)` intermediate is required — GDScript has no `.xz` swizzle.

**F.2 Gravity and jump**:
```gdscript
func _apply_vertical_velocity(delta: float) -> void:
    var delta_clamped: float = min(delta, 1.0 / 30.0)
    if not is_on_floor():
        velocity.y -= gravity * delta_clamped
    if Input.is_action_just_pressed("jump") and _can_jump():
        velocity.y = jump_velocity
```

**F.3 Hard-landing noise** (latches a `NoiseEvent` — coordination with Story 004's spike-latch):
```
v_land_hard = sqrt(2 × gravity × hard_land_height)
noise_radius = 8.0 × clamp(|velocity.y| / v_land_hard, 1.0, 2.0)
```

**Crouch transition**: 120 ms ease-in-out `Tween` on `_camera.position.y` (1.6 → 1.0 m) and `CapsuleShape3D.height` (1.7 → 1.1 m). `_crouch_transition_progress: float` (0.0 = standing, 1.0 = crouched) is updated during the tween — Story 004's `get_silhouette_height()` reads this value.

**Coyote time**: `_coyote_frames_remaining: int` decrements each `_physics_process` tick when not on floor. `_can_jump()` returns true if `is_on_floor()` OR `_coyote_frames_remaining > 0` (AND current state is not CROUCH).

**No air control**: F.1 runs only in ground states. Jump and Fall preserve the takeoff planar velocity unchanged.

**All speed/gravity/noise values are `@export` variables** with `@export_range(safe_min, safe_max, 0.01)` annotations per GDD Tuning Knobs. Designer-facing: `walk_speed`, `sprint_speed`, `crouch_speed`, `gravity`, `jump_velocity`, `hard_land_height`, noise knobs. Internal: `walk_accel_time`, `walk_decel_time`, `coyote_time_frames`, etc. stored in a `PlayerFeel.tres` resource.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: Scene root scaffold (ShapeCast3D ceiling check node must already exist)
- Story 002: Camera look input, turn overshoot, sprint sway
- Story 004: Actual NoiseEvent spike-latch implementation (`_latch_noise_spike()` called from this story but defined in Story 004); `get_noise_level()` and `get_noise_event()` accessors
- Story 006: Dead state entry from damage (Any → Dead transition triggered by health system)
- Story 007: Dead-state camera animation, reset_for_respawn

---

## QA Test Cases

**AC-1.1 — Walk speed**
- Given: `PlayerCharacter` with flat floor physics setup; `walk_speed = 3.5`
- When: `Input.get_action_strength("move_forward")` returns 1.0 for 9 consecutive `_physics_process(1.0/60.0)` ticks
- Then: `velocity.length()` >= `3.4` and `velocity.length()` <= `3.6` by frame 9
- Edge cases: `accel_time = 0` → NaN guard kicks in (max(0, 0.001)); frame 1 velocity = step ≈ 0.486 m/s

**AC-1.2 — Sprint speed**
- Given: same floor setup; `sprint_speed = 5.5`, sprint input active
- When: 12 ticks
- Then: `velocity.length()` >= `5.4` and `velocity.length()` <= `5.6`

**AC-1.3 — Crouch speed + collider height**
- Given: CROUCH state active; 120 ms tween complete
- When: crouch movement input for 9 ticks
- Then: `velocity.length()` within `1.7–1.9 m/s`; `(collision_shape.shape as CapsuleShape3D).height == 1.1 ± 0.01`
- Edge cases: tween interrupted mid-transition → height is interpolated value, not 1.1; test waits for tween completion

**AC-2.1 — Jump apex at defaults**
- Given: flat floor; `gravity = 12.0`, `jump_velocity = 3.8`
- When: jump pressed; simulate ticks until `is_on_floor()` returns true again; record peak Y
- Then: `peak_y - takeoff_y` in range `[0.55, 0.65]`
- Edge cases: Jolt stochastic floor detection may give 1-frame variance; tolerance ±0.05 m accounts for this

**AC-2.2 — Safe-range parametrized sweep**
- Given: parametrized test over 9 (gravity, jump_velocity) combinations
- When: each combination: perform a flat-ground jump; record apex; check landing noise event
- Then: all 9 apexes in [0.45, 0.80]; no combination latches LANDING_HARD at flat-ground landing
- Edge cases: corners (11, 3.5) and (13, 4.2) are the invariant boundary values; must be explicitly tested

**AC-2.3 — Hard landing scaled noise**
- Given: Eve in Fall state; 3 test drop heights giving `|velocity.y|` at 1.0×, 1.5×, 2.0× `v_land_hard`
- When: landing occurs (is_on_floor() transitions to true)
- Then: `get_noise_event().type == LANDING_HARD`; radii are 8.0 ± 0.1, 12.0 ± 0.1, 16.0 ± 0.1
- Edge cases: landing at exactly `v_land_hard` → `>` comparison fails → LANDING_SOFT fires (5 m); intentional threshold discontinuity per GDD F.3

**AC-state-machine — transitions**
- Given: mock input driver + SceneTree
- When: input sequence: idle → forward key → shift → release shift → ctrl → space → ctrl held through fall
- Then: state sequence matches: IDLE → WALK → SPRINT → WALK → CROUCH (120ms) → blocked Jump (Crouch) → uncrouch → WALK → JUMP → FALL → WALK
- Edge cases: coyote time: step off ledge edge, press jump within 3 frames → JUMP should fire

**AC-ceiling-check — ShapeCast3D blocking uncrouch**
- Given: Eve in CROUCH; a static ceiling body at 1.4 m above the floor placed directly above her
- When: Ctrl released (uncrouch attempt)
- Then: `ShapeCast3D.force_shapecast_update()` is called; `is_colliding()` returns true; `current_state` stays CROUCH; SFX request is made (verify via signal or method call spy)
- Edge cases: `force_shapecast_update()` not called → reads stale is_colliding from prior frame → ceiling-block silently fails

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/core/player_character/player_walk_speed_test.gd` — must pass (AC-1.1)
- `tests/unit/core/player_character/player_sprint_speed_test.gd` — must pass (AC-1.2)
- `tests/unit/core/player_character/player_crouch_speed_test.gd` — must pass (AC-1.3)
- `tests/unit/core/player_character/player_jump_apex_test.gd` — must pass (AC-2.1)
- `tests/unit/core/player_character/player_jump_safe_range_test.gd` — must pass (AC-2.2)
- `tests/unit/core/player_character/player_hard_landing_scaled_test.gd` — must pass (AC-2.3)
- `tests/unit/core/player_character/player_state_machine_test.gd` — must pass (AC-state-machine)
- `tests/unit/core/player_character/player_ceiling_check_test.gd` — must pass (AC-ceiling-check)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (scene root + ShapeCast3D node), Story 004 (coordination: `_latch_noise_spike()` method stub must be callable from landing/takeoff transitions — stub acceptable, full implementation in Story 004)
- Unlocks: Story 004 (noise state-keyed values depend on `current_state` being accurate), Story 005 (interact disables sprint during reach window — needs movement state machine)
