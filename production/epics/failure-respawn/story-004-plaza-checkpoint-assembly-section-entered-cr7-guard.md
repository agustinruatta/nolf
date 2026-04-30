# Story 004: Plaza checkpoint assembly — section_entered handler + CR-7 IDLE guard + floor flag state machine (VS path)

> **Epic**: Failure & Respawn
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 2-3 hours (M — section_entered handler, Checkpoint assembly, IDLE guard, flag state machine)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/failure-respawn.md`
**Requirement**: TR-FR-006 (flag reset gated by `_flow_state == IDLE`), TR-FR-007 (checkpoint assembled at section entry from `player_respawn_point` Marker3D)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Save Format Contract) + ADR-0002 (Signal Bus + Event Taxonomy)
**ADR Decision Summary**: `FailureRespawnState` sub-resource is the serialized mirror of the live flag `_floor_applied_this_checkpoint: bool`, not its authoritative source. F&R reads the **live** member at step 9 (Story 005), not from the restored SaveGame. The `section_entered` handler must be gated by `_flow_state == IDLE` on all state-mutating branches — flag reset AND checkpoint overwrite are SKIPPED when `_flow_state != IDLE` (CR-7 guard prevents queued-respawn forward-section from overwriting `_current_checkpoint` mid-RESTORING). Per ADR-0002, `LevelStreamingService.TransitionReason` enum is owned by `LevelStreamingService`; F&R branches on it but does not redefine it.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `get_tree().current_scene.find_child("player_respawn_point", true, false)` (recursive=true, owned=false) is the lookup contract for the Plaza `Marker3D` per GDD CR-11. `find_child` is stable Godot 4.0+. `recursive=true, owned=false` is the explicit contract — forbids deferred-add-child patterns (section-validation CI enforces presence in the non-deferred tree). The Plaza section must contain a `Marker3D` named `"player_respawn_point"` for AC-9.1 to pass; section authoring is a coord item with Level Streaming story-008 (section authoring contract). `Checkpoint` resource lives at `src/gameplay/shared/checkpoint.gd` (not in F&R directory) to avoid PC → F&R load-order dependency.

**Control Manifest Rules (Feature)**:
- Required (Foundation/Signal Bus): `LevelStreamingService.TransitionReason` enum is owned by `LevelStreamingService` — use qualified name in `section_entered` handler branching; do NOT redefine on F&R — ADR-0002 IG 2
- Required (Foundation/Save-Load): per-actor identity (checkpoint node lookup) uses stable node-name string, not `NodePath` from a saved Resource — ADR-0003 IG 6
- Forbidden: overwriting `_current_checkpoint` or resetting `_floor_applied_this_checkpoint` when `_flow_state != IDLE` — CR-7 IDLE guard violation

---

## Acceptance Criteria

*From GDD `design/gdd/failure-respawn.md` CR-7, CR-11, F.1, E.3, E.10; TR-FR-006, TR-FR-007; AC-FR-5.1–5.5, AC-FR-9.1–9.2:*

- [ ] **AC-1**: GIVEN a section scene containing a `Marker3D` named `"player_respawn_point"` at world position `(10.0, 0.5, -5.0)`, WHEN `Events.section_entered(section_id, TransitionReason.FORWARD)` fires AND `_flow_state == IDLE`, THEN `_current_checkpoint` is non-null AND `_current_checkpoint.respawn_position` is within `0.01 m` of `(10.0, 0.5, -5.0)`.
- [ ] **AC-2**: GIVEN a section scene with no `"player_respawn_point"` node, WHEN `Events.section_entered` fires, THEN F&R calls `push_error` with a message identifying the missing node AND `_current_checkpoint` retains its previous value (not overwritten with null).
- [ ] **AC-3**: GIVEN `_flow_state == IDLE` AND `section_entered(section_id, TransitionReason.FORWARD)` fires, THEN the live `_floor_applied_this_checkpoint` is reset to `false` (fresh checkpoint — the next death in this section may apply the floor once per F.1).
- [ ] **AC-4**: GIVEN `_floor_applied_this_checkpoint == true` AND `section_entered(section_id, TransitionReason.RESPAWN)` fires (regardless of `_flow_state`), THEN `_floor_applied_this_checkpoint` remains `true` (RESPAWN transition must NOT reset the flag — re-opens the farm loop if it did).
- [ ] **AC-5**: GIVEN `_flow_state == RESTORING` AND `section_entered(section_id, TransitionReason.FORWARD)` fires (queued-respawn scenario per CR-10 / GDD E.3), THEN `_current_checkpoint` is NOT overwritten AND `_floor_applied_this_checkpoint` is NOT reset (CR-7 IDLE guard on state-mutating branches).
- [ ] **AC-6**: GIVEN `_flow_state == IDLE` AND `section_entered` fires with an unrecognized `TransitionReason` value, THEN `push_warning` is called with a message containing the unrecognized reason AND the live flag is preserved (conservative-on-anti-farm default per F.1 forward-compatibility row).
- [ ] **AC-7**: GIVEN `section_entered(section_id, TransitionReason.NEW_GAME)` fires AND `_flow_state == IDLE`, THEN `_current_checkpoint` is assembled from the section's `"player_respawn_point"` AND `_floor_applied_this_checkpoint` is reset to `false` (same behavior as FORWARD).
- [ ] **AC-8**: `_current_section_id` (used by Story 003's emit) is updated to `section_id` when `section_entered` fires with `reason in [FORWARD, NEW_GAME, LOAD_FROM_SAVE]` AND `_flow_state == IDLE`.

---

## Implementation Notes

*Derived from GDD CR-7, CR-11, F.1:*

**`_on_section_entered` handler structure**:

```gdscript
func _on_section_entered(section_id: StringName, reason: LevelStreamingService.TransitionReason) -> void:
    if _flow_state != FlowState.IDLE:
        # CR-7 IDLE guard: only dispatch RESPAWN path; all state-mutating work is SKIPPED.
        # Story 005 handles the RESPAWN dispatch inside _on_ls_restore (step 9 callback path).
        return
    # _flow_state == IDLE: safe to mutate state.
    match reason:
        LevelStreamingService.TransitionReason.FORWARD, \
        LevelStreamingService.TransitionReason.NEW_GAME, \
        LevelStreamingService.TransitionReason.LOAD_FROM_SAVE:
            _current_section_id = section_id
            _floor_applied_this_checkpoint = false  # F.1 row 1: fresh checkpoint
            _assemble_checkpoint_from_scene()
        LevelStreamingService.TransitionReason.RESPAWN:
            pass  # No-op in IDLE: RESPAWN fires only during RESTORING (unreachable here in normal play)
        _:
            push_warning("FailureRespawn: unrecognized TransitionReason %s — live flag preserved" % reason)
            # Conservative: preserve _floor_applied_this_checkpoint; do NOT reset
