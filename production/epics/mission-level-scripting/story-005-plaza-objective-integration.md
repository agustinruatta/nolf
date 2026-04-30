# Story 005: Plaza objective integration — Recover Plaza Document, NEW_GAME to COMPLETED

> **Epic**: Mission & Level Scripting
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 3-4 hours (M — MLSTrigger Area3D in Plaza, document_collected subscription, full lifecycle integration test)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/mission-level-scripting.md`
**Requirement**: TR-MLS-008, TR-MLS-009, TR-MLS-010
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0002 (Signal Bus + Event Taxonomy), ADR-0003 (Save Format Contract)
**ADR Decision Summary (ADR-0002)**: MLS subscribes to `document_collected(id: StringName)` from the Document Collection system via `Events.document_collected`. The `completion_signal = &"document_collected"` on `MissionObjective` is the diegetic hook that closes the "Recover the Plaza Document" objective without any UI prompt. MLS connects in `_ready()`, disconnects with `is_connected` guard in `_exit_tree()`. Node-typed payloads (document node) are checked with `is_instance_valid()` before dereference per IG 4. **ADR Decision Summary (ADR-0003)**: On `section_entered(FORWARD)` the COMPLETE `fired_beats` dictionary (including any beats fired between last FORWARD save and now) must be assembled and saved to slot 0 — this is the mechanism by which the `MLSTrigger` single-fire latch persists across respawns (per F.7 invariant and OQ-MLS-2).

**Engine**: Godot 4.6 | **Risk**: LOW–MEDIUM
**Engine Notes**: `Area3D.body_entered` signal is stable and reliable for player-movement speeds in Godot 4.6 with Jolt physics. `set_deferred("monitoring", false)` — `set_deferred` is stable since 4.0; it schedules the property set to execute after the current physics frame, preventing re-entry. Jolt 4.6 `body_exited` non-determinism on mid-overlap despawn (GDD CR-6, coord item #15) — `body_exited` subscriptions are FORBIDDEN; this story must not subscribe to `body_exited` under any circumstances. The TR-MLS-009 note about the Triggers collision layer ADR-0006 amendment (coord item #14) is active: the `MLSTrigger` Area3D collision layer assignment is a pending amendment. For VS, use `PhysicsLayers.MASK_PLAYER` as the collision mask on the Area3D (detect player body entry) and document the pending layer assignment in a code comment referencing ADR-0006 coord item #14.

**Control Manifest Rules (Feature + Foundation)**:
- Required (Foundation, Signal Bus): subscribers connect in `_ready`, disconnect in `_exit_tree` with `is_connected` guards (ADR-0002 IG 3)
- Required (Foundation, Signal Bus): every Node-typed signal payload checked with `is_instance_valid(node)` before dereferencing (ADR-0002 IG 4)
- Required (Core): every physics script references `PhysicsLayers.*` constants — no bare integer literals (ADR-0006 IG 1)
- Forbidden (GDD CR-6, FP-5): `body_exited` subscription in `src/gameplay/mission/` — pattern enforced by CI grep
- Forbidden (GDD CR-12, FP-4): `save_to_slot` reachable from `reason == RESPAWN` branch
- Forbidden (GDD CR-20): `Events.*` emissions inside `respawn_triggered` handler
- Guardrail (TR-MLS-009): `MLSTrigger` Area3D collision layer pending ADR-0006 amendment; document pending status with `# TODO: ADR-0006 coord item #14 — Triggers layer amendment required` comment

---

## Acceptance Criteria

*From GDD §Group 4 (Trigger System), §Group 5 (Beat Lifecycle), §Group 9 (Signal Dispatch), §Group 14 AC-MLS-14.6, §F.7 (Trigger Single-Fire Latch), and the VS objective definition:*

