# Story 007: Respawn contract + PlayerState serialization

> **Epic**: Player Character
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2-3 hours (M — ordered reset, PlayerState resource, round-trip test)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/player-character.md`
**Requirements**: TR-PC-019, TR-PC-020
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Save Format Contract)
**ADR Decision Summary**: `PlayerState` is a typed `Resource` sub-resource on `SaveGame` — it MUST be declared as a top-level `class_name`-registered class in its own file under `src/core/save_load/states/` (Sprint 01 verification finding F2: inner-class typed Resources come back `null` after load). Fields: `position: Vector3`, `rotation: Vector3`, `health: int`, `current_state: int` (enum value). No stamina field (pillar decision). Per-actor identity uses `actor_id: StringName` if needed for future multi-checkpoint disambiguation. Save-Load epic Story 001 already scaffolds this file; this story populates it correctly and verifies the round-trip from PlayerCharacter's side.

**Also references**: ADR-0002 (Signal Bus) for `player_health_changed` emit on respawn reset.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Resource.duplicate_deep()` for nested resource isolation is available in Godot 4.6 (confirmed Sprint 01 verification gate). `ResourceSaver.save()` + `ResourceLoader.load()` for `PlayerState` round-trip is stable Godot 4.x. `Tween.kill()` is synchronous in Godot 4.x — `_is_hand_busy` cleared in the same frame that calls `kill()`.

**Control Manifest Rules (Foundation)**:
- Required: `PlayerState` must be top-level `class_name`-registered in its own file (ADR-0003 IG 11)
- Required: no `NodePath` or `Node` references in saved Resources (ADR-0003 IG 6)
- Required: `reset_for_respawn()` ordered reset: noise latch → state → hand busy → health → position/rotation → emit (GDD §Detailed Design §Respawn contract)
- Forbidden: `direct_position_assignment_during_respawn` — use `reset_for_respawn()` ordered API only
- Forbidden: stamina field in `PlayerState` (rejected in Pillar 5)

---

## Acceptance Criteria

*From GDD `design/gdd/player-character.md` §Acceptance Criteria AC-6, AC-8 + §Respawn contract:*

- [ ] **AC-6.1 [Logic]** **Same-frame reset invariants**: within the SAME physics frame in which `reset_for_respawn(stub_checkpoint)` is called from DEAD state, ALL of the following hold BEFORE any subsequent `_physics_process` tick:
  - `health == max_health`
  - `current_state == PlayerEnums.MovementState.IDLE`
  - `is_hand_busy() == false`
  - `get_noise_event() == null` (latch cleared synchronously)
  - `global_transform.origin.distance_to(stub_checkpoint.respawn_position) < 0.001 m`
  - `player_health_changed(max_health, max_health)` has emitted exactly once
- [ ] **AC-6.2 [Logic]** **DEAD-state latch clearance at respawn**: after `apply_damage` kills Eve (state → DEAD), then `reset_for_respawn()` is called, `get_noise_event()` returns `null` on the next `_physics_process` tick. The latch clear in `reset_for_respawn()` is independent of (and in addition to) the `apply_damage` DEAD-state latch clear.
- [ ] **AC-6-ordering [Logic]** **Respawn ordering invariant**: `_latched_event` is set to `null` BEFORE `current_state = IDLE`; `_is_hand_busy` is set to `false` BEFORE `Tween.kill()` on any in-flight interact tween; `health = max_health` is set BEFORE `global_transform.origin = checkpoint.respawn_position`; `player_health_changed` is emitted LAST (after all state fields are restored). A test that reads each field immediately after the `reset_for_respawn()` call confirms each invariant holds in the documented order.
- [ ] **AC-8.1 [Logic]** `PlayerState` resource round-trip: populate `PlayerState` with `position = Vector3(5.0, 1.0, -3.0)`, `rotation = Vector3(0.0, 1.5708, 0.0)`, `health = 75`, `current_state = PlayerEnums.MovementState.CROUCH` (int value 3). Save via `ResourceSaver.save(state, "user://test_player_state.res", FLAG_COMPRESS)`. Load via `ResourceLoader.load(...)`. Assert: `loaded.position.distance_to(original.position) < 0.001`; `loaded.rotation` component-wise `±0.001 rad`; `loaded.health == 75`; `loaded.current_state == 3`; no `stamina` field present.

---

## Implementation Notes

*Derived from GDD §Detailed Design §Respawn contract + ADR-0003 §Implementation Guidelines:*

**`reset_for_respawn()` ordered reset** (from GDD, ordering is load-bearing):
```gdscript
func reset_for_respawn(checkpoint: Resource) -> void:
    # 1. Clear noise latch — must be before IDLE so AI polling this frame
    #    reads null rather than a stale spike from the death sequence.
    _latched_event = null
    _latch_frames_remaining = 0
    # 2. Reset movement state
    current_state = PlayerEnums.MovementState.IDLE
    velocity = Vector3.ZERO
    # 3. Clear hand busy — flag-first before Tween.kill() (kill() suppresses tween_finished)
    _is_hand_busy = false
    if _interact_tween != null and _interact_tween.is_valid():
        _interact_tween.kill()
    # 4. Restore health
    health = max_health
    # 5. Teleport — direct position assignment is only valid here (this is the ordered reset API)
    global_transform.origin = checkpoint.respawn_position
    rotation.y = checkpoint.respawn_rotation.y  # yaw only; pitch/roll always 0 on respawn
    # 6. Emit exactly once — last, after all state is restored
    Events.player_health_changed.emit(float(max_health), float(max_health))
```

