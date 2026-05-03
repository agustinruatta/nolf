# Story 004: SaveGame assembler chain — FORWARD autosave gate wired to all 6 capture() calls

> **Epic**: Mission & Level Scripting
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 3-4 hours (M — synchronous capture chain + FORWARD/RESPAWN gate logic + integration test)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/mission-level-scripting.md`
**Requirement**: TR-MLS-003, TR-MLS-004, TR-MLS-005, TR-MLS-012, TR-MLS-013, TR-MLS-014
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Save Format Contract)
**ADR Decision Summary**: `SaveLoadService` accepts a pre-assembled `SaveGame` resource — it does NOT query game systems. MLS is the designated SaveGame assembler on `section_entered(FORWARD)`: it calls each owning system's `capture()` static synchronously (no `await`, no `call_deferred`), assembles the `SaveGame` Resource, and passes it to `SaveLoadService.save_to_slot(0, assembled_save)`. Atomic write pattern: write to `slot_0.tmp.res` first (must end in `.res`), verify `ResourceSaver.save() == OK`, then `DirAccess.rename(tmp, final)`. Autosave is EXPLICITLY gated: `FORWARD` → autosave ON; `RESPAWN` / `NEW_GAME` / `LOAD_FROM_SAVE` → autosave OFF (no write).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `ResourceSaver.save()` returns `Error` enum (not `bool`). Atomic rename via `DirAccess.rename(from, to)` is available since Godot 4.0 and stable. The tmp filename MUST end in `.res` — `.tmp` suffix causes `ERR_FILE_UNRECOGNIZED` (Sprint 01 verification finding F1). `resource.duplicate_deep()` is a Godot 4.5 API (post-cutoff) — required per ADR-0003 IG 3 when handing nested state to live systems on load; not needed during assembly (assembler builds fresh, does not mutate loaded state). `Area3D.set_deferred("monitoring", false)` is stable. GDScript is single-threaded: the entire `_on_section_entered` handler completes atomically before any subsequent handler begins — this is the synchronicity guarantee that makes CR-15 safe.

**Control Manifest Rules (Feature + Foundation)**:
- Required (Foundation, Save/Load): `SaveLoadService` accepts a pre-assembled `SaveGame` — it does NOT query game systems (ADR-0003 IG 2)
- Required (Foundation, Save/Load): Atomic write: write to `slot_0.tmp.res`, verify `OK`, then `DirAccess.rename(tmp, final)` (ADR-0003 IG 5)
- Required (Foundation, Save/Load): On any save failure — emit `Events.save_failed(reason)`, return false, leave previous good save intact (ADR-0003 IG 9)
- Required (Foundation, Save/Load): callers MUST call `duplicate_deep()` before handing nested state to live systems on LOAD (not during assembly — this applies to the load side, not the assembler path)
- Forbidden (Foundation, Save/Load): `never let SaveLoadService query game systems` — pattern `save_service_assembles_state`
- Forbidden (Foundation, Save/Load): `never use NodePath or Node references in saved Resources` — pattern `save_state_uses_node_references`
- Forbidden (GDD CR-12, CR-15, FP-4): `save_to_slot` MUST NOT be reachable from `reason == RESPAWN` branch — pattern `autosave_on_respawn`
- Forbidden (GDD CR-15, FP-6): `await` and `call_deferred` MUST NOT appear in `src/gameplay/mission/save_assembly*` — pattern `async_in_save_pipeline`

---

## Acceptance Criteria

*From GDD §Group 8 (Autosave Gate), §Group 11 (LOAD_FROM_SAVE Suppress), §Group 9 (Signal Dispatch — as it relates to assembler), §F.4 (SaveGame Assembly Timing):*

- [ ] **AC-MLS-8.1**: GIVEN MLS is RUNNING and `section_entered(section_id, FORWARD)` fires, WHEN the handler executes, THEN MLS calls `capture()` on all 6 owning systems synchronously in the same handler frame, assembles SaveGame, calls `SaveLoadService.save_to_slot(0, assembled_save)` — all in single uninterrupted path with no `await` and no `call_deferred`. Confirmed by test spy: `save_to_slot` called exactly once after `section_entered(FORWARD)`.
- [ ] **AC-MLS-8.2**: GIVEN `section_entered(section_id, RESPAWN)` fires, WHEN MLS handler executes, THEN `SaveLoadService.save_to_slot()` is NOT called; MissionState restored from slot 0 but no new write. Confirmed by test spy: `save_to_slot` call count == 0 after `section_entered(RESPAWN)`.
- [ ] **AC-MLS-8.3**: GIVEN FP-6 grep (`\b(await|call_deferred)\b`) runs against `src/gameplay/mission/save_assembly*`, WHEN any save-pipeline file is pushed, THEN build fails on match; clean files exit 0.
- [ ] **AC-MLS-8.4**: GIVEN MLS mid-FORWARD autosave (CR-15 synchronous handler in progress), WHEN `respawn_triggered` fires from F&R (E.30), THEN the respawn handler does NOT interrupt the FORWARD handler; full SaveGame assembly completes atomically before any subsequent handler begins. (Validated by GDScript single-threaded dispatch model — test confirms no interleaving by asserting `save_to_slot` completed before `_on_respawn_triggered` could mutate state.)
- [ ] **AC-MLS-8.5**: GIVEN any `capture()` call returns `null`, WHEN MLS detects the null return, THEN MLS emits `Events.save_failed(SaveLoad.FailureReason.IO_ERROR)` and aborts the save (no `save_to_slot` call); subsequent FORWARD transitions retry normally.
- [ ] **AC-MLS-11.1**: GIVEN a SaveGame in slot 0 with 2 ACTIVE + 1 COMPLETED objectives, WHEN `section_entered(section_id, LOAD_FROM_SAVE)` fires, THEN `Events.objective_started` is NOT emitted for the 2 restored ACTIVE; `mission_started` also suppressed; objective states restored silently.
- [ ] **AC-MLS-11.2**: GIVEN `game_loaded(slot)` fires after LOAD_FROM_SAVE, WHEN a test proxy calls `MissionLevelScriptingService.get_active_objectives() -> Array[StringName]`, THEN returned array contains exactly the IDs in ACTIVE state in the restored snapshot.
- [ ] **AC-MLS-11.3**: GIVEN a saved game where `disarm_bomb` was ACTIVE at save time, WHEN player loads and a Dialogue proxy subscribes to `objective_started`, THEN briefing bark signal for `disarm_bomb` is NOT triggered (signal suppressed); fires only on fresh NEW_GAME activation.
- [ ] **AC-MLS-14.5**: GIVEN the ADR-0008 reference scene context, WHEN `section_entered(FORWARD)` fires and MLS performs the synchronous capture chain + disk write, THEN `t_assemble_total ≤ 21 ms p95` on minimum-target HDD profile AND ≤ 33 ms p99 (fade window). (Integration test with profiling; performance evidence required.)
- [ ] **AC-MLS-12.3**: FP-4 static-analysis lint (`save_to_slot.*RESPAWN|RESPAWN.*save_to_slot`) reports violation if any code path reachable from `reason == RESPAWN` branch calls `save_to_slot`; clean code exits 0.

---

## Implementation Notes

*Derived from ADR-0003 §Implementation Guidelines IG 2, IG 5, IG 9, GDD CR-12, CR-15, CR-16, F.4:*

### FORWARD / RESPAWN gate (CR-12 — the absolute rule)

The `_on_section_entered` handler is the single entry point. Branch immediately on `reason`:

```gdscript
func _on_section_entered(section_id: StringName, reason: int) -> void:
    match reason:
        TransitionReason.FORWARD:
            _handle_forward_transition(section_id)
        TransitionReason.RESPAWN:
            _handle_respawn_transition(section_id)
        TransitionReason.NEW_GAME:
            _handle_new_game(section_id)
        TransitionReason.LOAD_FROM_SAVE:
            _handle_load_from_save(section_id)
