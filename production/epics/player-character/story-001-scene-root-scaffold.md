# Story 001: PlayerCharacter scene root scaffold

> **Epic**: Player Character
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2-3 hours (S — new scene + node hierarchy + enum host files)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/player-character.md`
**Requirements**: TR-PC-001, TR-PC-002, TR-PC-007
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006 (Collision Layer Contract)
**ADR Decision Summary**: Every gameplay script that touches `collision_layer`, `collision_mask`, `set_collision_layer_value()`, or `set_collision_mask_value()` MUST reference `PhysicsLayers.*` constants. Bare integer literals are forbidden. The PlayerCharacter sets its own layer on `LAYER_PLAYER` and masks against `MASK_WORLD | MASK_AI` in `_ready()` via the `set_collision_layer_value` / `set_collision_mask_value` helpers.

**Also references**: ADR-0002 (Signal Bus), ADR-0007 (Autoload Load Order Registry)

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `CharacterBody3D`, `CapsuleShape3D`, `class_name`, `@export`, and `PhysicsLayers` constant resolution are all stable Godot 4.0+. Jolt is the default 3D physics engine in Godot 4.6 (no project-level change required). ADR-0006 fully Accepted with all gates closed in Sprint 01. `set_collision_layer_value(index, true)` and `set_collision_mask_value(index, true)` use LAYER_* indices (not MASK_* values) — see Control Manifest Core Layer Required Patterns.

**Control Manifest Rules (Core)**:
- Required: every collision_layer/collision_mask assignment references `PhysicsLayers.*` constants — ADR-0006 IG 1
- Required: physics bodies set their OWN layer; they mask the layers they collide AGAINST — ADR-0006 IG 6
- Required: LAYER_* indices used with `set_collision_layer_value`; MASK_* values used with direct property assignment — ADR-0006 IG 3
- Forbidden: bare integer literals for collision_layer / collision_mask — pattern `hardcoded_physics_layer_number`

---

## Acceptance Criteria

*From GDD `design/gdd/player-character.md` §Detailed Design Core Rules + ADR-0006:*

- [ ] **AC-1**: `res://src/gameplay/player/player_enums.gd` exists with `class_name PlayerEnums extends RefCounted`, declares `enum MovementState { IDLE, WALK, SPRINT, CROUCH, JUMP, FALL, DEAD }` and `enum NoiseType { FOOTSTEP_SOFT, FOOTSTEP_NORMAL, FOOTSTEP_LOUD, JUMP_TAKEOFF, LANDING_SOFT, LANDING_HARD }`. No runtime logic — pure enum host.
- [ ] **AC-2**: `res://src/gameplay/player/noise_event.gd` exists with `class_name NoiseEvent extends RefCounted`, declaring fields `type: PlayerEnums.NoiseType`, `radius_m: float`, `origin: Vector3`. Doc comment on the class reads: "In-place mutation is intentional (zero-allocation at 80 Hz aggregate AI polling). Callers MUST copy fields before the next physics frame. DO NOT 'fix' this by allocating a new NoiseEvent per spike — see GDD F.4."
- [ ] **AC-3**: Scene `res://src/gameplay/player/PlayerCharacter.tscn` exists with `CharacterBody3D` as scene root, `class_name PlayerCharacter`, and the following direct children: `CapsuleShape3D` collider node (`CollisionShape3D` wrapper), `Camera3D` (at local Y 1.6 m), `ShapeCast3D` (for ceiling-check, standing dimensions), `HandAnchor` (`Node3D`, child of `Camera3D`).
- [ ] **AC-4**: In `_ready()`, Eve's CharacterBody3D sets `set_collision_layer_value(PhysicsLayers.LAYER_PLAYER, true)`, clears all other layer bits, then sets `set_collision_mask_value(PhysicsLayers.LAYER_WORLD, true)` and `set_collision_mask_value(PhysicsLayers.LAYER_AI, true)`. Zero bare integer literals for any collision layer or mask assignment.
- [ ] **AC-5**: `CapsuleShape3D` default shape dimensions in the scene file: `height = 1.7`, `radius = 0.3` (standing pose). The standing height IS the full collider height (not the cylinder portion). Comment in scene or script references GDD Core Rules "total capsule height including hemispherical caps".
- [ ] **AC-6**: `_physics_process(delta: float) -> void` exists on the PlayerCharacter script (stub body acceptable at this story's scope — movement, health, and noise are owned by later stories). The script declares `var current_state: PlayerEnums.MovementState = PlayerEnums.MovementState.IDLE` and `var velocity: Vector3 = Vector3.ZERO` at class scope with explicit types.

---

## Implementation Notes

*Derived from GDD §Detailed Design Core Rules + ADR-0006 §Implementation Guidelines:*

File structure created by this story:

```
src/gameplay/player/
├── PlayerCharacter.tscn       (CharacterBody3D root; stub script)
├── player_character.gd        (class_name PlayerCharacter; stub)
├── player_enums.gd            (class_name PlayerEnums; enum host only)
└── noise_event.gd             (class_name NoiseEvent; RefCounted, 3 fields)
```

Node hierarchy inside `PlayerCharacter.tscn`:
```
PlayerCharacter (CharacterBody3D)
├── CollisionShape3D           (CapsuleShape3D, height=1.7, radius=0.3)
├── ShapeCast3D                (ceiling check; shape CapsuleShape3D 1.7/0.3;
│                               target_position Vector3(0, 0.1, 0);
│                               collision_mask = PhysicsLayers.MASK_WORLD)
└── Camera3D                   (position.y = 1.6)
    └── HandAnchor (Node3D)
```

The `ShapeCast3D` node position is `Vector3.ZERO` (local) so it inherits the body's world origin automatically every frame — no manual repositioning needed. `force_shapecast_update()` must be called before reading `is_colliding()` (deferred to Story 003 crouch implementation, but node must be present in hierarchy now).

The `CollisionShape3D` wrapping `CapsuleShape3D` is the standard Godot 4.6 pattern — a standalone `CapsuleShape3D` resource does not attach directly to the scene tree.

Physics setup in `_ready()`:
```gdscript
func _ready() -> void:
    set_collision_layer_value(PhysicsLayers.LAYER_PLAYER, true)
    set_collision_mask_value(PhysicsLayers.LAYER_WORLD, true)
    set_collision_mask_value(PhysicsLayers.LAYER_AI, true)
```

`PlayerEnums` carries no runtime logic — it is a pure enum host. Neither enum is published on `Events.gd` (ADR-0002 IG 2 forbids non-signal types there). `NoiseEvent` is `RefCounted`, NOT a `Resource`, because Resource allocator overhead at 80 Hz aggregate AI polling is unacceptable (GDD §Detailed Design Core Rules — NoiseEvent).

This story establishes the scaffold that all subsequent PlayerCharacter stories build on. It does NOT implement any movement, health, noise, or interact logic.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: Camera look input (mouse + gamepad), pitch clamp, yaw, turn overshoot
- Story 003: Movement state machine, locomotion formulas, jump/fall, coyote time, crouch transition
- Story 004: NoiseEvent spike-latch implementation, get_noise_level(), get_noise_event(), get_silhouette_height()
- Story 005: Interact raycast, get_current_interact_target(), is_hand_busy(), player_interacted signal
- Story 006: Health system, apply_damage(), apply_heal(), player health signals
- Story 007: reset_for_respawn(), PlayerState serialization
- Story 008: FPS hands SubViewport + HandsOutlineMaterial

---

## QA Test Cases

**AC-1 — PlayerEnums file + enum members**
- Given: `res://src/gameplay/player/player_enums.gd` source
- When: a unit test loads the script and reflects on the class
- Then: `PlayerEnums.MovementState` enum exists with members {IDLE=0, WALK=1, SPRINT=2, CROUCH=3, JUMP=4, FALL=5, DEAD=6}; `PlayerEnums.NoiseType` enum exists with {FOOTSTEP_SOFT, FOOTSTEP_NORMAL, FOOTSTEP_LOUD, JUMP_TAKEOFF, LANDING_SOFT, LANDING_HARD}; no func, var, or const declarations beyond the enums (verify via property_list grep)
- Edge cases: missing enum member → access error; declared as inner class on PlayerCharacter → circular parse dependency

**AC-2 — NoiseEvent fields + doc comment**
- Given: `res://src/gameplay/player/noise_event.gd` source
- When: a unit test creates `NoiseEvent.new()`
- Then: instance has `type` (typed `PlayerEnums.NoiseType`), `radius_m: float`, `origin: Vector3` fields; source grep confirms "In-place mutation is intentional" comment is present at the class doc level
- Edge cases: declared as inner class on PlayerCharacter → cannot be forward-referenced from NoiseEvent itself (circular); typed as Resource → unacceptable allocator overhead documented in AC-2 comment

**AC-3 — Scene root hierarchy**
- Given: `res://src/gameplay/player/PlayerCharacter.tscn`
- When: a unit test instantiates the packed scene and inspects the node tree
- Then: root is `CharacterBody3D` with `class_name PlayerCharacter`; has `CollisionShape3D` child with `CapsuleShape3D` shape (height 1.7, radius 0.3); has `Camera3D` child at local position.y = 1.6 ± 0.001; `Camera3D` has `HandAnchor` (`Node3D`) child; has `ShapeCast3D` child with position == Vector3.ZERO
- Edge cases: missing ShapeCast3D → Story 003's ceiling check has no node to query; Camera3D at wrong height → eye-height sightline mismatch

**AC-4 — Collision layer setup uses PhysicsLayers constants**
- Given: a `PlayerCharacter` instance added to a test SceneTree
- When: `_ready()` runs
- Then: `has_collision_layer_value(PhysicsLayers.LAYER_PLAYER) == true`; `has_collision_mask_value(PhysicsLayers.LAYER_WORLD) == true`; `has_collision_mask_value(PhysicsLayers.LAYER_AI) == true`; source grep for bare integers (patterns `collision_layer = [0-9]`, `collision_mask = [0-9]`) returns zero matches in player_character.gd
- Edge cases: `set_collision_layer_value(LAYER_PLAYER, false)` mistakenly clears instead of sets → layer bitmask zero → player passes through world geometry

**AC-5 — Collider dimensions**
- Given: the `CollisionShape3D` child node in `PlayerCharacter.tscn`
- When: a test reads `(collision_shape.shape as CapsuleShape3D).height` and `.radius`
- Then: height == 1.7 ± 0.001; radius == 0.3 ± 0.001
- Edge cases: confusion between cylinder-portion height (GDD explicitly says 1.7 IS the total height including caps, per Godot 4.6 CapsuleShape3D semantics)

**AC-6 — PlayerCharacter script declares required variables**
- Given: `PlayerCharacter.new()` instance
- When: a test reads class properties
- Then: `current_state` exists and equals `PlayerEnums.MovementState.IDLE` at init; `velocity` exists and equals `Vector3.ZERO` at init; `_physics_process` method is present (verify via `has_method("_physics_process")`)
- Edge cases: untyped `var current_state` → fails static typing requirement

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/core/player_character/player_character_scaffold_test.gd` — must exist and pass (AC-1 through AC-6)
- Naming: `[system]_[scenario]_[expected]` convention per project test standards

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Signal Bus epic (Story 001 + 002 — `Events` autoload and player domain signals must be declared). ADR-0006 Accepted (all gates closed Sprint 01).
- Unlocks: Story 002 (camera look), Story 003 (movement state machine), Story 004 (noise interface), Story 005 (interact raycast), Story 006 (health system), Story 007 (respawn + serialization), Story 008 (FPS hands)