- [ ] **AC-MLS-4.1**: GIVEN `MLSTrigger` with `trigger_id = &"t_plaza_document_zone"`, empty `triggers_fired`, WHEN player body enters the Area3D and `body_entered` fires, THEN trigger: (1) calls `is_instance_valid(body)`; (2) checks `body.is_in_group("player")`; (3) checks `trigger_id not in MissionState.triggers_fired`; (4) adds `trigger_id` to `triggers_fired` synchronously; (5) calls `set_deferred("monitoring", false)`; (6) a second entry to the same volume fires no additional beat.
- [ ] **AC-MLS-4.2**: CI grep for FP-5 (`body_exited`) against `src/gameplay/mission/` exits 1 on match; zero matches → exit 0.
- [ ] **AC-MLS-4.3**: GIVEN no `body_entered` fires for an MLSTrigger during the entire section life (simulating Jolt tunneling E.21), WHEN `section_entered(FORWARD)` fires, THEN autosave executes, no `push_error` logged, no recovery attempt; the beat is silently missed (acceptable).
- [ ] **AC-MLS-4.4**: GIVEN `body_entered` fires for a freed body (E.22), WHEN MLS processes the callback, THEN `is_instance_valid(body)` called before `is_in_group`; silently discarded if invalid.
- [ ] **AC-MLS-5.1**: GIVEN T1 beat `beat_id = &"t1_plaque_debate"` in `MissionState.fired_beats`, WHEN `section_entered(section_id, RESPAWN)` fires, THEN `fired_beats` restored from slot-0; `MLSTrigger.monitoring = false`; beat does not replay.
- [ ] **AC-MLS-5.5**: GIVEN T7 beat subscribed to `section_entered(id, FORWARD)`, WHEN `section_entered(id, RESPAWN)` fires, THEN T7 handler does NOT execute; fires exclusively on FORWARD.
- [ ] **AC-MLS-9.1**: GIVEN a mission runs NEW_GAME → COMPLETED, WHEN Events bus is instrumented and one section is traversed with one objective completed, THEN all 4 Mission-domain signals emit at correct lifecycle moments; none skipped or reordered.
- [ ] **AC-MLS-9.2**: Code-review CI finds zero direct refs to HUD/Audio/Cutscenes/Dialogue node paths or class names in `src/gameplay/mission/`; all interactions via `Events.*`.
- [ ] **AC-MLS-9.3**: VS-tier subscribers absent (pre-VS build): MLS emits `mission_started` / `objective_completed` with no subscribers — GDScript emits silently, no error, no crash; mission beat resolves correctly.
- [ ] **AC-MLS-9.4**: Playthrough of one section (integration test): narrative-critical objective completes (`recover_plaza_document` — `document_collected` fires) → `objective_started` fired during NEW_GAME start → `objective_completed` fires → Audio subscriber (or test proxy) receives `objective_completed` — no direct MLS→Audio call.
- [ ] **AC-MLS-14.6**: GIVEN SAI propagation flips N ≥ 2 guards UNAWARE→SUSPICIOUS same physics frame, WHEN T6 handlers process N `alert_state_changed` events, THEN AT MOST 1 T6 beat fires that frame; remaining N-1 events dropped (counted toward neither budget nor fire count). (VS scope: Plaza has one T6-capable guard pair; this AC verifies the per-frame burst limit mechanism is in place even at N=2.)
- [ ] **AC-MLS-14.7**: GIVEN `MissionState.triggers_fired` typed as `Dictionary[StringName, bool]`, WHEN MLSTrigger checks `trigger_id not in MissionState.triggers_fired`, THEN lookup is O(1); the `triggers_fired` check is the FIRST guard in `body_entered` after `is_instance_valid` (per CR-6 revised step ordering, closing OQ-MLS-12).

---

## Implementation Notes

*Derived from ADR-0002 IG 3/4, GDD CR-6, F.7, CR-7, §C.4, §C.6 Plaza anchor beat, VS objective definition:*

### VS objective: "Recover the Plaza Document"

The single Plaza objective for VS scope:

