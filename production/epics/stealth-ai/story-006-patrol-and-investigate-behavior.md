# Story 006: Patrol + investigate + combat behavior dispatch

> **Epic**: Stealth AI
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 3-4 hours (L — PatrolController, state-driven movement, integration test)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/stealth-ai.md`
**Requirement**: `TR-SAI-002` (state machine behavioral outputs), `TR-SAI-013` (takedown_prompt_active accessor — rear-arc geometry)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006 (Collision Layer Contract), ADR-0002 (Signal Bus)
**ADR Decision Summary**: `NavigationAgent3D` target_position writes dispatch path queries on the nav server's background thread (async, Godot 4.6 default). `map_get_path` direct sync calls are a forbidden pattern. `PatrolController` samples a `Path3D` curve and writes successive waypoints to `NavigationAgent3D.target_position` on `is_navigation_finished()`. The `takedown_prompt_active(attacker)` accessor uses the `_perception_cache` from Story 003 plus rear-arc dot-product math.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `NavigationAgent3D.target_position` write sends an async query; `is_navigation_finished()` becomes true on the NEXT physics frame after the nav server processes the query. `velocity_computed` signal fires on the main thread when the nav server delivers a computed velocity. In Godot 4.6, `NavigationAgent3D.velocity_computed` is the idiomatic way to receive the desired velocity — connect to it in `_ready()`. `move_and_slide()` call uses the velocity from the last `velocity_computed` emission. `NavigationAgent3D.max_speed` must match the per-state locomotion speed. `Path3D` sampling uses `Curve3D.sample_baked(offset, cubic=false)` — bake the curve in the editor before runtime. `Vector3` lacks `.with_y(0)` — implement as `Vector3(delta.x, 0.0, delta.z)`.

**Control Manifest Rules (Feature/Core)**:
- Required (ADR-0006): `collision_mask` on movement must use `PhysicsLayers.*` constants
- Forbidden: `NavigationServer3D.map_get_path()` synchronous calls — use `NavigationAgent3D` async dispatch only
- Guardrail: `REPATH_INTERVAL_SEC = 1.0 s` + `REPATH_MIN_DELTA_M = 1.0 m` hard floors — declare as `const` with `assert` in `_ready()` per GDD Tuning Knobs

---

## Acceptance Criteria

*From GDD §Detailed Rules (Guard node architecture, Investigate behavior, Combat behavior, COMBAT recovery pacing spec) + TR-SAI-002 + TR-SAI-013:*

- [ ] **AC-1**: At UNAWARE state, guard follows patrol route at `PATROL_SPEED (~1.2 m/s)`. `PatrolController` samples successive waypoints from a `Path3D` resource and writes each to `NavigationAgent3D.target_position` on `is_navigation_finished()`. Wraps to first waypoint at path end. Integration test: guard completes at least 2 waypoint transitions in 10 s on a simple 2-waypoint path.
- [ ] **AC-2**: On UNAWARE → SUSPICIOUS transition (from Story 005 escalation), guard stops patrol (sets `NavigationAgent3D.target_position = global_position` — stop in place), faces the stimulus direction (sets `look_at` toward `last_stimulus_position`), holsters weapon (if drawn). Mutter vocal is NOT emitted by this story — owned by Dialogue & Subtitles (forward dep).
- [ ] **AC-3**: On SUSPICIOUS → SEARCHING transition, guard navigates to Last Known Position (LKP) at `INVESTIGATE_SPEED (~1.6 m/s)`. On arrival (within `INVESTIGATE_ARRIVAL_EPSILON_M = 0.5 m`), guard plays sweep animation and waits `INVESTIGATE_SWEEP_SEC (3.0 s)`. If no new stimulus: story 007 handles timer and de-escalation. The navigation itself (`target_position = LKP`) is implemented here.
- [ ] **AC-4**: On SEARCHING → COMBAT transition, guard draws weapon and navigates to cover at `COMBAT_SPRINT_SPEED (~3.0 m/s)`. VS scope: cover nodes are MVP stubs — guard navigates directly toward `last_sight_position` without tactical cover evaluation (cover navigation is post-VS).
- [ ] **AC-5**: On COMBAT → SEARCHING de-escalation (after `COMBAT_LOST_TARGET_SEC`), weapon moves to ready-at-hip (drawn but not raised). Guard navigates back to patrol-adjacent area or LKP. GDD COMBAT recovery pacing spec: guard must not snap to SEARCHING instantly — de-escalation flow is owned by Story 007.
- [ ] **AC-6** (AC-SAI-3.10 — takedown_prompt_active): `takedown_prompt_active(attacker: Node) -> bool` returns `true` iff ALL of:
  - `current_alert_state in {UNAWARE, SUSPICIOUS}`
  - `attacker` is within the rear half-cone: `(-guard.global_transform.basis.z).dot((attacker.global_position - guard.global_position).normalized()) <= 0` (boundary: dot ≤ 0 = rear, inclusive per GDD)
  - `distance(attacker, guard) <= TAKEDOWN_RANGE_M (1.5 m)` (XZ-plane distance)
  - `_perception_cache.los_to_player == false` (guard does NOT currently have LOS to attacker)
  - `is_instance_valid(attacker) == true`
  - Zero-distance short-circuit: `Vector3(delta.x, 0, delta.z).length_squared() < 1e-4` → returns `false`
- [ ] **AC-7** (E.12 — navigation fail graceful): If `NavigationAgent3D` returns no path (nav mesh missing or guard stuck), guard idles at current position for `PATROL_STUCK_RECOVERY_SEC (5.0 s)` via a timer, then attempts the next patrol waypoint. No crash, no freeze.

---

## Implementation Notes

*Derived from GDD §Detailed Rules + GDD §Tuning Knobs:*

`PatrolController` is a sibling sub-component of `NavigationAgent3D` in the Guard scene. It samples `Path3D.curve` and writes `NavigationAgent3D.target_position` on `is_navigation_finished()`. The `Path3D` reference is an `@export var path: Path3D` on `PatrolController`.

`NavigationAgent3D.velocity_computed.connect(_on_velocity_computed)` in `_ready()`. In `_on_velocity_computed(safe_velocity: Vector3)`: set `velocity = safe_velocity` then call `move_and_slide()`.

State-driven speed: guard's `NavigationAgent3D.max_speed` is updated on state transitions:
- UNAWARE → `PATROL_SPEED (1.2 m/s)`
- SUSPICIOUS → `0.0` (stopped, face stimulus)
- SEARCHING → `INVESTIGATE_SPEED (1.6 m/s)`
- COMBAT → `COMBAT_SPRINT_SPEED (3.0 m/s)`

Rear-arc dot-product math — the forward vector is `-guard.global_transform.basis.z`. Attacker direction:
```gdscript
var delta_3d := attacker.global_position - global_position
var delta_xz := Vector3(delta_3d.x, 0.0, delta_3d.z)  # .with_y(0) does not exist in Godot 4.x
if delta_xz.length_squared() < 1e-4:
    return false  # zero-distance short-circuit
