# Story 005: Interact raycast + query API

> **Epic**: Player Character
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 2-3 hours (M — F.5 iterative raycast, is_hand_busy, player_interacted signal, pre-reach pause tween)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/player-character.md`
**Requirements**: TR-PC-008, TR-PC-009
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006 (Collision Layer Contract), ADR-0002 (Signal Bus + Event Taxonomy)
**ADR Decision Summary**: Interact raycast uses `PhysicsRayQueryParameters3D.collision_mask = PhysicsLayers.MASK_INTERACT_RAYCAST` — raycasts have no layer (they are not collision bodies), so only `collision_mask` is set. `LAYER_INTERACTABLES` bodies have `collision_layer = MASK_INTERACTABLES` but `collision_mask = 0` — they participate in raycasts but do NOT block movement. `player_interacted` signal is emitted through `Events` autoload (ADR-0002). `query.exclude` mutation after `create()` is live in Godot 4.6 — appending between `intersect_ray` calls IS reflected in the next query call.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `get_world_3d().direct_space_state.intersect_ray(query)` and `PhysicsRayQueryParameters3D.create()` are stable Godot 4.x. `query.exclude` backing array is exposed by reference in 4.6 (confirmed per `docs/engine-reference/godot/modules/physics.md` Raycasting section). `Tween` for the pre-reach pause and reach animation is stable Godot 4.0+. GDScript `INT32_MAX = 2147483647` sentinel because GDScript has no `INT_MAX` constant.

**Control Manifest Rules (Core)**:
- Required: `collision_mask` only for raycasts (no layer — ADR-0006 IG 7)
- Required: `PhysicsLayers.MASK_INTERACT_RAYCAST` constant — no bare integer literals
- Required: `player_interacted` signal emitted via `Events.player_interacted.emit(target)` (ADR-0002 direct emit)
- Forbidden: `OutlineTier.set_tier` called from interact resolution (outline is HUD Core concern)
- Forbidden: `is_hand_busy()` gating the raycast (raycast always resolves; only the E-press action and HUD prompt check `is_hand_busy()`)

---

## Acceptance Criteria

*From GDD `design/gdd/player-character.md` §Acceptance Criteria AC-4:*

- [ ] **AC-4.1 [Logic]** With a stub Document (priority 0, `get_interact_priority() → 0`) and a stub Door (priority 3, `get_interact_priority() → 3`) both on `LAYER_INTERACTABLES` within 2.0 m of the camera, `_resolve_interact_target()` returns the Document regardless of their geometric order along the ray.
- [ ] **AC-4.2 [Logic]** **Cap-exceeded warning**: with `raycast_max_iterations + 1` stacked interactables, `_resolve_interact_target()` emits `push_warning` exactly once (captured via GUT's `assert_warned` helper) AND returns the best candidate within the iteration cap (no crash, no null return if a valid target exists).
- [ ] **AC-4.3 [Integration]** E-press flow: the HUD-highlighted object each physics frame matches `_resolve_interact_target()` (HUD-coherence — same resolver powers both the E-press and the HUD query); `is_hand_busy()` is `true` for `interact_pre_reach_ms + interact_reach_duration_ms ± 10 ms` after E is pressed; `player_interacted` fires exactly once on reach complete, with the correct target Node3D as payload.
- [ ] **AC-interact-query [Logic]** `get_current_interact_target()` returns the same node as `_resolve_interact_target()` when called from outside the class. `is_hand_busy()` returns `true` during the pre-reach and reach window; `false` before E is pressed and after `player_interacted` fires.
- [ ] **AC-edge-e4 [Logic]** E.4 (interact during interact): a second E-press during `is_hand_busy() == true` is swallowed — `player_interacted` fires exactly once for the in-flight interaction; no double-pickup. `is_hand_busy()` stays `true` for the remaining window.
- [ ] **AC-edge-e11 [Logic]** E.11 (target destroyed mid-reach): if the interact target node is freed before the reach animation completes, `player_interacted` fires with `target = null` (not with an invalid node reference). `is_hand_busy()` is set to false on the same tick.

---

## Implementation Notes

*Derived from GDD §Formulas F.5 + §Detailed Design §Context-sensitive interact + §Edge Cases E.4, E.11:*

**F.5 Iterative interact raycast**:
```gdscript
func _resolve_interact_target() -> Node3D:
    var space_state := get_world_3d().direct_space_state
    var ray_origin: Vector3 = _camera.global_position
    var ray_end: Vector3 = ray_origin + (-_camera.global_transform.basis.z * interact_ray_length)
    var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
    query.collision_mask = PhysicsLayers.MASK_INTERACT_RAYCAST
    query.exclude = []
    var best_node: Node3D = null
    var best_priority: int = 2147483647   # INT32_MAX sentinel
    var best_distance_sq: float = INF
    var hit_count: int = 0
    for _i in raycast_max_iterations:
        var hit: Dictionary = space_state.intersect_ray(query)
        if hit.is_empty():
            break
        hit_count += 1
        var collider: Node3D = hit.collider
        if not collider.has_method("get_interact_priority"):
            query.exclude.append(hit.rid)
            continue
        var priority: int = collider.get_interact_priority()
        var distance_sq: float = ray_origin.distance_squared_to(hit.position)
        if priority < best_priority or (priority == best_priority and distance_sq < best_distance_sq):
            best_priority = priority
            best_distance_sq = distance_sq
            best_node = collider
        query.exclude.append(hit.rid)
    if hit_count == raycast_max_iterations:
        push_warning("interact raycast hit iteration cap (%d); a higher-priority interactable may be beyond the cap" % raycast_max_iterations)
    return best_node