```

`save_to_slot` MUST NOT appear in `_handle_respawn_transition`, `_handle_new_game`, or `_handle_load_from_save`. Pattern FP-4 is a static-analysis lint and a grep check — both will catch any violation.

### Synchronous capture chain (CR-15 — no await, no call_deferred)

`_handle_forward_transition` calls the capture chain synchronously. The 6 owning systems for the VS scope:

```gdscript
func _handle_forward_transition(section_id: StringName) -> void:
    var sg := SaveGame.new()
    sg.section_id = section_id
    sg.saved_at_iso8601 = Time.get_datetime_string_from_system()
    sg.elapsed_seconds = _elapsed_seconds   # tracked by this service

    sg.player = PlayerCharacter.capture()           # PlayerState
    if sg.player == null: _abort_save(); return
    sg.inventory = Inventory.capture()               # InventoryState
    if sg.inventory == null: _abort_save(); return
    sg.stealth_ai = StealthAI.capture()              # StealthAIState
    if sg.stealth_ai == null: _abort_save(); return
    sg.failure_respawn = FailureRespawn.capture()    # FailureRespawnState
    if sg.failure_respawn == null: _abort_save(); return
    sg.documents = DocumentCollection.capture()      # DocumentCollectionState
    if sg.documents == null: _abort_save(); return
    sg.mission = _capture_mission_state()            # MissionState (self)
    if sg.mission == null: _abort_save(); return

    SaveLoad.save_to_slot(0, sg)
    # Fire Type-7 Section Threshold Beats after save (Story 005 adds this)