var attacker_dir := delta_xz.normalized()
var forward := -global_transform.basis.z
var dot := forward.dot(attacker_dir)
return dot <= 0.0  # rear = inclusive boundary at exactly 90°
```

LKP management: sight LKPs take priority over sound LKPs (GDD E.3 `_lkp_has_sight_confirm` flag). The flag is set true on sight-sourced LKP writes; sound writes are ignored while it remains true during SEARCHING dwell.

`REPATH_MIN_DELTA_M` and `REPATH_INTERVAL_SEC` are `const` (not `@export`) per GDD Tuning Knobs:
```gdscript
const REPATH_MIN_DELTA_M: float = 1.0
const REPATH_INTERVAL_SEC: float = 1.0
```
Both have `assert(REPATH_MIN_DELTA_M >= 0.5)` and `assert(REPATH_INTERVAL_SEC >= 0.5)` in `_ready()`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: state escalation/de-escalation logic that triggers the behavior changes
- Story 007: de-escalation timers (SUSPICION_TIMEOUT_SEC, SEARCH_TIMEOUT_SEC, COMBAT_LOST_TARGET_SEC)
- Post-VS: tactical cover evaluation in COMBAT (hand-authored CoverNodes — post-MVP per GDD OQ-SAI-2)
- Post-VS: receive_takedown / receive_damage (no chloroform gadget in VS)
- Post-VS: UNCONSCIOUS/DEAD cleanup (NavigationAgent3D stop, group swap) — requires damage-path in VS
- Post-VS: F.4 alert propagation (no second guard to propagate to)
- Post-VS: guard dialogue / vocal callouts (Dialogue & Subtitles forward dep — stubbed with placeholder)

---

## QA Test Cases

**AC-1 — Patrol waypoint progression**
- Given: guard in UNAWARE; `Path3D` with 2 waypoints 4 m apart; nav mesh covers the area
- When: 10 physics seconds simulated
- Then: guard visits both waypoints at least once; `NavigationAgent3D.target_position` transitions between waypoints; guard returns to first waypoint (loop)
- Edge cases: single-waypoint path → guard reaches it and stays; no path assigned → E.12 fallback (AC-7)

**AC-6 — takedown_prompt_active (AC-SAI-3.10)**
- Given: various (state, position, distance, LOS) configurations as parametrized rows
- When: `takedown_prompt_active(attacker)` called
- Then: returns true only when all 5 eligibility dimensions pass; returns false for any single-dimension failure; all-negative multi-dimension case returns false (AC-3.10.g)
- Edge cases: attacker at exactly 90° → returns true (inclusive boundary); zero-distance attacker → returns false; freed attacker → returns false

**AC-7 — Navigation graceful fail**
- Given: guard in SEARCHING; nav mesh NOT baked; `NavigationAgent3D.target_position` set to LKP
- When: no path returned by nav server
- Then: guard idles at current position; no crash; after `PATROL_STUCK_RECOVERY_SEC (5 s)`, advances to next patrol waypoint
- Edge cases: nav mesh partially covering — guard pathfinds to nearest reachable node and idles from there

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/feature/stealth_ai/stealth_ai_patrol_behavior_test.gd` — AC-1 (patrol loop)
- `tests/unit/feature/stealth_ai/stealth_ai_takedown_prompt_active_test.gd` — AC-SAI-3.10 (9 parametrized dimensions)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 DONE (Guard scene), Story 002 DONE (AlertState enum), Story 005 DONE (state transitions drive behavior changes)
- Unlocks: Story 008 (full perception → state → signal pipeline needed for audio integration test), Story 010 (performance test needs behavior running)