```

`_resolve_interact_target()` is called each `_physics_process` tick and the result is cached as `_current_interact_target: Node3D`. `get_current_interact_target()` returns this cached value. This ensures HUD and E-press see the same target (HUD-coherence guarantee).

**Interact priority constants** live in `res://src/gameplay/interactables/interact_priority.gd`:
```gdscript
class_name InteractPriority
enum Kind { DOCUMENT = 0, TERMINAL = 1, PICKUP = 2, DOOR = 3 }
```
PlayerCharacter never changes. Adding a new interactable type = append to the enum + implement `get_interact_priority()` on the new class.

**E-press handling**:
- On `Input.is_action_just_pressed("interact")` in `_physics_process`: if `_is_hand_busy` → swallow (E.4). Otherwise: set `_is_hand_busy = true`, start `interact_pre_reach_ms` Tween, then on tween complete start `interact_reach_duration_ms` Tween, then on reach complete: if `is_instance_valid(_current_interact_target)` → emit `Events.player_interacted.emit(_current_interact_target)`; else emit `Events.player_interacted.emit(null)` (E.11). Set `_is_hand_busy = false` in the same stack frame as the emit.

**E.6 damage-cancel integration point** (Story 006): `apply_damage()` checks if `amount >= interact_damage_cancel_threshold`; if so, sets `_is_hand_busy = false` in the same method call that kills the reach Tween — never in a `tween_finished` callback. Stub call site can be left as a TODO comment for Story 006 to implement.

**Sprint disabled during interact window**: in `_physics_process`, if `_is_hand_busy` and current state == SPRINT, the movement system caps speed to `walk_speed` (Story 003 coordination — `is_hand_busy()` is readable from the movement update).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: Camera look input (raycast uses `_camera.global_position` + forward; camera must exist)
- Story 006: Damage-cancellation of in-flight interact (E.6); `apply_damage` `interact_damage_cancel_threshold` check
- Story 007: `reset_for_respawn()` clearing `_is_hand_busy` (E.13 — dead-state interact cancel)

---

## QA Test Cases

**AC-4.1 — Priority resolver returns Document over Door**
- Given: stub Document (`get_interact_priority() → 0`) and stub Door (`get_interact_priority() → 3`) placed on `LAYER_INTERACTABLES`; both within 2.0 m of camera; Door geometrically closer
- When: `_resolve_interact_target()` called
- Then: returns the Document (priority 0 < priority 3 regardless of distance)
- Edge cases: two Documents at different distances → nearer one returned (same-priority distance tie-break); two Documents at equal distance → first-encountered returned (documented undefined-but-stable outcome)

**AC-4.2 — Cap-exceeded push_warning**
- Given: `raycast_max_iterations = 4`; 5 stub interactables stacked in a row
- When: `_resolve_interact_target()` called
- Then: GUT `assert_warned` captures exactly one `push_warning` call; return value is non-null (best candidate within 4 iterations)
- Edge cases: cap == 1 with 2 stacked → warning fires on first call; best-within-cap is still returned

**AC-4.3 — E-press flow integration**
- Given: `PlayerCharacter` in test SceneTree; one stub interactable (Document) within 2.0 m
- When: `Input.parse_input_event(InputEventAction{ action = "interact", pressed = true })` injected; simulate `interact_pre_reach_ms + interact_reach_duration_ms + 50 ms` of physics ticks
- Then: `is_hand_busy()` returns `true` from E-press until reach completes; `player_interacted` emits exactly once with the Document as payload; `is_hand_busy()` returns `false` after emit
- Edge cases: stub Document freed mid-reach → `player_interacted` fires with `null` (E.11); second E-press during window → swallowed (E.4)

**AC-interact-query — get_current_interact_target coherence**
- Given: stub Document within range
- When: `_physics_process` runs (resolves target); then `get_current_interact_target()` called from external caller
- Then: returns same node as `_resolve_interact_target()` would return; confirms HUD-coherence guarantee
- Edge cases: no interactable in range → returns `null`

**AC-edge-e4 — Double E-press swallowed**
- Given: E-press in flight (`_is_hand_busy == true`); second E-press injected
- When: physics ticks advance to complete the first interaction
- Then: `player_interacted` fires exactly once; no duplicate animation; `is_hand_busy()` becomes false exactly once

**AC-edge-e11 — Target freed mid-reach**
- Given: interact E-press started with stub Document in range
- When: stub Document node freed via `queue_free()` before reach animation completes; ticks advance to reach complete
- Then: `player_interacted` fires with `target = null` (not a freed node reference); `is_hand_busy()` returns false
- Edge cases: `is_instance_valid(_current_interact_target)` check must be performed in the reach-complete callback, not at E-press time

---

## Test Evidence

**Story Type**: Integration (AC-4.3 requires SceneTree + Input injection + Tween)
**Required evidence**:
- `tests/unit/core/player_character/player_interact_priority_test.gd` — must pass (AC-4.1)
- `tests/unit/core/player_character/player_interact_cap_warning_test.gd` — must pass (AC-4.2)
- `tests/integration/core/player_character/player_interact_flow_test.gd` — must pass (AC-4.3, AC-interact-query, AC-edge-e4, AC-edge-e11)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (scene root + Camera3D node), Story 002 (camera look — `_camera.global_position` and forward basis), Story 003 (sprint-disabled-during-interact requires `current_state` from movement)
- Unlocks: HUD Core epic (`get_current_interact_target()` + `is_hand_busy()` query contract), Document Collection epic (`player_interacted` with Document target), Story 006 (damage-cancel E.6 coordination)