The `# direct position assignment is only valid here` comment is load-bearing documentation: the Forbidden Pattern `direct_position_assignment_during_respawn` refers to bypassing this API. The only valid position assignment in the codebase is inside `reset_for_respawn()`.

`Checkpoint` is a forward dependency (Failure & Respawn GDD). Until that GDD lands, `reset_for_respawn()` accepts `Resource` as its parameter type with a `## checkpoint: Resource with respawn_position: Vector3, respawn_rotation: Vector3` doc comment. Stub `Checkpoint` resource used in tests.

**`PlayerState` resource** (file already scaffolded by Save-Load epic Story 001; this story verifies correctness):
- File: `res://src/core/save_load/states/player_state.gd`
- Fields: `@export var position: Vector3`, `@export var rotation: Vector3`, `@export var health: int`, `@export var current_state: int`
- No stamina field, per Pillar 5 decision
- Class-level doc comment references "PlayerEnums.MovementState — `current_state` stores the enum int value, not the string"

**Collecting state for save** (Save-Load epic assembles the `SaveGame`; PlayerCharacter provides the data):
```gdscript
func get_player_state() -> PlayerState:
    var state := PlayerState.new()
    state.position = global_transform.origin
    state.rotation = Vector3(0.0, rotation.y, 0.0)  # yaw only; pitch/roll always reset
    state.health = health
    state.current_state = current_state as int
    return state
```

**Restoring from save** (called by Save-Load service after a section transition load):
```gdscript
func load_player_state(state: PlayerState) -> void:
    global_transform.origin = state.position
    rotation.y = state.rotation.y
    health = state.health
    current_state = state.current_state as PlayerEnums.MovementState
    Events.player_health_changed.emit(float(health), float(max_health))
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: `PlayerState` file creation (Save-Load epic Story 001 already scaffolded it)
- Story 003: Dead-state camera animation (800 ms pitch-down) — movement story owns that
- Story 006: `apply_damage` lethal path clearing `_latched_event` at death (not at respawn)
- Failure & Respawn epic: fade sequence, Checkpoint type definition, AI reset after respawn
- Save-Load epic Stories 002-004: `SaveLoadService` file I/O, slot scheme, `duplicate_deep()` discipline

---

## QA Test Cases

**AC-6.1 — Same-frame reset invariants**
- Given: `PlayerCharacter` in DEAD state; `health = 0`; `_latched_event` non-null (JUMP_TAKEOFF spike)
- When: `reset_for_respawn(stub_checkpoint)` called; all assertions made on the same stack frame BEFORE yielding to next physics tick
- Then: all 6 invariants hold simultaneously: health == max_health, state == IDLE, is_hand_busy == false, get_noise_event() == null, origin within 0.001 m of respawn_position, player_health_changed emitted once
- Edge cases: respawn called while interact tween is in-flight → tween killed, _is_hand_busy false, all other invariants still hold

**AC-6.2 — Latch cleared after respawn (independent of death clear)**
- Given: `apply_damage(999)` kills Eve; respawn is called immediately on next tick
- When: read `get_noise_event()` after respawn call
- Then: `null` returned; even if `apply_damage` had already cleared it, the respawn clears it again safely (idempotent clear)
- Edge cases: respawn called without prior death (e.g., teleport from Mission Scripting) → still clears latch safely

**AC-6-ordering — Respawn field ordering**
- Given: instrumented version of `reset_for_respawn()` recording the frame at which each field is mutated
- When: `reset_for_respawn()` runs
- Then: mutation order matches specification exactly: noise latch → state → hand_busy + tween_kill → health → position → player_health_changed emit. Test uses a sequential assertion: assert that reading each field after the prior field's mutation and before the next field's mutation shows the expected intermediate value
- Edge cases: `player_health_changed` emitted before `health = max_health` → HUD would show stale health value; test catches this reordering

**AC-8.1 — PlayerState round-trip**
- Given: `PlayerState.new()` populated with known values
- When: `ResourceSaver.save(state, "user://test_player_state.res", FLAG_COMPRESS)` then `var loaded = ResourceLoader.load(...) as PlayerState`
- Then: all 4 fields bit-equal (position within 0.001 m, rotation within 0.001 rad, health exact int, current_state exact int); no `stamina` field in `get_property_list()`; test cleanup deletes `user://test_player_state.res` in teardown
- Edge cases: `current_state` stored as int (not enum name string) — `loaded.current_state == 3` not `== "CROUCH"`; `PlayerState` declared as inner class → `loaded == null` (Sprint 01 finding F2)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/core/player_character/player_reset_for_respawn_test.gd` — must pass (AC-6.1, AC-6.2, AC-6-ordering)
- `tests/unit/core/player_character/player_serialization_test.gd` — must pass (AC-8.1)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (scene root scaffold), Story 004 (`_latched_event` + `_latch_frames_remaining` fields), Story 005 (`_is_hand_busy` + `_interact_tween` fields), Story 006 (`health`, `max_health` fields). Save-Load epic Story 001 (PlayerState file scaffolded).
- Unlocks: Failure & Respawn epic (consumes `reset_for_respawn()` API), Save-Load epic Story 004 (`duplicate_deep()` discipline for PlayerState in SaveGame)
