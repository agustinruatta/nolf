# Story 001: Guard node scaffold

> **Epic**: Stealth AI
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2-3 hours (M — 8 new files, node hierarchy, unit test)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/stealth-ai.md`
**Requirement**: `TR-SAI-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006 (Collision Layer Contract)
**ADR Decision Summary**: Guards sit on `LAYER_AI` (layer 3); their `CharacterBody3D` sets `collision_layer = PhysicsLayers.MASK_AI`, `collision_mask = PhysicsLayers.MASK_WORLD | PhysicsLayers.MASK_PLAYER`. Vision-cone `Area3D` uses `layer = 0`, `mask = PhysicsLayers.MASK_PLAYER | PhysicsLayers.MASK_AI` (player-body perception + dead-guard body perception). Raycasts use composite `PhysicsLayers.MASK_AI_VISION_OCCLUDERS`. Bare integer literals in `collision_layer` / `collision_mask` are a forbidden pattern and block PRs.

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `NavigationAgent3D` in Godot 4.6 is asynchronous by default — `NavigationServer3D.map_get_path()` direct sync calls are a forbidden pattern (AC-SAI-3.12.b). Use `NavigationAgent3D.target_position` writes and let the nav server dispatch on its own thread. `CharacterBody3D` and `move_and_slide()` are stable. Jolt is the default 3D physics engine as of Godot 4.6. `OutlineTier.set_tier(mesh, OutlineTier.MEDIUM)` must be called at guard spawn — no engine default exists. `material_overlay` (not `material_override`) is the correct field for outline materials per GDD §Core Rules.

**Control Manifest Rules (Feature)**:
- No Feature-layer rules yet in the manifest; Foundation + Core rules apply globally.
- Required (Core — ADR-0006): Every `collision_layer`, `collision_mask`, or `PhysicsRayQueryParameters3D.collision_mask` reference MUST use `PhysicsLayers.*` constants. Bare integers are forbidden.
- Required (Foundation — ADR-0002): Signal subscribers connect in `_ready`, disconnect in `_exit_tree` with `is_connected` guards.
- Required (Presentation — ADR-0001): Call `OutlineTier.set_tier(mesh, OutlineTier.MEDIUM)` at spawn for the guard's `MeshInstance3D` child. Guards are tier MEDIUM (stencil value 2, 2.5 px @ 1080p).
- Forbidden: `material_override` on the guard's `MeshInstance3D` — use `material_overlay` only. `material_override` replaces the base albedo material.

---

## Acceptance Criteria

*From GDD `design/gdd/stealth-ai.md` §Core Rules + TR-SAI-001:*

- [ ] **AC-1**: `res://src/gameplay/stealth/guard.gd` declares `class_name Guard extends CharacterBody3D`. At `_ready()`, `collision_layer = PhysicsLayers.MASK_AI` and `collision_mask = PhysicsLayers.MASK_WORLD | PhysicsLayers.MASK_PLAYER` are set. No bare integer literals used.
- [ ] **AC-2**: The Guard scene (`res://src/gameplay/stealth/Guard.tscn`) has the following named children: `NavigationAgent3D`, `VisionCone: Area3D` (with `layer = 0`, `mask = PhysicsLayers.MASK_PLAYER | PhysicsLayers.MASK_AI`), `HearingPoller: Node`, `Perception: Node`, `DialogueAnchor: Node3D`, `OutlineTier: MeshInstance3D` (placeholder geometry). No occluder layers in the `VisionCone` mask.
- [ ] **AC-3**: `VisionCone` has a `SphereShape3D` collision shape with radius `VISION_MAX_RANGE_M` (default 18.0 m). The GDD specifies no `ConeShape3D` in Godot 4.6 — angle filtering is implemented via dot-product in `_on_vision_cone_body_entered`.
- [ ] **AC-4**: `_on_vision_cone_body_entered(body: Node3D)` rejects any body not in group `"player"` OR group `"dead_guard"` with an early return. A belt-and-braces typed class check (`body is PlayerCharacter` or `body is Guard`) follows the group check. Neither check issues any signal.
- [ ] **AC-5**: `OutlineTier.set_tier(mesh, OutlineTier.MEDIUM)` is called in `_ready()` on the guard's `MeshInstance3D` child. The mesh uses `material_overlay`, not `material_override`.
- [ ] **AC-6**: `@export var actor_id: StringName` is declared on `guard.gd` — the stable per-actor identity string used by Save/Load (ADR-0003 IG 6).
- [ ] **AC-7**: Unit test confirms a freshly instantiated `Guard` node has `current_alert_state == StealthAI.AlertState.UNAWARE` and both accumulators equal `0.0` at `_ready()` before any physics frame runs.

---

## Implementation Notes

*Derived from ADR-0006 + GDD §Core Rules:*

Recommended file structure (per GDD OQ-SAI-8):

```
src/gameplay/stealth/
├── stealth_ai.gd           (class_name StealthAI — enums; Story 002)
├── guard.gd                (class_name Guard extends CharacterBody3D)
├── Guard.tscn              (scene matching guard.gd)
├── perception.gd           (Story 003+)
├── raycast_provider.gd     (Story 003)
└── perception_cache.gd     (Story 003)
```