```

**`_assemble_checkpoint_from_scene()` private method**:

```gdscript
func _assemble_checkpoint_from_scene() -> void:
    var scene: Node = get_tree().current_scene
    if scene == null:
        push_error("FailureRespawn: no current_scene when assembling checkpoint")
        return
    var marker: Node = scene.find_child("player_respawn_point", true, false)
    if marker == null or not (marker is Marker3D):
        push_error("FailureRespawn: 'player_respawn_point' Marker3D not found in section scene — _current_checkpoint unchanged")
        return
    var cp: Checkpoint = Checkpoint.new()
    cp.respawn_position = (marker as Marker3D).global_position
    _current_checkpoint = cp
```

**CR-7 IDLE guard critical invariant**: the guard `if _flow_state != IDLE: return` is the primary defense against the queued-respawn overwrite defect (GDD CR-10). Under queued respawn (CR-10), a forward-section `section_entered(FORWARD)` can arrive while `_flow_state == RESTORING`. Without the IDLE guard, `_current_checkpoint` would be overwritten with the forward section's marker and Eve would teleport to the wrong respawn point. The guard must be the FIRST check in `_on_section_entered` (before any branching on `reason`).

**Floor flag transition state machine (VS scope)**: in the VS, `respawn_floor_used` stays `false` because there is no ammo in VS (no Inventory system yet). The flag state machine is still wired correctly per F.1:
- `FORWARD` → reset to `false` (AC-3)
- `RESPAWN` → unchanged (AC-4)
- `RESTORING` state guard → no mutation (AC-5)

The actual floor APPLICATION happens in Story 005 (step-9 callback). This story only manages the flag's state transitions.

**Checkpoint shared class location**: `src/gameplay/shared/checkpoint.gd` declares `class_name Checkpoint extends Resource` with `@export var respawn_position: Vector3 = Vector3.ZERO`. This file is scaffolded in Story 001 if not already created. The `Checkpoint` type must live in `src/gameplay/shared/` — NOT inside `src/gameplay/failure_respawn/` — to avoid a `PlayerCharacter` → `FailureRespawn` load-order dependency (PC must be able to `import Checkpoint` without implying F&R is loaded first).

**Plaza section authoring requirement**: the Plaza section scene must contain a `Marker3D` named `"player_respawn_point"` as a non-deferred child of the section root (not added via `call_deferred` or `add_child.call_deferred`). This is a Mission Scripting coord item (GDD CR-11 provisional). For the VS, the Plaza stub scene created in Level Streaming story-008 must include this marker. If the marker is absent, AC-2 fires `push_error` and `_current_checkpoint` stays at its previous value (null at boot = E.9 edge case handled by Story 005).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: autoload scaffold, signal subscription wiring
- Story 002: CAPTURING body — SaveGame assembly, `save_to_slot`, in-memory handoff
- Story 003: `respawn_triggered` emission, signal ordering
- Story 005: step-9 restore callback body — ammo floor application, `PC.reset_for_respawn`, InputContext pop, RESTORING → IDLE
- Story 006: forbidden pattern CI lints
- Multi-checkpoint progression within a section (deferred post-VS: Mission Scripting extension point per GDD CR-11 PROVISIONAL)
- Combat-driven `section_entered(LOAD_FROM_SAVE)` hydration of the live flag from SaveGame (Story 005 handles the full load-path hydration)

---

## QA Test Cases

**AC-1 — Checkpoint assembly from scene Marker3D**
- Given: a test scene with a `Marker3D` child named `"player_respawn_point"` at `(10, 0.5, -5)` set as `current_scene` on the SceneTree
- When: `Events.section_entered.emit(&"plaza", LevelStreamingService.TransitionReason.FORWARD)` fires AND `_flow_state == FlowState.IDLE`
- Then: `_current_checkpoint != null`; `_current_checkpoint.respawn_position.distance_to(Vector3(10, 0.5, -5)) < 0.01`
- Edge cases: `Marker3D` has a Transform3D offset from a parent node — `global_position` (not `position`) must be used

**AC-2 — Missing player_respawn_point logs error and preserves checkpoint**
- Given: a test scene with no `"player_respawn_point"` node; `_current_checkpoint` pre-set to a non-null `Checkpoint` stub
- When: `section_entered` fires
- Then: `push_error` called with message containing `"player_respawn_point"`; `_current_checkpoint` unchanged (still the non-null stub)
- Edge cases: node named `"PlayerRespawnPoint"` (wrong case) — `find_child` is case-sensitive; push_error must still fire

**AC-3 — FORWARD transition resets floor flag**
- Given: `_floor_applied_this_checkpoint = true`; `_flow_state == FlowState.IDLE`
- When: `section_entered(&"plaza", TransitionReason.FORWARD)` fires
- Then: `_floor_applied_this_checkpoint == false`

**AC-4 — RESPAWN transition preserves floor flag**
- Given: `_floor_applied_this_checkpoint = true`; `_flow_state == FlowState.IDLE` (unreachable in normal play but testable)
- When: `section_entered(&"plaza", TransitionReason.RESPAWN)` fires
- Then: `_floor_applied_this_checkpoint == true` (unchanged)

**AC-5 — IDLE guard blocks state mutation during RESTORING**
- Given: `_flow_state = FlowState.RESTORING` (forced); `_current_checkpoint` is a pre-set stub; `_floor_applied_this_checkpoint = false`
- When: `section_entered(&"plaza", TransitionReason.FORWARD)` fires
- Then: `_current_checkpoint` is unchanged (still the pre-set stub); `_floor_applied_this_checkpoint == false` (unchanged — no reset attempt while RESTORING)

**AC-6 — Unrecognized TransitionReason logs warning and preserves flag**
- Given: a future `TransitionReason` value not in the current enum (inject via `int` cast); `_floor_applied_this_checkpoint = false`
- When: `section_entered` fires with the unrecognized reason
- Then: `push_warning` called with message containing the unrecognized reason; `_floor_applied_this_checkpoint` still `false`

**AC-7 — NEW_GAME resets flag and assembles checkpoint**
- Given: `_floor_applied_this_checkpoint = true`; valid `"player_respawn_point"` in scene
- When: `section_entered(&"plaza", TransitionReason.NEW_GAME)` fires AND `_flow_state == FlowState.IDLE`
- Then: `_floor_applied_this_checkpoint == false`; `_current_checkpoint != null`

**AC-8 — _current_section_id is updated on FORWARD/NEW_GAME/LOAD_FROM_SAVE**
- Given: `_current_section_id == &"old_section"`
- When: `section_entered(&"plaza", TransitionReason.FORWARD)` fires
- Then: `_current_section_id == &"plaza"`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/feature/failure_respawn/checkpoint_assembly_test.gd` — must exist and pass (AC-1, AC-2, AC-5, AC-7)
- `tests/unit/feature/failure_respawn/floor_flag_state_machine_test.gd` — must exist and pass (AC-3, AC-4, AC-6, AC-8)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (autoload scaffold + signal subscriptions) MUST be Done; Level Streaming story-008 (Plaza section authoring contract — `player_respawn_point` Marker3D) for AC-1 VS integration
- Unlocks: Story 005 (restore callback uses `_current_checkpoint` to call `PC.reset_for_respawn`; floor flag transitions are prerequisites for the step-9 apply logic)
