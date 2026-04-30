# Story 005: LS step-9 restore callback + PlayerCharacter.reset_for_respawn + InputContext push/pop — VS end-to-end respawn beat

> **Epic**: Failure & Respawn
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 4-5 hours (L — restore callback body, InputContext push/pop, PC reset call, round-trip integration test, visual evidence)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/failure-respawn.md`
**Requirement**: TR-FR-005 (respawn floor via live-authoritative read at LS step-9), TR-FR-009 (InputContext.LOADING push/pop), TR-FR-011 (queued-respawn tolerance; `respawn_triggered` fires exactly once), TR-FR-012 (watchdog: push_error if RESTORING > 2.5 s), TR-FR-013 (mechanical flow ~0.58 s; perceived ~2.2 s with Audio fade)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Save Format Contract) + ADR-0007 (Autoload Load Order Registry) + ADR-0008 (Performance Budget Distribution)
**ADR Decision Summary**: F&R claims share of the 0.8 ms residual pool (ADR-0008 Slot 8 — event-driven, no per-frame work outside the death event). `InputContext.LOADING` push at step 2 / pop at step 13 uses ADR-0004 true-stack semantics (F&R and LS push/pop independently; the stack resolves correctly via symmetrical pairs). At LS step-9, F&R's restore callback fires synchronously: F&R reads the **live** `_floor_applied_this_checkpoint` (NOT from the restored SaveGame — CR-6 live-authoritative read), calls `Inventory.apply_respawn_floor_if_needed(snapshot, should_apply_floor)`, then advances the live flag to `true` if the floor was applied. Finally, after the step-12 `section_entered(RESPAWN)` fires, F&R calls `PlayerCharacter.reset_for_respawn(_current_checkpoint)` and pops `InputContext.LOADING` to return to `FlowState.IDLE`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `InputContext` autoload (ADR-0004 true-stack) is at line 4 per ADR-0007; F&R at line 8 can call `InputContext.push/pop` from `_ready()` and handler callbacks. `Time.get_ticks_msec()` is used for the 2.5 s watchdog (CR-10 + ADR-0008) — stable Godot 4.0+ API. The LS step-9 callback fires synchronously within LS's 13-step swap sequence (verified in LS story-003); F&R's callback body must be synchronous (no `await`). `PlayerCharacter.reset_for_respawn(Checkpoint)` is a PC-owned method; F&R calls it with `_current_checkpoint`. If `_current_checkpoint == null` at this point (E.9 / OQ-FR-5), F&R calls `reset_for_respawn(null)` with `push_warning` — the PC GDD governs the null behavior.

**Control Manifest Rules (Feature)**:
- Required (Foundation/Autoload): `InputContext` is at autoload line 4; F&R at line 8 may reference it safely — ADR-0007 IG 4
- Required (Foundation/Signal Bus): `is_instance_valid(node)` before dereferencing Node-typed payload — ADR-0002 IG 4 (not directly applicable here since payloads are StringName, but apply to any Node references in the callback chain)
- Forbidden: `await` inside the LS step-9 restore callback body (callback fires synchronously; `await` would break the LS step-9 → step-10 ordering guarantee)
- Forbidden: reading `_floor_applied_this_checkpoint` from the restored SaveGame sub-resource at step 9 — must read LIVE member (CR-5/CR-6 live-authoritative rule)

---

## Acceptance Criteria

*From GDD `design/gdd/failure-respawn.md` CR-5, CR-9, CR-10, CR-12 Steps 8-13, E.12, E.13, E.23; TR-FR-005, TR-FR-009, TR-FR-011, TR-FR-012, TR-FR-013; AC-FR-7.1, AC-FR-7.3, AC-FR-8.1, AC-FR-9.3, AC-FR-10.1, AC-FR-11.1, AC-FR-11.2, AC-FR-11.3:*

- [ ] **AC-1**: GIVEN the InputContext stack is `[GAMEPLAY]` at the moment `Events.player_died` fires, WHEN the full respawn flow completes (CAPTURING → RESTORING → IDLE), THEN the stack is `[GAMEPLAY]` again (net-zero push/pop, verified by reading `InputContext._stack` before and after).
- [ ] **AC-2**: GIVEN `InputContext.LOADING` is active during the respawn window, WHEN `ui_pause` action is triggered (simulated via `InputEventAction`), THEN the action does not route to the pause handler (GDD E.13).
- [ ] **AC-3**: GIVEN F&R's step-9 `_on_ls_restore` callback fires, WHEN `_floor_applied_this_checkpoint == false` (first death of this checkpoint — VS path), THEN `Inventory.apply_respawn_floor_if_needed(snapshot, should_apply_floor=true)` is called AND the live `_floor_applied_this_checkpoint` advances to `true` synchronously after `Inventory.apply_respawn_floor_if_needed` returns.
- [ ] **AC-4**: GIVEN `_flow_state == FlowState.RESTORING` AND `section_entered(_, TransitionReason.RESPAWN)` fires (LS step-12), WHEN F&R's `section_entered` handler runs, THEN `PlayerCharacter.reset_for_respawn(_current_checkpoint)` is called AND `_current_checkpoint` is NOT overwritten AND `_floor_applied_this_checkpoint` is NOT reset (CR-7 RESTORING guard).
- [ ] **AC-5**: GIVEN `PC.reset_for_respawn(_current_checkpoint)` returns, THEN `InputContext.LOADING` is popped and `_flow_state` transitions to `FlowState.IDLE`.
- [ ] **AC-6**: GIVEN F&R `_ready()` has run, WHEN a fresh F&R instance is created (simulating editor hot-reload), THEN the new instance re-registers the restore callback unconditionally; no duplicate registration from the old instance persists (replace-semantics per GDD E.24 + LS coord item).
- [ ] **AC-7**: GIVEN `_flow_state == FlowState.RESTORING` persists for > 2.5 seconds without the step-9 callback firing, THEN F&R calls `push_error` with a watchdog message (CR-10 watchdog — indicates LS queue depth exceeded the documented contract).
- [ ] **AC-8 [Integration]**: GIVEN the VS scenario — Plaza section loaded, `_current_checkpoint` pointing to the Plaza `player_respawn_point` Marker3D, WHEN `Events.player_died(CombatSystemNode.DeathCause.SCRIPTED)` fires, THEN the round-trip integration test verifies: (a) F&R assembles a slot-0 SaveGame; (b) `Events.respawn_triggered(&"plaza")` is emitted; (c) LS `reload_current_section` is called; (d) F&R step-9 callback fires and `Inventory.apply_respawn_floor_if_needed` is called (no-op in VS — no ammo); (e) `PlayerCharacter.reset_for_respawn` is called with the Plaza checkpoint; (f) `_flow_state == FlowState.IDLE` after the full flow.
- [ ] **AC-9 [Visual/Feel]**: GIVEN the VS demonstrable beat (caught-by-Plaza-guard → `Events.player_died(SCRIPTED)` → 2.0 s Audio fade-out → respawn at Plaza checkpoint → audio cut-to-silence + fade-in → Eve back on her feet, mission state intact), WHEN the beat is observed in the running game, THEN the evidence screenshot/recording captures Eve at the Plaza `player_respawn_point` position post-respawn, consistent with the "house lights up between scenes" Pillar 3 feel.

---

## Implementation Notes

*Derived from GDD CR-5, CR-9, CR-12 Steps 8-13:*

**`_on_ls_restore` callback body** (fires at LS step-9):

```gdscript
## Called synchronously by LevelStreamingService at step 9 of the 13-step swap.
## MUST be synchronous — no await. Reads LIVE flag, not restored SaveGame sub-resource.
func _on_ls_restore(save_game: SaveGame) -> void:
    # Step 9: apply ammo floor via live-authoritative flag read (CR-5/CR-6).
    # VS path: no ammo → Inventory.apply_respawn_floor_if_needed is a no-op.
    var should_apply: bool = not _floor_applied_this_checkpoint  # LIVE read
    var snapshot: Dictionary = {}  # assembled from save_game.inventory at restore time
    if save_game.inventory != null:
        snapshot = save_game.inventory.ammo_reserve.duplicate()
    InventoryService.apply_respawn_floor_if_needed(snapshot, should_apply)
    if should_apply:
        _floor_applied_this_checkpoint = true  # advance LIVE synchronously (CR-5)
    # Cancel watchdog timer if running.
    _watchdog_cancel()