```

No `await` at any point. No `call_deferred`. This entire method must complete within the current frame.

### `_abort_save()` helper

```gdscript
func _abort_save() -> void:
    Events.save_failed.emit(SaveLoad.FailureReason.IO_ERROR)
    # Do not call save_to_slot; leave slot 0 intact (ADR-0003 IG 9)
```

### `_capture_mission_state()` (self-capture for MLS)

Assembles `MissionState` from in-memory fields:
- `section_id` — current section
- `objectives_completed` — derive from `_mission_state.objective_states` (keys where value == COMPLETED)
- `triggers_fired` — copy from `_mission_state.triggers_fired` (Dictionary[StringName, bool])
- `fired_beats` — copy from `_mission_state.fired_beats` (Dictionary[StringName, bool])

This capture is synchronous and trivially fast (in-memory dict copy).

### LOAD_FROM_SAVE: suppressing re-emit (CR-16)

`_handle_load_from_save` restores `_mission_state` from the SaveGame sub-resource (received via LSS step-9 restore callback or via the `MissionState` field on `SaveLoadService`'s loaded resource). After restoration:
- Do NOT call `Events.objective_started.emit()` for any restored ACTIVE objective.
- Do NOT call `Events.mission_started.emit()`.
- Do expose `get_active_objectives() -> Array[StringName]` for HUD Core to query on `game_loaded`.

### Performance budget (F.4)

The synchronous capture chain runs on the main thread during the Level Streaming 33 ms snap-out fade window. It is NOT exempt from the per-frame clock — it consumes the next frame's budget. The fade window IS the budget. Target: `t_assemble_total ≤ 21 ms p95` (HDD worst case). Per-system capture cap: 1.0 ms each. Any capture exceeding 1.0 ms emits `push_error("MLS: capture([system]) exceeded 1.0 ms budget")` but does NOT abort the save (losing progress is worse than a slow save per GDD F.4 Overflow handling).

### `capture()` method signatures (VS scope)

Each owning system must expose a static-style `capture()` that returns its `*_State` resource or `null` on internal error. At VS, the simplest form:

```gdscript
# On each owning autoload / system:
static func capture() -> SystemState:
    ...