Forward axis in Godot 4.6: `-guard.global_transform.basis.z` (NOT `basis * Vector3.FORWARD` which points +X). The downward tilt reference vector per GDD is:
```gdscript
eye_forward = (-guard.global_transform.basis.z).rotated(
    guard.global_transform.basis.x,
    -deg_to_rad(VISION_CONE_DOWNWARD_ANGLE_DEG)
)
```
Accept if `eye_forward.dot((body.global_position - guard_eye_position).normalized()) >= cos(deg_to_rad(VISION_FOV_DEG / 2.0))`.

Zero-distance short-circuit (GDD E.18): if `(body.global_position - guard_eye_position).length() < 0.1`, accept unconditionally — dot product against a zero vector is undefined; at zero distance there is no reasonable stealth expectation.

`VisionCone.monitoring = false` does NOT synthetically emit `body_exited` for bodies currently inside (verified GDD §Core Rules 4th-pass correction). The `body_exited` handler must still early-return when `current_alert_state in [DEAD, UNCONSCIOUS]` as defense against same-frame emission races.

`NavigationAgent3D.target_position` is not `move_and_slide` — it sends a path-query request to the nav server's background thread. `is_navigation_finished()` becomes true on the NEXT physics frame after nav server sync, not the same frame. Guard movement calls `move_and_slide()` each physics frame only after checking `NavigationAgent3D.is_navigation_finished() == false`.

`HearingPoller` will implement poll-phase stagger via `get_instance_id() % 6` in its `_ready()` to spread co-spawned guards across the 6-frame polling period (Story 004+).

All exported gameplay values (e.g., `VISION_MAX_RANGE_M`, `VISION_FOV_DEG`, `VISION_CONE_DOWNWARD_ANGLE_DEG`) MUST be declared as `@export var` with defaults — data-driven per coding standards.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: `StealthAI` class with enums (`AlertState`, `AlertCause`, `Severity`, `TakedownType`) + signal declarations on `Events.gd`
- Story 003: `RaycastProvider` DI interface + `PerceptionCache` struct + `Perception` node initialization
- Story 004: F.1 sight fill formula implementation inside `_on_vision_cone_body_entered` + `HearingPoller` at 10 Hz
- Story 005: F.5 thresholds + combined score calculation + escalation/de-escalation logic
- Story 006: Patrol behavior (PatrolController) + state-driven movement dispatch
- Story 009: Forbidden-pattern CI grep gates (AC-SAI-3.12)
- Post-VS: `receive_takedown` / `receive_damage` implementation (no chloroform gadget in VS); UNCONSCIOUS/DEAD terminal states; wake-up clock; save/load serialisation of guard state

---

## QA Test Cases

**AC-1 — Guard physics layers**
- Given: `Guard.new()` instantiated in a test scene, `_ready()` has run
- When: `guard.collision_layer` and `guard.collision_mask` are read
- Then: `guard.collision_layer == PhysicsLayers.MASK_AI`; `guard.collision_mask == PhysicsLayers.MASK_WORLD | PhysicsLayers.MASK_PLAYER`
- Edge cases: bare integer literal (`collision_layer = 4`) → ADR-0006 forbidden pattern, test fails on grep check (Story 009)

**AC-2 — Child node presence**
- Given: `Guard.tscn` loaded and instantiated
- When: `guard.get_node_or_null("NavigationAgent3D")`, `guard.get_node_or_null("VisionCone")`, etc.
- Then: each child is non-null and typed correctly; `VisionCone` is `Area3D`; `HearingPoller` and `Perception` are `Node`
- Edge cases: renamed child → test fails clearly with missing-node assertion

**AC-3 — VisionCone shape radius**
- Given: `VisionCone` Area3D child of the guard
- When: `vision_cone.get_shape(0)` is read
- Then: the shape is `SphereShape3D` with `radius == guard.VISION_MAX_RANGE_M`
- Edge cases: wrong shape type (BoxShape3D, CapsuleShape3D) → test fails

**AC-4 — Body filter early return**
- Given: a test `Node3D` body NOT in group `"player"` or `"dead_guard"`
- When: `guard._on_vision_cone_body_entered(body)` is called directly
- Then: no signal emits, no accumulator change, method returns without processing
- Edge cases: body in both groups simultaneously → accepted (group union — should not occur in authoring but handled gracefully)

**AC-7 — Fresh instance state**
- Given: `Guard.new()` added to a test scene, `_ready()` called
- When: `guard.current_alert_state` and accumulator fields are read before any physics frame
- Then: `current_alert_state == StealthAI.AlertState.UNAWARE` (depends on Story 002 delivering StealthAI enums first); `_sight_accumulator == 0.0`, `_sound_accumulator == 0.0`
- Edge cases: editor-set default value persists → `_ready()` must reset regardless of `@export` defaults

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/feature/stealth_ai/guard_scaffold_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 must be DONE (needs `StealthAI.AlertState` enum for AC-7 assertion)
- Unlocks: Story 003 (Perception node init requires Guard scene to exist), Story 006 (PatrolController requires Guard)