```
assets/data/missions/eiffel_tower/objectives/recover_plaza_document.tres
```

`MissionObjective` fields:
- `objective_id = &"recover_plaza_document"`
- `display_name_key = &"obj.recover_plaza_document.name"` (Localization key)
- `prereq_objective_ids = []` (activates on `mission_started`)
- `completion_signal = &"document_collected"`
- `completion_filter_method = &"_filter_plaza_document"` (resolves to a method on MLS that checks `document_id == &"doc_plaza_maintenance"` or equivalent)
- `supersedes = []`
- `required_for_completion = true`

### `MLSTrigger` class declaration

```gdscript
## Scripted-event trigger volume. One-shot body_entered with single-fire latch via MissionState.triggers_fired.
class_name MLSTrigger extends Area3D

@export var trigger_id: StringName
@export var one_shot: bool = true

func _ready() -> void:
    monitoring = false  # OQ-MLS-6: passivity in _ready until section_entered fires
    # TODO: ADR-0006 coord item #14 — Triggers layer amendment required; using MASK_PLAYER for VS
    collision_mask = PhysicsLayers.MASK_PLAYER
    body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
    if not is_instance_valid(body): return
    if not body.is_in_group("player"): return
    var ms: MissionState = MissionLevelScripting._mission_state
    if trigger_id in ms.triggers_fired: return        # O(1) — OQ-MLS-12 closed
    ms.triggers_fired[trigger_id] = true               # synchronous latch FIRST (F.7 step 3)
    set_deferred("monitoring", false)                  # cross-frame structural latch
    _run_beat_body()

func _run_beat_body() -> void:
    pass  # Overridden by per-beat subclasses or set via callable at authoring time
```

Key invariant from F.7: `triggers_fired[trigger_id] = true` MUST be set synchronously BEFORE the beat body runs. `set_deferred` MUST be called after. This ordering provides both same-frame idempotency (synchronous check) and cross-frame structural latch (deferred monitoring=false).

### `_t6_fired_this_frame` burst limit (AC-MLS-14.6)

```gdscript
var _t6_fired_this_frame: bool = false

func _on_alert_state_changed(actor: Node, old_state: int, new_state: int, severity: int) -> void:
    if new_state == StealthAI.AlertState.COMBAT: return   # COMBAT suppression (F.3)
    if new_state not in [StealthAI.AlertState.SUSPICIOUS, StealthAI.AlertState.SEARCHING]: return
    if _t6_fired_this_frame: return   # burst limit: at most 1 T6 per frame
    _t6_fired_this_frame = true
    call_deferred("_reset_t6_frame_flag")
    _fire_t6_beat(new_state)   # Post-VS: populate beat body; stub for VS

func _reset_t6_frame_flag() -> void:
    _t6_fired_this_frame = false
```

### Enable trigger volumes on section_entered

OQ-MLS-6 requires `MLSTrigger` to self-enforce passivity in `_ready()` (set `monitoring = false`) and enable on `section_entered`. In the `_handle_forward_transition` / `_handle_new_game` handlers:

```gdscript
# After mission start or forward transition, enable all trigger volumes in the active section:
for trigger in _active_triggers:   # tracked list of MLSTrigger instances in active section
    trigger.monitoring = true
```

The `_active_triggers` list is populated when the section scene loads and the MLS service walks the section tree for `MLSTrigger` nodes. Do NOT use `get_node()` from autoload `_ready()` (section not yet loaded) — walk the tree from the section root on `section_entered` (CR-20 FP-8 scope-aware lint applies only to `_ready()`).

### `document_collected` subscription for objective completion

The "Recover Plaza Document" objective uses `completion_signal = &"document_collected"`. MLS subscribes to `Events.document_collected` when the objective becomes ACTIVE:

```gdscript
# In _activate_objective(obj: MissionObjective):
if obj.completion_signal != &"":
    var signal_ref: Signal = Events.get(obj.completion_signal)  # runtime lookup
    if signal_ref:
        signal_ref.connect(_on_objective_completion_signal.bind(obj.objective_id))
```