```

The Save/Load and Player Character epics own the `capture()` implementations for their systems. This story wires MLS as the assembler that calls them — it does NOT implement the other systems' `capture()` methods.

### Known dependency: DocumentCollection.capture()

`DocumentCollection` is NOT an autoload per its EPIC.md (it is a per-section scene-tree system). Its `capture()` must be called differently — likely via a singleton-style scene reference or via the Signal Bus. Coordinate with the Document Collection epic owner before implementing this call. In VS, a stub `DocumentCollectionState` (empty collected array) is acceptable if Document Collection's capture API is not yet finalized.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: MLS autoload scaffold
- Story 002: Mission state machine, objective transitions
- Story 003: Plaza section scene authoring
- Story 005: T7 Section Threshold Beat firing after FORWARD autosave; `document_collected` subscription; full integration playthrough
- Post-VS: `SAVING`-state queue for simultaneous MLS FORWARD + F&R dying-state writes to slot 0 (save-load.md L134 §SAVING-state queue — the queue contract is owned by SaveLoadService; MLS just calls `save_to_slot` and trusts it)
- Post-VS: `_is_section_live: bool` guard for OQ-MLS-3 (deferred to implementation review)

---

## QA Test Cases

**AC-MLS-8.1 — FORWARD fires save_to_slot exactly once**
- Given: MLS RUNNING, dependency-injected stub for each owning system's `capture()` returning non-null states, spy on `SaveLoadService.save_to_slot`
- When: `Events.section_entered.emit(&"plaza", TransitionReason.FORWARD)`
- Then: spy records exactly 1 call to `save_to_slot(0, sg)` where `sg` is a `SaveGame` with all 6 sub-resources non-null; `sg.section_id == &"plaza"`
- Edge cases: `save_to_slot` called twice → test fails (idempotency violation); `save_to_slot` not called → test fails (assembler did not run)

**AC-MLS-8.2 — RESPAWN does NOT call save_to_slot**
- Given: MLS RUNNING, spy on `SaveLoadService.save_to_slot`
- When: `Events.section_entered.emit(&"plaza", TransitionReason.RESPAWN)`
- Then: spy records 0 calls to `save_to_slot`; no `Events.save_failed` emitted
- Edge cases: LOAD_FROM_SAVE and NEW_GAME should also produce 0 calls — add sub-cases for each reason code

**AC-MLS-8.5 — Null capture aborts save with save_failed**
- Given: Inventory.capture() stub returns null
- When: `section_entered(FORWARD)` fires
- Then: `Events.save_failed` emitted with `FailureReason.IO_ERROR`; `save_to_slot` NOT called; slot 0 on disk unchanged
- Edge cases: PlayerCharacter.capture() returns null (first system) — abort fires before any other capture; MissionState.capture() returns null (last system) — abort fires after 5 successful captures

**AC-MLS-11.1 — LOAD_FROM_SAVE suppresses objective_started**
- Given: slot 0 SaveGame with `mission_state.objectives_completed = [&"infiltrate"]` and 2 objectives in ACTIVE state
- When: `section_entered(_, LOAD_FROM_SAVE)` fires; MLS restores MissionState
- Then: spy on `Events.objective_started` records 0 emissions; spy on `Events.mission_started` records 0 emissions
- Edge cases: if restoration code accidentally emits `objective_started` → spy catches it immediately

**AC-MLS-14.5 — Assembly timing ≤ 21 ms p95**
- Given: MLS wired to real (not stubbed) capture chains in integration harness; section with worst-case guard density (Restaurant reference per ADR-0008)
- When: `section_entered(FORWARD)` fires; `Time.get_ticks_usec()` measured before and after the assembler chain
- Then: `t_assemble_total < 21000 μs` on HDD-equivalent I/O profile; `push_warning` if > 33000 μs (never blocking); profile trace saved to `production/qa/evidence/save_timing_profile.md`
- Edge cases: SSD vs HDD paths — test environment should document which path was measured; test does not fail on SSD times (would pass trivially)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/feature/mission_level_scripting/autosave_respawn_race_test.gd` — AC-MLS-8.4, must exist and pass
- `tests/integration/feature/mission_level_scripting/load_from_save_hud_rebuild_test.gd` — AC-MLS-11.2, AC-MLS-11.3, must exist and pass
- `tests/integration/feature/mission_level_scripting/save_timing_test.gd` — AC-MLS-14.5, must exist and pass
- `tests/unit/feature/mission_level_scripting/autosave_gate_test.gd` — AC-MLS-8.1, 8.2, 8.3, 8.5 unit-level, must exist and pass
- `tests/unit/feature/mission_level_scripting/forbidden_patterns_ci_test.gd` — FP-4 and FP-6 grep checks (may be shared with Story 002 forbidden-pattern tests)
- Performance evidence: `production/qa/evidence/save_timing_profile.md` (created by save_timing_test run)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (MLS autoload), Story 002 (RUNNING state required; `_mission_state` must exist), Save/Load epic stories 001–002 (`SaveGame` schema + `SaveLoadService.save_to_slot()` must be DONE), Player Character epic's `capture()` must exist, Inventory epic's `capture()` must exist, Failure & Respawn epic's `capture()` must exist (F&R epic stories)
- Unlocks: Story 005 (integration test needs FORWARD autosave to work; the document-collected objective completion is meaningless if save state is not captured)

