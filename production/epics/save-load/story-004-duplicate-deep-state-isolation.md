# Story 004: duplicate_deep state-isolation discipline

> **Epic**: Save / Load
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 1-2 hours (S — small focused test on the production schema; documentation + helper)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/save-load.md`
**Requirement**: TR-SAV-006 (`Resource.duplicate_deep()` MANDATORY on load before handing state to live systems)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Save Format Contract)
**ADR Decision Summary**: Callers MUST call `loaded_save.duplicate_deep()` before handing nested state to live systems. Otherwise mutations to live state would mutate the cached loaded resource (Godot's `ResourceLoader` caches by path) — a subsequent reload of the same slot would return the post-mutation state instead of the on-disk state. Sprint 01 verification Gate 3 (2026-04-29) confirmed the API exists and performs deep-copy semantics through nested typed Dictionaries on a stub `TestSaveGame`. This story performs the production-scope confirmation: deep-copy isolation across the actual `SaveGame` with all 7 sub-resources populated (including `StealthAIState.guards: Dictionary[StringName, GuardRecord]` — the structural shape godot-specialist 2026-04-22 §5 specifically called out as needing extended-scope verification).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Resource.duplicate_deep()` is a Godot 4.5+ API (post-cutoff for the LLM training data, but Sprint 01-verified for this project). It performs a deep recursive copy of nested Resource fields. Sprint 01 G3 confirmed it works correctly with `Dictionary[StringName, int]` and `Dictionary[StringName, bool]` shapes (TestSaveGame's `ammo_magazine` + `fired_beats` analogues). This story verifies it works with `Dictionary[StringName, Resource-typed]` (StealthAIState.guards with GuardRecord values), which is the same structural shape but with Resource-typed values — confirming the same deep-copy discipline holds for the production schema.

**Control Manifest Rules (Foundation)**:
- Required: callers MUST call `loaded_save.duplicate_deep()` before handing nested state to live systems (ADR-0003 IG 3)
- Forbidden: hand a loaded SaveGame's nested state to live systems without `duplicate_deep()` — pattern `forgotten_duplicate_deep_on_load` (formal registration in Story 009)

---

## Acceptance Criteria

*From GDD §Acceptance Criteria + ADR-0003 §Validation Criteria Gate 3:*

- [x] **AC-1**: A unit test populates a `SaveGame` with all 7 sub-resources non-empty (per Story 001's round-trip fixture). Calls `var copy: SaveGame = original.duplicate_deep()`. Asserts `copy != original` (different Resource instances) AND each nested field is also a different instance (`copy.player != original.player`, `copy.inventory != original.inventory`, `copy.stealth_ai != original.stealth_ai`, etc. — across all 7 sub-resources).
- [x] **AC-2**: GIVEN the duplicated SaveGame from AC-1, WHEN the test mutates `copy.player.position = Vector3(99, 99, 99)`, THEN `original.player.position` is unchanged.
- [x] **AC-3**: GIVEN `copy` from AC-1, WHEN the test mutates `copy.inventory.ammo_magazine[&"silenced_p38"] = 999`, THEN `original.inventory.ammo_magazine[&"silenced_p38"]` retains its original value (extending Sprint 01 G3 to the production schema's `Dictionary[StringName, int]` shape).
- [x] **AC-4**: GIVEN `copy` from AC-1, WHEN the test mutates `copy.stealth_ai.guards[&"plaza_guard_01"].alert_state = 99`, THEN `original.stealth_ai.guards[&"plaza_guard_01"].alert_state` is unchanged AND `copy.stealth_ai.guards[&"plaza_guard_01"]` is a different `GuardRecord` instance from `original.stealth_ai.guards[&"plaza_guard_01"]` (`Dictionary[StringName, GuardRecord]` deep-copy verification — godot-specialist 2026-04-22 §5 extended scope).
- [x] **AC-5**: GIVEN `copy` from AC-1, WHEN the test mutates `copy.mission.fired_beats[&"beat_intro"] = false`, THEN `original.mission.fired_beats[&"beat_intro"]` retains its original value (`Dictionary[StringName, bool]` shape — A4 amendment field).
- [x] **AC-6**: GIVEN `copy` from AC-1, WHEN the test mutates `copy.documents.collected.append(&"doc_002")`, THEN `original.documents.collected` does NOT contain `&"doc_002"` (`Array[StringName]` deep-copy verification).
- [x] **AC-7**: StringName keys in dictionaries remain interned-identical across `duplicate_deep()` (i.e., `original.stealth_ai.guards.keys()[0] == copy.stealth_ai.guards.keys()[0]` is true; StringName interning is global, only the values are deep-copied — confirms expected Godot semantics).

---

## Implementation Notes

*Derived from ADR-0003 §Implementation Guidelines + Sprint 01 verification log:*

This story is primarily **a test + a documented discipline**, not a new code path. `load_from_slot()` itself does NOT call `duplicate_deep()` (per Story 003 IG 3 — that's the caller's responsibility, not the service's).

**What this story produces**:

1. **Production-scope test** at `tests/unit/foundation/save_load_duplicate_deep_test.gd` — exercises all 7 sub-resources of the production `SaveGame` schema (vs Sprint 01 G3 which used a stub `TestSaveGame` with only 2 fields). Specifically validates the `Dictionary[StringName, GuardRecord]` deep-copy that godot-specialist 2026-04-22 §5 called out.

2. **Optional helper / documentation comment** in `save_load_service.gd` — a brief comment near `load_from_slot()`'s return statement reminding callers to call `duplicate_deep()` before handing state to live systems. Example:
   ```gdscript
   # Caller is responsible for calling .duplicate_deep() before handing
   # nested state to live systems. See ADR-0003 IG 3.
   return save_game
   ```
   (No helper function — explicit `duplicate_deep()` at call sites is more visible than a wrapper.)

3. **Forbidden-pattern documentation** — Story 009 formally registers `forgotten_duplicate_deep_on_load` in `docs/registry/architecture.yaml` and adds a code-review checklist row. This story does NOT touch the registry (separation of concerns), but the test in this story is the *runtime* check that Story 009's *static* lint complements.

**Why this is a separate story rather than rolled into Story 003**: `duplicate_deep()` is a discipline at the *call site* (where Mission Scripting / F&R / Menu System calls `SaveLoad.load_from_slot` and then operates on the result), NOT inside the service. Story 003 owns the service's read path; this story owns the discipline that consumers must follow when they receive the result. Bundling them would couple SaveLoadService to consumer-side logic — which is exactly the `save_service_assembles_state` anti-pattern the design avoids.

**Test fixture reuse**: import the populated SaveGame fixture from Story 001's round-trip test (factor it into a shared `tests/fixtures/save_game_fixture.gd` helper if necessary; otherwise duplicate the population code with a comment noting the shared shape).

**StringName interning** (AC-7): StringName is a globally interned string in Godot. `duplicate_deep()` deep-copies *values* but does NOT need to deep-copy StringName *keys* — the same StringName instance is reused because that's the engine-level contract for StringName. The test asserts this is the observed behavior. (Not a bug; documented as expected for clarity.)

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: `SaveGame` schema (already done)
- Story 002: write path (already done)
- Story 003: `load_from_slot()` (already done; this story does NOT modify it)
- Story 005: metadata sidecar
- Story 008: state machine
- Story 009: formal registration of `forgotten_duplicate_deep_on_load` in the registry + lint tests (this story's scope is the runtime test, not the static lint)
- Caller-side discipline at consumer epics — Mission Scripting / F&R / Menu System will each call `duplicate_deep()` themselves; this story doesn't author those call sites

---

## QA Test Cases

**AC-1 — duplicate_deep produces fully isolated SaveGame instance**
- **Given**: a populated `SaveGame original` with all 7 sub-resources non-null and non-empty (use Story 001's fixture pattern)
- **When**: `var copy: SaveGame = original.duplicate_deep() as SaveGame`
- **Then**: `copy != original` (Resource instance identity differs); for each of the 7 sub-resources `f in [player, inventory, stealth_ai, civilian_ai, documents, mission, failure_respawn]`: `copy.f != original.f`
- **Edge cases**: a sub-resource is null on `original` → `copy.f` is also null (no exception); a sub-resource Dictionary is empty → `copy.f` Dictionary is also empty but a separate Dictionary instance

**AC-2 — Player position mutation isolated**
- **Given**: `copy` from AC-1; `original.player.position = Vector3(1, 2, 3)`
- **When**: `copy.player.position = Vector3(99, 99, 99)`
- **Then**: `original.player.position == Vector3(1, 2, 3)`
- **Edge cases**: Vector3 is a value type — Godot copies it on assignment regardless of `duplicate_deep`; this AC verifies the documented behavior holds

**AC-3 — Ammo Dictionary mutation isolated (Dictionary[StringName, int] shape)**
- **Given**: `original.inventory.ammo_magazine = {&"silenced_p38": 7}`; `copy` from AC-1
- **When**: `copy.inventory.ammo_magazine[&"silenced_p38"] = 999`
- **Then**: `original.inventory.ammo_magazine[&"silenced_p38"] == 7`
- **Edge cases**: the dictionary instance itself is also separate — `copy.inventory.ammo_magazine != original.inventory.ammo_magazine` (assert with `is_same` if available, else by mutation+verification)

**AC-4 — Guard alert_state mutation isolated (Dictionary[StringName, GuardRecord] shape — godot-specialist 2026-04-22 §5 extended scope)**
- **Given**: `original.stealth_ai.guards = {&"plaza_guard_01": GuardRecord(alert_state=2, patrol_index=3, ...)}`; `copy` from AC-1
- **When**: `copy.stealth_ai.guards[&"plaza_guard_01"].alert_state = 99`
- **Then**: `original.stealth_ai.guards[&"plaza_guard_01"].alert_state == 2`; `copy.stealth_ai.guards[&"plaza_guard_01"]` is a different GuardRecord instance from `original.stealth_ai.guards[&"plaza_guard_01"]` (i.e., the Resource value in the Dictionary was deep-copied, not just the Dictionary container)
- **Edge cases**: this is the load-bearing test that validates Sprint 01 G3's extended scope on the production schema; if it fails, ADR-0003 G3 must re-open and the verification must be re-run on the production schema

**AC-5 — fired_beats mutation isolated (Dictionary[StringName, bool] shape — A4 amendment)**
- **Given**: `original.mission.fired_beats = {&"beat_intro": true}`; `copy` from AC-1
- **When**: `copy.mission.fired_beats[&"beat_intro"] = false`
- **Then**: `original.mission.fired_beats[&"beat_intro"] == true`
- **Edge cases**: matches Sprint 01 G3's `fired_beats` test on the stub TestSaveGame — confirms the same isolation holds when the field is on the production `MissionState` Resource

**AC-6 — Document collection Array mutation isolated (Array[StringName] shape)**
- **Given**: `original.documents.collected = [&"doc_001"]`; `copy` from AC-1
- **When**: `copy.documents.collected.append(&"doc_002")`
- **Then**: `original.documents.collected == [&"doc_001"]` (length 1; does NOT contain `&"doc_002"`)
- **Edge cases**: typed Array deep-copy — `Array[StringName]` is a deep-copyable typed array; verify `copy.documents.collected != original.documents.collected` as separate instances

**AC-7 — StringName keys remain interned-identical across deep copy**
- **Given**: `original.stealth_ai.guards = {&"plaza_guard_01": GuardRecord.new()}`; `copy` from AC-1
- **When**: `var orig_key = original.stealth_ai.guards.keys()[0]; var copy_key = copy.stealth_ai.guards.keys()[0]`
- **Then**: `orig_key == copy_key` is true (StringName equality); `orig_key.hash() == copy_key.hash()`
- **Edge cases**: a StringName is globally interned — Godot's `duplicate_deep()` does NOT create a new interned StringName; the keys point to the same interned table entry. This AC documents the expected behavior so future readers don't get surprised.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/foundation/save_load_duplicate_deep_test.gd` — must exist and pass (covers all 7 ACs)
- Naming follows Foundation-layer convention
- Determinism: fully in-memory, no file I/O, no random data — fixed StringName / int / Vector3 fixtures

**Status**: [x] Created — 2026-04-30 (7 functions in `save_load_duplicate_deep_test.gd`; suite 67/67 PASS)

---

## Dependencies

- Depends on: Story 001 (production SaveGame schema must exist with all 7 sub-resources)
- Unlocks: Story 009 (anti-pattern fence registration; this story is the runtime proof, Story 009 is the static lint)

---

## Completion Notes

**Completed**: 2026-04-30
**Criteria**: 7/7 PASS (all auto-verified)
**Suite**: 67/67 PASS, 0 errors, 0 failures, 0 orphans, exit 0

**Files changed (2)**:
- `src/core/save_load/save_load_service.gd` — added 3-line caller-discipline reminder comment near `load_from_slot()` return (per ADR-0003 IG 3; references Story SL-009's forbidden-pattern lint)
- `tests/unit/foundation/save_load_duplicate_deep_test.gd` — created. 7 test functions covering all 7 ACs: AC-1 distinct instances for all 7 sub-resources, AC-2 player position isolation, AC-3 ammo Dict[StringName,int] isolation, AC-4 GuardRecord-in-Dict isolation (godot-specialist 2026-04-22 §5 extended scope), AC-5 fired_beats Dict[StringName,bool] isolation (A4 amendment), AC-6 Array[StringName] isolation, AC-7 StringName key interning preservation.

**Deviations**: None.

**Code Review**: APPROVED (solo mode; inline review). Implementation per ADR-0003 IG 3; production-schema deep-copy verified including the load-bearing AC-4 nested-Resource Dictionary case.

**Tech debt logged**: None.

**Critical proof points**:
- AC-4 (the godot-specialist 2026-04-22 §5 follow-up) PASSES on the production schema — `Dictionary[StringName, GuardRecord]` deep-copies its Resource values, mutations to `copy.guards[k].alert_state` do not propagate to `original.guards[k].alert_state`, and the GuardRecord instances are different objects.
- StringName key interning behaviour documented as expected Godot contract (AC-7) — keys equal across deep-copy, hash-identical, both typed TYPE_STRING_NAME.

**Save/Load chain CLOSED**: SL-001 (data) + SL-002 (write) + SL-003 (read) + SL-004 (isolation) all done. The end-of-sprint demo loop (save → quit → reload → resume) is now structurally feasible — the only remaining gap is the level streaming integration (LS-001/002) and player movement (PC-001..005) that closes the visible "walk around the Plaza" half of the demo.