```

**`section_entered` RESTORING path** (step-12 dispatch added to Story 004's handler):

The IDLE guard in Story 004's `_on_section_entered` returns early when `_flow_state != IDLE`. This story adds the RESTORING-specific RESPAWN dispatch BEFORE that early return:

```gdscript
func _on_section_entered(section_id: StringName, reason: LevelStreamingService.TransitionReason) -> void:
    if _flow_state != FlowState.IDLE:
        # CR-7: state-mutating branches (flag reset, checkpoint overwrite) are SKIPPED.
        # Only dispatch PC.reset_for_respawn when reason == RESPAWN.
        if reason == LevelStreamingService.TransitionReason.RESPAWN:
            _complete_respawn_flow()
        return
    # ... IDLE branches (Story 004) ...
```

**`_complete_respawn_flow()` private method** (step 12-13):

```gdscript
func _complete_respawn_flow() -> void:
    if _current_checkpoint == null:
        push_warning("FailureRespawn: _current_checkpoint is null at respawn — calling reset_for_respawn(null). PC GDD governs null behavior (OQ-FR-5).")
    PlayerCharacter.reset_for_respawn(_current_checkpoint)  # Step 12
    InputContext.pop(InputContext.Context.LOADING)  # Step 13
    _flow_state = FlowState.IDLE