On `document_collected(doc_id: StringName)` fires: MLS calls the `completion_filter_method` (if set) to check `doc_id == &"doc_plaza_maintenance"`, then emits `objective_completed(&"recover_plaza_document")`.

### Integration test playthrough (AC-MLS-9.1)

The full VS lifecycle test:
1. `section_entered(&"plaza", NEW_GAME)` → `mission_started(&"eiffel_tower")` + `objective_started(&"recover_plaza_document")`
2. Player walks through Plaza document pickup → `document_collected(&"doc_plaza_maintenance")`
3. MLS detects completion → `objective_completed(&"recover_plaza_document")`
4. F.1 gate: only required objective COMPLETED → `mission_completed(&"eiffel_tower")`
5. `section_entered(&"plaza", FORWARD)` at some point in the flow → assembler chain called → `SaveLoadService.save_to_slot(0, sg)` called

All 4 signal emissions verified in order by the Events spy.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: MLS autoload scaffold
- Story 002: State machine core logic, prereq cycle detection
- Story 003: Plaza scene required nodes (respawn point, discovery surface)
- Story 004: FORWARD autosave assembly chain (called here but implemented there)
- Post-VS: Multi-section trigger choreography (Lower, Restaurant, Upper, Bomb Chamber beats)
- Post-VS: Bomb-disarm sequence (T4 Fire-Drill Klaxon, Upper Structure `disarm_bomb` objective)
- Post-VS: `scripted_dialogue_trigger` signal emission for Plaza banter beats (`plaza_radiator_curiosity_bait` — part of D&S integration, deferred to Cutscenes & Mission Cards epic and D&S epic)
- Post-VS: T3 Comedic Choreography (Foreman's Lunch Inventory Lower beat — animation budget unconfirmed per OQ-MLS-ANIM-1)
- Post-VS: T5 Mission-Gadget Beat (Parfum Restaurant — gadget pickup is VS-scoped but scripted-beat authoring is post-VS)
- Post-VS: `peek_surface` / `placeable_surface` collision tags (no peek/placement in VS per EPIC.md VS Scope Guidance)
- Post-VS: T6 full audio bark bank (alert-state comedy fires are plumbed in this story but audio routing is post-VS Audio GDD coord item §A.3.5)

---

## QA Test Cases

**AC-MLS-4.1 — MLSTrigger single-fire latch**
- Given: `MLSTrigger` instance with `trigger_id = &"t_plaza_doc_zone"` and `MissionState.triggers_fired = {}`; player body enters Area3D
- When: `body_entered(player_body)` fires
- Then: `triggers_fired[&"t_plaza_doc_zone"] == true`; `monitoring == false` (deferred); second body entry produces no additional `_run_beat_body()` call
- Edge cases: player body freed before `body_entered` processes (E.22) → `is_instance_valid` returns false → no action, no crash; body enters while already in `triggers_fired` → early return before any beat body

**AC-MLS-4.2 — FP-5 body_exited CI fence**
- Given: CI grep `body_exited` on `src/gameplay/mission/`
- When: any MLS file pushed
- Then: zero matches → exit 0; any match (including `body_exited.connect(...)` or `body_exited = ...`) → exit 1
- Edge cases: `body_exited` inside a comment (preceded by `#`) — grep pattern should be `^[^#]*body_exited` to exclude commented-out lines; document in CI script

**AC-MLS-5.1 — Beat does not replay on RESPAWN**
- Given: `MissionState.fired_beats = {&"t1_plaque_debate": true}` (from slot-0 restore); Plaza section reloaded on RESPAWN
- When: `section_entered(&"plaza", RESPAWN)` fires; Eve re-enters the Plaza
- Then: `MLSTrigger("t1_plaque_debate").monitoring == false`; beat body not called; spy on beat body records 0 calls
- Edge cases: beat fires and THEN player dies before FORWARD save — slot 0 does not have `fired_beats` entry; on RESPAWN the beat would re-fire (E.8 / OQ-MLS-2). This test documents the CORRECT behavior (beat does not re-fire when slot-0 DOES contain the entry); the OQ-MLS-2 race is a KNOWN open question.

**AC-MLS-9.1 — Full signal dispatch integration (NEW_GAME → COMPLETED)**
- Given: integration test harness; `eiffel_tower/mission.tres` with one objective `recover_plaza_document`; test proxy subscribes to all 4 Mission-domain signals
- When: (1) `section_entered(FORWARD or NEW_GAME)` fires; (2) `document_collected(&"doc_plaza_maintenance")` fires
- Then: signals fired in order: `mission_started` → `objective_started` → `objective_completed` → `mission_completed`; none duplicated; no extra signals
- Edge cases: `mission_completed` fires before `objective_completed` → ordering violation, test fails; `objective_started` fires twice for same objective → duplication violation, test fails

**AC-MLS-14.6 — T6 per-frame burst cap at N=2 concurrent guards**
- Given: `_t6_fired_this_frame = false`; spy on `_fire_t6_beat`; two SAI SUSPICIOUS events in same physics frame
- When: `alert_state_changed(guard1, UNAWARE, SUSPICIOUS, severity)` and `alert_state_changed(guard2, UNAWARE, SUSPICIOUS, severity)` both processed in same frame
- Then: `_fire_t6_beat` called exactly once; `_t6_fired_this_frame` reset to false by deferred call in next frame
- Edge cases: single guard (N=1) → fires normally (no burst condition); N=3 guards same frame → still exactly 1 fire

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/feature/mission_level_scripting/signal_dispatch_integration_test.gd` — AC-MLS-9.1, AC-MLS-9.4, must exist and pass
- `tests/unit/feature/mission_level_scripting/mls_trigger_test.gd` — AC-MLS-4.1, 4.2, 4.3, 4.4, 14.7, must exist and pass
- `tests/unit/feature/mission_level_scripting/beat_lifecycle_test.gd` — AC-MLS-5.1, 5.5, must exist and pass
- `tests/unit/feature/mission_level_scripting/t6_burst_limit_test.gd` — AC-MLS-14.6, must exist and pass
- `tests/unit/feature/mission_level_scripting/signal_dispatch_test.gd` — AC-MLS-9.2, 9.3, must exist and pass
- All integration tests: deterministic harness, no random seeds, uses stub document_collected emission rather than full player-input simulation

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (MLS autoload), Story 002 (RUNNING state, objective state machine), Story 003 (Plaza section scene with document WorldItem placed), Story 004 (FORWARD autosave chain — `fired_beats` persisted to slot 0); Document Collection epic must have `document_collected` signal declared on `Events` and must emit it when the Plaza document is picked up
- Unlocks: (Epic DONE when this story is DONE — all 5 VS stories complete); post-VS multi-section trigger authoring can begin; Cutscenes & Mission Cards VS epic integration handshake (CR-13 forward surface confirmed working)

## Open Questions

- **OQ-MLS-2**: Confirm F&R's dying-state save (on `player_died`) captures `MissionState.triggers_fired`. If not, beats fired between the last FORWARD save and the death event will re-fire on RESPAWN (E.8). This story documents the problem; the fix is a F&R epic coordinate. Verify with F&R implementation team before marking this story Done if OQ-MLS-2 is still unresolved.
- **TR-MLS-009 / ADR-0006 coord item #14**: The `MLSTrigger` Area3D collision layer is using `MASK_PLAYER` as a temporary VS measure. The formal Triggers layer must be added to ADR-0006 and `PhysicsLayers` before Production sprint. Add a `TODO` comment at every `collision_mask = PhysicsLayers.MASK_PLAYER` assignment in `MLSTrigger._ready()`.