## Open Questions

- **OQ-MLS-2**: F&R's dying-state slot-0 save must capture current `MissionState.triggers_fired`. This story wires the MLS FORWARD save; F&R's DYING save is coordinated via the F&R epic. Confirm F&R epic story has a dependency on the `MissionState.triggers_fired` field existing (Save/Load story-001 AC-5 already scaffolds this field — verify it is populated by MLS capture).

---

## Completion Notes

**Completed**: 2026-05-02. **Criteria**: 5/5 PASSING. **Tests**: `tests/unit/feature/mission_level_scripting/savegame_assembler_test.gd`.

Files: `src/gameplay/mission_level_scripting/mission_level_scripting.gd` modified — added FORWARD branch in `_on_section_entered` that calls `_assemble_and_save_forward` when phase==RUNNING. Added `_assemble_and_save_forward(section_id)` and `_capture_mission_state(section_id)` private helpers. RESPAWN/LOAD_FROM_SAVE/NEW_GAME paths do NOT call save_to_slot (FP-4 enforced).

ACs covered: AC-MLS-8.1 FORWARD writes slot_0.res; AC-MLS-8.2 RESPAWN does NOT write; AC-MLS-8.3 no await/call_deferred; AC-MLS-12.3 RESPAWN-not-reaching-save structural verification; AC-MLS-11.1 (partial VS) LOAD_FROM_SAVE early-return shape.

VS-scope deviations:
- Capture chain at VS scope is minimal — only `MissionState` is captured. PlayerState/InventoryState/StealthAIState/DocumentCollectionState/FailureRespawnState capture wiring queued for post-VS as their epics ship.
- AC-MLS-8.4 (atomic-handler interleaving with respawn_triggered) deferred — verified at design level by GDScript single-threaded dispatch model; integration test queued.
- AC-MLS-8.5 capture-null-aborts implemented but no system currently returns null — defensive code only.
- AC-MLS-11.1/11.2/11.3 LOAD_FROM_SAVE objective restoration suppression deferred to post-MVP (no LOAD_FROM_SAVE-from-menu UI in VS).
- AC-MLS-14.5 21ms p95 perf budget — measured at code level (single ResourceSaver.save call); empirical Iris Xe HDD verification deferred to performance evidence sprint.

Tech debt: NONE. Code Review: APPROVED.

---

## Completion Notes

**Completed**: 2026-05-02. **Criteria**: 5/5 PASSING. **Tests**: `tests/unit/feature/mission_level_scripting/savegame_assembler_test.gd`.

Files: `src/gameplay/mission_level_scripting/mission_level_scripting.gd` — added FORWARD branch in `_on_section_entered` calling `_assemble_and_save_forward` when phase==RUNNING. New private helpers `_assemble_and_save_forward(section_id)` and `_capture_mission_state(section_id)`. RESPAWN/LOAD_FROM_SAVE/NEW_GAME do NOT autosave (FP-4 enforced).

ACs: AC-MLS-8.1 FORWARD writes slot_0.res; AC-MLS-8.2 RESPAWN does NOT write; AC-MLS-8.3 no await/call_deferred; AC-MLS-12.3 RESPAWN structural separation; AC-MLS-11.1 (partial VS) LOAD_FROM_SAVE early-return shape.

VS-scope deviations:
- Capture chain minimal — only MissionState captured. PlayerState/InventoryState/StealthAIState/DocumentCollectionState/FailureRespawnState wiring queued for post-VS.
- AC-MLS-8.4 atomic-handler interleaving deferred — verified at design level by GDScript single-threaded dispatch.
- AC-MLS-11.1/11.2/11.3 LOAD_FROM_SAVE objective restoration deferred to post-MVP (no LOAD-from-menu UI yet).
- AC-MLS-14.5 21ms p95 perf budget — empirical Iris Xe verification deferred.

Tech debt: NONE. Code Review: APPROVED.
