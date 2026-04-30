# Story 004: F.1 sight fill formula + VisionCone integration

> **Epic**: Stealth AI
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 3-4 hours (L — 25-row parametrized test, formula implementation, cache write)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/stealth-ai.md`
**Requirement**: `TR-SAI-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006 (Collision Layer Contract)
**ADR Decision Summary**: Perception raycasts query `PhysicsLayers.MASK_AI_VISION_OCCLUDERS` (composite of `LAYER_WORLD`; excludes `LAYER_PLAYER` and `LAYER_AI` so Eve and other guards are not treated as occluders — the ray hits them directly). The `IRaycastProvider` DI seam (Story 003) means production scenes use `RealRaycastProvider` wrapping `PhysicsDirectSpaceState3D.intersect_ray`; unit tests use `CountingRaycastProvider` with `scripted_result` to avoid physics engine dependency.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: Jolt 3D (default in 4.6) honors `PhysicsRayQueryParameters3D` the same as GodotPhysics — the DI interface abstracts this. `VisionCone` (Area3D) `body_entered` fires on Jolt's physics step. The guard's forward axis is `-guard.global_transform.basis.z` (not `basis * Vector3.FORWARD` which is +X). `Vector3.normalized()` returns `Vector3.ZERO` when magnitude is 0 — the zero-distance short-circuit must check `length() < 0.1` BEFORE calling `normalized()`. `Δt_clamped = min(delta, 1.0 / 30.0)` is the hitch guard (mirrors PC's pattern). `Engine.get_physics_frames()` used for `frame_stamp` in the perception cache.

**Control Manifest Rules (Feature/Core)**:
- Required (ADR-0006): `PhysicsRayQueryParameters3D.collision_mask` MUST reference `PhysicsLayers.MASK_AI_VISION_OCCLUDERS` — no bare integers
- Required (coding standards): all gameplay values (`BASE_SIGHT_RATE`, `VISION_MAX_RANGE_M`, etc.) are `@export var` with defaults — never hardcoded in logic
- Required (coding standards): static typing on all GDScript; every function has typed parameters and return type

---

## Acceptance Criteria

*From GDD §Formulas §F.1 + TR-SAI-007:*

- [ ] **AC-1** (AC-SAI-2.1): The `Perception` node implements F.1 sight fill per physics frame while Eve's `CharacterBody3D` is inside the `VisionCone` AND the LOS raycast succeeds:
  ```
  sight_fill_rate = BASE_SIGHT_RATE × range_factor × silhouette_factor × movement_factor × state_multiplier × body_factor
  _sight_accumulator += sight_fill_rate × Δt_clamped
  ```
  All 6 factors implemented per GDD variable table (range linear falloff, silhouette clamp [0.5, 1.0], movement_factor state-keyed including DEAD_TARGET=0.3, state_multiplier {1.0, 1.5, 1.5, 2.0}, body_factor {1.0 alive, 2.0 dead}).
- [ ] **AC-2** (AC-SAI-2.1 — parametrized 25-row test): Unit test covering all 6 factors:
  - (a) range × movement grid: 15 combinations (range ∈ {0.5, 2, 6, 12, 17.9} × movement ∈ {Walk, Crouch, Sprint})
  - (b) silhouette: 3 rows (1.7 standing, 1.1 crouched, 0.6 hypothetical-prone → clamps to 0.5)
  - (c) state_multiplier: 4 rows (UNAWARE 1.0, SUSPICIOUS 1.5, SEARCHING 1.5, COMBAT 2.0)
  - (d) body_factor: 1 row — dead guard at range 6 m Walk → fill rate exactly 2× the equivalent alive-player row
  - (e) DEAD movement_factor: 1 row — Eve's movement_state == DEAD → `sight_fill_rate == 0.0` regardless of other factors
  - (f) zero-distance short-circuit: 1 row — Eve at guard eye + Vector3(0,0,0.01) → accepted AND `sight_fill_rate > 0`
  All 25 rows assert computed `sight_fill_rate` within 0.01 tolerance. `CountingRaycastProvider` injected; `scripted_result = {}` (LOS fail) and `scripted_result = {collider: eve_stub}` (LOS pass) toggled per row.
- [ ] **AC-3**: After each F.1 tick, `_perception_cache` is written with `initialized = true`, `frame_stamp = Engine.get_physics_frames()`, `los_to_player = <result>`, `los_to_player_position = eve.global_position` (at time of cache write), `last_sight_stimulus_cause = SAW_PLAYER` (or `SAW_BODY` for dead-guard targets), `last_sight_position = eve.global_position`.
- [ ] **AC-4**: Raycast caching: on any physics frame where both F.1 (sight LOS) and F.2a (sound occlusion) are invoked, the implementation issues exactly ONE raycast for the `guard → Eve` pair, not two. Verified via `CountingRaycastProvider.call_count` assertion: for one guard with both sight and sound active, `call_count` increments by 1 per frame, not 2.
- [ ] **AC-5**: `_sight_accumulator` never exceeds 1.0 (clamped at each add-step) and never goes below 0.0 (floored by decay, Story 007). The sight accumulator is a `float` field in `[0.0, 1.0]`.
- [ ] **AC-6**: Downward tilt: the reference forward vector is `(-guard.global_transform.basis.z).rotated(guard.global_transform.basis.x, -deg_to_rad(VISION_CONE_DOWNWARD_ANGLE_DEG))` before the dot-product check. `VISION_CONE_DOWNWARD_ANGLE_DEG` is an `@export var` defaulting to `15.0`.

---

## Implementation Notes

*Derived from GDD §F.1 + §Core Rules (VisionCone):*

The full F.1 sight fill formula with all variable definitions:

| Variable | Symbol | Range | Formula |
|---|---|---|---|
| `range_factor` | r | [0, 1] | `1.0 - clamp(d(eye, head) / VISION_MAX_RANGE_M, 0, 1)` |
| `silhouette_factor` | h | [0.5, 1] | `clamp(eve.get_silhouette_height() / 1.7, 0.5, 1.0)` |
| `movement_factor` | m | [0, 1.5] | DEAD=0.0, DEAD_TARGET=0.3, IDLE/Crouch-still=0.3, Walk=1.0, Crouch=0.5, Sprint=1.5, Jump/Fall=0.8 |
| `state_multiplier` | s | {1.0,1.5,1.5,2.0} | UNAWARE=1.0, SUSPICIOUS=1.5, SEARCHING=1.5, COMBAT=2.0 |
| `body_factor` | b | {1.0, 2.0} | alive Eve in `player` group=1.0; dead guard in `dead_guard` group=2.0 |

Output range: 0.0 to **6.0/sec** (dead body at close range with Combat guard: `1.0×1.0×1.0×1.5×2.0×2.0`).

LOS raycast query (per physics frame inside the VisionCone callback):
```gdscript
var query := PhysicsRayQueryParameters3D.create(
    guard_eye_position,
    eve_head_position,
    PhysicsLayers.MASK_AI_VISION_OCCLUDERS,
    [get_rid()]  # exclude self
)
var result := raycast_provider.cast(query)
var has_los := result.is_empty() or result.get("collider") == target_body
```

`has_los` is true when ray hits nothing (unobstructed) OR when the first hit IS the target body (Eve in LAYER_PLAYER is not in `MASK_AI_VISION_OCCLUDERS`, so the ray passes through her — wait, Eve IS in `LAYER_PLAYER` and the occluder mask excludes that layer. So if LOS is unobstructed the result is empty. If something blocks it, result is non-empty but collider is world geometry, not Eve. Thus `has_los = result.is_empty()`. Verify this logic matches the GDD LOS gate: "fill rate is 0 if the LOS raycast hits anything on `MASK_AI_VISION_OCCLUDERS`." `MASK_AI_VISION_OCCLUDERS` = world geometry only; Eve and guards are not in this mask. So `has_los = result.is_empty()`.

`Δt_clamped = min(delta, 1.0 / 30.0)` — apply to every accumulator increment.

`_sight_accumulator = clamp(_sight_accumulator + sight_fill_rate * delta_clamped, 0.0, 1.0)`.

The `HearingPoller` 10 Hz stagger: in `_ready()`, set the initial tick counter to `get_instance_id() % 6` so co-spawned guards spread across the 6-frame polling period. Story 004 implements the stub; full F.2 sound fill is Post-VS (TR-SAI-008 deferred).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: F.5 thresholds + escalation/de-escalation logic that consumes `_sight_accumulator`
- Story 007: F.3 accumulator decay (the subtract side of the accumulator)
- Post-VS (TR-SAI-008): F.2 sound fill formula (HearingPoller at 10 Hz, `get_noise_level()`, occlusion factor, elevation factor, surface factor) — sound fill is deferred because the basic VS Plaza tutorial does not require noise detection
- Post-VS (TR-SAI-010): F.4 alert propagation — no second guard in VS
- Post-VS: `body_factor` decay for UNCONSCIOUS guards (2.0→1.0 linear over `WAKE_UP_SEC`) — no UNCONSCIOUS state in VS

---

## QA Test Cases

**AC-2 — F.1 parametrized 25-row formula**
- Given: `Perception` node with `CountingRaycastProvider` injected; `scripted_result` set to empty (LOS blocked) or hit (LOS clear) per row; guard state and Eve silhouette/movement set per row
- When: `_process_sight_fill(target_body, delta)` is called once
- Then: computed `sight_fill_rate` matches formula within 0.01 tolerance for all 25 rows; `_sight_accumulator` incremented by `sight_fill_rate × delta`
- Edge cases: zero-distance → short-circuit (no `normalized()` called on zero vector); movement_factor DEAD → rate == 0 regardless of other factors

**AC-3 — Cache write after F.1 tick**
- Given: F.1 tick runs with LOS clear (`scripted_result` non-empty with `collider = eve`)
- When: `_perception_cache` read immediately after the tick
- Then: `initialized == true`, `frame_stamp == Engine.get_physics_frames()`, `los_to_player == true`, `los_to_player_position == eve.global_position`
- Edge cases: LOS blocked → `los_to_player == false`; frame_stamp from previous frame → cache correctly updated to current frame

**AC-4 — Raycast deduplication**
- Given: F.1 and F.2a both active in the same physics frame for the same guard/Eve pair; `CountingRaycastProvider` injected
- When: one full physics frame processes (F.1 tick + F.2a occlusion)
- Then: `call_count` increments by exactly 1 (not 2) — cache reuse prevents the duplicate raycast
- Edge cases: multiple guards in scene → each guard's own provider counted independently

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/feature/stealth_ai/stealth_ai_sight_fill_rate_test.gd` — AC-SAI-2.1 (25 rows)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 DONE (needs `StealthAI.AlertState` for state_multiplier lookup), Story 003 DONE (needs `IRaycastProvider` DI + `PerceptionCache` struct)
- Unlocks: Story 005 (F.5 thresholds read `_sight_accumulator` to escalate), Story 007 (F.3 decay applies to `_sight_accumulator`)