```

**InputContext push/pop symmetry (CR-9 Option B)**: F&R pushes `InputContext.LOADING` at step 2 (in `_on_player_died` CAPTURING entry, before SaveGame assembly) and pops at step 13 (in `_complete_respawn_flow` after `reset_for_respawn`). LS also pushes/pops its own `LOADING` context at LS step-1 / step-11 independently. The stack resolves: `[GAMEPLAY, LOADING(F&R), LOADING(LS)]` → LS pops at step-11 → `[GAMEPLAY, LOADING(F&R)]` → F&R pops at step-13 → `[GAMEPLAY]`. Net-zero.

**Watchdog implementation (CR-10, TR-FR-012)**: start a timer after `_flow_state` transitions to `RESTORING` (end of CAPTURING body). If `_on_ls_restore` does not fire within 2.5 s, call `push_error("FailureRespawn: watchdog fired — RESTORING for > 2.5 s; LS queue depth may have exceeded depth-1 contract (CR-10)")`. Use `get_tree().create_timer(2.5)` in debug builds; no timer in release builds to avoid any per-tick overhead. `_watchdog_cancel()` cancels the timer when `_on_ls_restore` fires.

**VS demonstrable beat** (Definition of Done gate): caught-by-Plaza-guard → `Events.player_died(SCRIPTED)` → F&R CAPTURING (SaveGame assembled, slot-0 written) → `Events.respawn_triggered(&"plaza")` → Audio silence begins → `LevelStreamingService.reload_current_section(save_game)` → LS 13-step swap (fade-out + scene reload + fade-in, ~0.58 s mechanical) → F&R step-9 callback → no ammo floor applied (VS path) → LS step-12 `section_entered(RESPAWN)` → `PC.reset_for_respawn(plaza_checkpoint)` → Eve at Plaza respawn point → `InputContext.LOADING` popped → `_flow_state == IDLE` → Audio 2.0 s fade-in completes.

**RESPAWN-not-FORWARD autosave MLS boundary**: F&R writes slot-0 at CAPTURING (step 4) — a dying-state snapshot. The step-9 callback does NOT write a new slot-0 save (that would be `fr_autosaving_on_respawn` — the forbidden pattern guarded by Story 006). The only slot-0 write in the respawn flow is at step 4 in CAPTURING. MLS writes slot-0 on `section_entered(FORWARD)` — a separate, authorized write. These two slot-0 write points must not be confused.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: autoload scaffold, state machine declaration
- Story 002: CAPTURING body — SaveGame assembly, `save_to_slot`, in-memory handoff
- Story 003: `respawn_triggered` emission, signal ordering
- Story 004: checkpoint assembly, `section_entered` IDLE branches, floor flag state machine
- Story 006: anti-pattern fences, `fr_autosaving_on_respawn` CI lint, `await` lint
- Combat-driven death paths (`DeathCause.SHOT`, `DeathCause.BLADE`) — no combat in VS
- Kill-plane fall-out-of-bounds detector (Plaza is bounded) — deferred post-VS
- Ammo respawn floor actual application math (Inventory GDD coord item — `apply_respawn_floor_if_needed` is a no-op in VS; floor math tested when Inventory epic is implemented)
- Multi-checkpoint progression (post-VS — Mission Scripting extension point)

---

## QA Test Cases

**AC-1 — InputContext net-zero push/pop**
- Given: `InputContext._stack == [GAMEPLAY]` before `player_died`; F&R wired to real `InputContext` (or a faithful double)
- When: full respawn flow completes (player_died → CAPTURING → RESTORING → IDLE)
- Then: `InputContext._stack == [GAMEPLAY]` again
- Edge cases: `MENU` context on stack (`[GAMEPLAY, MENU]`) → after respawn: `[GAMEPLAY, MENU]` (MENU preserved, per GDD E.12)

**AC-2 — LOADING blocks ui_pause**
- Given: `InputContext.LOADING` is active (respawn in progress)
- When: `ui_pause` `InputEventAction` is injected via `Input.parse_input_event`
- Then: the pause handler is NOT called (action masked by LOADING context per ADR-0004)

**AC-3 — Live-authoritative floor read at step-9 (VS path: floor not applied)**
- Given: `_floor_applied_this_checkpoint = false`; `Inventory` double injected; VS scenario (empty ammo snapshot)
- When: `_on_ls_restore(save_game)` is called with an assembled save
- Then: `Inventory.apply_respawn_floor_if_needed` called with `should_apply_floor = true` (live reads `false` → should apply); but in VS with empty snapshot, the result is no ammo change; live `_floor_applied_this_checkpoint` advances to `true` synchronously after the Inventory call returns

**AC-4 — CR-7 guard in RESTORING: no state mutation on RESPAWN dispatch**
- Given: `_flow_state == FlowState.RESTORING`; `_current_checkpoint` is a pre-set stub; `_floor_applied_this_checkpoint = false`
- When: `section_entered(&"plaza", TransitionReason.RESPAWN)` fires
- Then: `PC.reset_for_respawn` called with the pre-set stub; `_current_checkpoint` unchanged; `_floor_applied_this_checkpoint == false` (unchanged — no flag reset in RESTORING)

**AC-5 — RESTORING → IDLE after reset_for_respawn**
- Given: `_flow_state == FlowState.RESTORING`; PC double injected; `_current_checkpoint` is a valid Checkpoint
- When: `_complete_respawn_flow()` is called (simulating LS step-12 RESPAWN dispatch)
- Then: `PC.reset_for_respawn` called once; `InputContext.LOADING` popped once; `_flow_state == FlowState.IDLE`

**AC-6 — Hot-reload restore callback re-registration**
- Given: a first F&R instance registered its callback with LS double
- When: F&R instance is removed from tree and a new instance is added (simulating hot-reload); new instance's `_ready()` runs
- Then: the LS double's `register_restore_callback` was called a second time; the second call's Callable points to the new instance's `_on_ls_restore` (old instance's Callable replaced)

**AC-7 — 2.5 s watchdog fires push_error**
- Given: `_flow_state` forced to `FlowState.RESTORING`; `Time.get_ticks_msec()` spied; watchdog timer advanced by > 2500 ms
- When: `_on_ls_restore` has NOT fired within 2.5 s
- Then: `push_error` called with message containing "watchdog" and "> 2.5 s"

**AC-8 — VS round-trip integration test**
- Given: Plaza section with `player_respawn_point` Marker3D; real (or faithful double) `LevelStreamingService`; PC double with `reset_for_respawn` spy; no ammo (VS)
- When: `Events.player_died(DeathCause.SCRIPTED)` fires
- Then (in order): (a) slot-0 saved; (b) `respawn_triggered(&"plaza")` emitted; (c) `reload_current_section` called; (d) step-9 `_on_ls_restore` fires; (e) `apply_respawn_floor_if_needed` called; (f) `reset_for_respawn(plaza_checkpoint)` called; (g) `_flow_state == FlowState.IDLE`
- Evidence: `tests/integration/feature/failure_respawn/vs_respawn_round_trip_test.gd`

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/unit/feature/failure_respawn/input_stack_test.gd` — must exist and pass (AC-1, AC-2)
- `tests/unit/feature/failure_respawn/autoload_hygiene_test.gd` — must exist and pass (AC-4, AC-5, AC-6, AC-7)
- `tests/integration/feature/failure_respawn/vs_respawn_round_trip_test.gd` — must exist and pass (AC-8)
- `production/qa/evidence/failure_respawn/vs_respawn_beat_evidence.md` — screenshot or annotated recording of the VS respawn beat (AC-9): Eve at Plaza respawn point post-respawn, 2.0 s Audio fade visible in Audio mixer or noted by QA lead; lead sign-off required

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (autoload scaffold) MUST be Done; Story 002 (CAPTURING body + RESTORING transition) MUST be Done; Story 003 (signal emission) MUST be Done; Story 004 (section_entered handler + checkpoint assembly) MUST be Done; Level Streaming story-003 (`register_restore_callback` chain) MUST be Done; Level Streaming story-008 (Plaza section with `player_respawn_point`) MUST be Done
- Unlocks: Story 006 (anti-pattern fences operate on the complete F&R implementation)
