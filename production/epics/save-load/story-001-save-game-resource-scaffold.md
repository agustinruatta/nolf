# Story 001: SaveGame Resource + 7 typed sub-resource scaffolding

> **Epic**: Save / Load
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 hours (M — 8 new files + round-trip test)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/save-load.md`
**Requirement**: TR-SAV-002 (SaveGame schema), TR-SAV-007 (actor_id convention)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Save Format Contract)
**ADR Decision Summary**: `SaveGame extends Resource` is the canonical save container holding 7 typed `*_State` sub-resources (PlayerState, InventoryState, StealthAIState, CivilianAIState, DocumentCollectionState, MissionState, FailureRespawnState). Each typed-Resource `@export` field MUST reference a top-level `class_name`-registered class in its own file (Sprint 01 verification finding F2). Per-actor identity uses stable `actor_id: StringName`, NOT `NodePath`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Resource` + `@export` + `class_name` are stable Godot 4.0+. ADR-0003 Gate 1 already verified `ResourceSaver.save(...)` round-trip integrity for primitive `@export` fields, nested typed-Resource fields, and `Dictionary[StringName, int]` / `Dictionary[StringName, bool]` typed-dict shapes (Godot 4.6.2 stable, Linux Vulkan, 2026-04-29). The inner-class `@export` trap is documented in IG 11 — every typed-Resource field MUST live in its own file.

**Control Manifest Rules (Foundation)**:
- Required: `SaveGame.FORMAT_VERSION` is a `const`; `save_format_version` is the `@export var` initialized from it (only the `var` is serialized) — ADR-0003 IG 1
- Required: every typed-Resource `@export` field on `SaveGame` MUST reference a top-level `class_name`-registered Resource declared in its own file under `src/core/save_load/states/` — ADR-0003 IG 11
- Required: per-actor identity uses `actor_id: StringName` declared as `@export` on the actor's script — ADR-0003 IG 6
- Forbidden: `NodePath` or `Node` references in saved Resources — pattern `save_state_uses_node_references`
- Forbidden: inner-class typed Resources used as `@export` field types on serialized Resources

---

## Acceptance Criteria

*From GDD §Acceptance Criteria + ADR-0003 §Key Interfaces:*

- [x] **AC-1**: `src/core/save_load/save_game.gd` declares `class_name SaveGame extends Resource` with `const FORMAT_VERSION: int = 2`, `@export var save_format_version: int = FORMAT_VERSION`, `@export var saved_at_iso8601: String`, `@export var section_id: StringName`, `@export var elapsed_seconds: float`, and 7 typed sub-resource `@export` fields (player, inventory, stealth_ai, civilian_ai, documents, mission, failure_respawn).
- [x] **AC-2**: 7 sub-resource files exist under `src/core/save_load/states/`, each with `class_name` registered: `player_state.gd`, `inventory_state.gd`, `stealth_ai_state.gd`, `civilian_ai_state.gd`, `document_collection_state.gd`, `mission_state.gd`, `failure_respawn_state.gd`. (Per ADR-0003 IG 11; the inner-class @export trap is avoided.)
- [x] **AC-3**: `src/core/save_load/states/guard_record.gd` declares `class_name GuardRecord extends Resource` with `alert_state: int`, `patrol_index: int`, `last_known_target_position: Vector3`, `current_position: Vector3`. Used as the value type of `StealthAIState.guards: Dictionary` (per-actor record keyed by `actor_id`).
- [x] **AC-4**: `InventoryState` declares `@export var ammo_magazine: Dictionary` and `@export var ammo_reserve: Dictionary` (untyped Dictionary with doc-comment typing `## StringName -> int`, NOT `TypedDictionary`, per Inventory CR-11 — TypedDictionary `ResourceSaver` stability is unverified post-cutoff).
- [x] **AC-5**: `MissionState` declares `@export var section_id: StringName`, `@export var objectives_completed: Array[StringName]`, `@export var triggers_fired: Dictionary` (`## StringName -> bool`), `@export var fired_beats: Dictionary` (`## StringName -> bool`).
- [x] **AC-6**: `DocumentCollectionState` declares `@export var collected: Array[StringName]`.
- [x] **AC-7**: A round-trip unit test populates a `SaveGame` instance with stub values for all 7 sub-resources (including non-empty `StealthAIState.guards` with one `GuardRecord`, `InventoryState.ammo_magazine` + `ammo_reserve`, and `MissionState.fired_beats`), calls `ResourceSaver.save(sg, "user://test_round_trip.res", ResourceSaver.FLAG_COMPRESS)`, then `ResourceLoader.load("user://test_round_trip.res")`, and asserts every field is bit-equal across the round-trip. (AC-15 from GDD; in-memory only — no slot scheme yet.)

---

## Implementation Notes

*Derived from ADR-0003 §Implementation Guidelines + §Key Interfaces:*

File structure:

```
src/core/save_load/
├── save_game.gd                    (class_name SaveGame)
└── states/
    ├── player_state.gd             (class_name PlayerState)
    ├── inventory_state.gd          (class_name InventoryState)
    ├── stealth_ai_state.gd         (class_name StealthAIState)
    ├── civilian_ai_state.gd        (class_name CivilianAIState)
    ├── document_collection_state.gd (class_name DocumentCollectionState)
    ├── mission_state.gd            (class_name MissionState)
    ├── failure_respawn_state.gd    (class_name FailureRespawnState)
    └── guard_record.gd             (class_name GuardRecord)
```

Field shapes per ADR-0003 §Key Interfaces + the cross-system reconciliation rows in `save-load.md` §Interactions table:

- **PlayerState**: `position: Vector3`, `rotation: Vector3`, `health: int`, `current_state: int` (PlayerCharacter.MovementState enum value)
- **InventoryState**: `equipped_gadget: StringName`, `ammo_magazine: Dictionary`, `ammo_reserve: Dictionary`, `collected_gadget_flags: Dictionary`, `mission_pickup_available: bool`
- **StealthAIState**: `guards: Dictionary` (`## StringName -> GuardRecord`)
- **CivilianAIState**: `panicked: Dictionary` (`## StringName -> bool`) — MVP scope: stub
- **DocumentCollectionState**: `collected: Array[StringName]`
- **MissionState**: `section_id: StringName`, `objectives_completed: Array[StringName]`, `triggers_fired: Dictionary`, `fired_beats: Dictionary`
- **FailureRespawnState**: stub fields per F&R GDD CR-3 (let F&R epic refine; this story scaffolds the file with `class_name` + a placeholder `@export` field that survives round-trip — F&R takes ownership later)

Default values per ADR-0003 §Architecture default-init pattern (e.g., `Vector3.ZERO`, `&""`, `0`, `[]`, `{}`).

Documentation comments on Dictionary fields use `## StringName -> ValueType` syntax for type clarity without TypedDictionary instability (Inventory CR-11).

This story is data-layer-only. No SaveLoadService autoload yet (Story 002). No file I/O at slot scheme (Story 002). The round-trip test writes to `user://test_round_trip.res` directly via `ResourceSaver` to verify the data layer in isolation.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: `SaveLoadService` autoload + `save_to_slot()` + atomic-write protocol
- Story 003: `load_from_slot()` + type-guarding + version-mismatch refusal
- Story 004: `duplicate_deep()` state-isolation discipline (production-scope test)
- Story 005: metadata sidecar (`slot_N_meta.cfg`) write/read
- Per-system gameplay logic that *populates* these states — owned by each consumer epic (Player Character, Inventory, Stealth AI, etc.)

---

## QA Test Cases

**AC-1 — SaveGame schema fields**
- **Given**: `src/core/save_load/save_game.gd` source
- **When**: a unit test reflects on a fresh `SaveGame.new()` instance
- **Then**: `FORMAT_VERSION` const equals `2`; `save_format_version` defaults to `2`; `section_id` defaults to `&""`; `elapsed_seconds` defaults to `0.0`; all 7 sub-resource fields exist as typed `@export` properties (verify via `(SaveGame.new() as Object).get_property_list()`)
- **Edge cases**: missing field → property_list grep fails; const not declared → `SaveGame.FORMAT_VERSION` access errors

**AC-2 — 7 sub-resource files exist with `class_name`**
- **Given**: file system + parsed scripts
- **When**: a unit test calls `load("res://src/core/save_load/states/<file>.gd")` for each of the 7 state files
- **Then**: each load returns a non-null `Script` whose `get_global_name()` matches the expected `class_name` (PlayerState, InventoryState, StealthAIState, CivilianAIState, DocumentCollectionState, MissionState, FailureRespawnState)
- **Edge cases**: missing file → `load()` returns null; missing `class_name` → `get_global_name()` returns empty StringName

**AC-3 — GuardRecord file + fields**
- **Given**: `src/core/save_load/states/guard_record.gd`
- **When**: a unit test creates `GuardRecord.new()`
- **Then**: instance has `alert_state: int = 0`, `patrol_index: int = 0`, `last_known_target_position: Vector3 = Vector3.ZERO`, `current_position: Vector3 = Vector3.ZERO`; class is registered as top-level `class_name GuardRecord` (per ADR-0003 IG 11)
- **Edge cases**: declared as inner class on `StealthAIState` → fails IG 11

**AC-4 — InventoryState ammo two-dict shape**
- **Given**: `InventoryState.new()` instance
- **When**: a unit test reads property metadata
- **Then**: `ammo_magazine` and `ammo_reserve` exist as `@export var Dictionary` (untyped Dictionary, NOT `TypedDictionary`); doc-comment annotation present (verify by source grep for `## StringName -> int`)
- **Edge cases**: declared as `TypedDictionary[StringName, int]` → fails Inventory CR-11

**AC-5 — MissionState fields**
- **Given**: `MissionState.new()` instance
- **When**: a unit test reads property metadata
- **Then**: all 4 fields present with correct types: `section_id: StringName`, `objectives_completed: Array[StringName]`, `triggers_fired: Dictionary`, `fired_beats: Dictionary`
- **Edge cases**: missing `fired_beats` → MLS CR-7 savepoint-persistent-beats invariant violated

**AC-6 — DocumentCollectionState field**
- **Given**: `DocumentCollectionState.new()` instance
- **When**: a unit test reads property metadata
- **Then**: `collected: Array[StringName]` exists; default value is `[]`

**AC-7 — In-memory round-trip integrity**
- **Given**: a fully-populated `SaveGame`:
  - `save_format_version = 2`
  - `section_id = &"test_section"`
  - `elapsed_seconds = 123.45`
  - `player.position = Vector3(1, 2, 3)`, `player.health = 75`
  - `inventory.ammo_magazine = {&"silenced_p38": 7}`, `inventory.ammo_reserve = {&"silenced_p38": 21}`
  - `stealth_ai.guards = {&"plaza_guard_01": GuardRecord_with_alert_state=2_patrol_index=3}`
  - `mission.objectives_completed = [&"obj_1"]`, `mission.fired_beats = {&"beat_intro": true}`
  - `documents.collected = [&"doc_001"]`
- **When**: `ResourceSaver.save(sg, "user://test_round_trip.res", ResourceSaver.FLAG_COMPRESS)` then `var loaded = ResourceLoader.load("user://test_round_trip.res") as SaveGame`
- **Then**: every assertion passes — `loaded.save_format_version == 2`, `loaded.section_id == &"test_section"`, `loaded.player.position == Vector3(1, 2, 3)`, `loaded.inventory.ammo_magazine[&"silenced_p38"] == 7`, `loaded.stealth_ai.guards[&"plaza_guard_01"].alert_state == 2`, `loaded.mission.fired_beats[&"beat_intro"] == true`, etc.
- **Edge cases**:
  - Inner-class `@export` typed-Resource → field comes back `null` (Sprint 01 finding F2). Test must FAIL if any sub-resource has been declared as inner-class.
  - `Dictionary` empty default → loads as `{}`, not `null` (Godot Dictionary default behavior)
  - `StringName` keys in dictionaries — verify `loaded.inventory.ammo_magazine.keys()[0]` is a `StringName` not a `String`
  - Test cleanup: delete `user://test_round_trip.res` in `_exit_tree()` to avoid polluting subsequent runs

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/foundation/save_game_round_trip_test.gd` — must exist and pass
- Naming: `save_game_round_trip_test.gd` (matches Foundation-layer convention from signal-bus stories)
- Determinism: no random seeds; uses fixed StringName keys; cleans up `user://test_round_trip.res` in teardown

**Status**: [x] Created — 2026-04-30 (suite 38/38 PASS, 9 functions in `save_game_round_trip_test.gd`)

---

## Dependencies

- Depends on: None — foundational data layer
- Unlocks: Story 002 (SaveLoadService needs SaveGame to write/read), Story 004 (duplicate_deep test needs the production schema)

---

## Completion Notes

**Completed**: 2026-04-30
**Criteria**: 7/7 PASS (all auto-verified)
**Suite**: 38/38 PASS, 0 errors, 0 failures, 0 orphans, exit 0

**Files created (10)**:
- `src/core/save_load/save_game.gd` — `class_name SaveGame extends Resource`, `FORMAT_VERSION: int = 2`, 7 typed sub-resource `@export` fields, `_init()` default-initializes children
- `src/core/save_load/states/player_state.gd` — `class_name PlayerState`
- `src/core/save_load/states/inventory_state.gd` — `class_name InventoryState` (untyped Dictionary ammo per Inventory CR-11)
- `src/core/save_load/states/stealth_ai_state.gd` — `class_name StealthAIState` (guards keyed by actor_id)
- `src/core/save_load/states/civilian_ai_state.gd` — `class_name CivilianAIState`
- `src/core/save_load/states/document_collection_state.gd` — `class_name DocumentCollectionState`
- `src/core/save_load/states/mission_state.gd` — `class_name MissionState` (fired_beats per MLS CR-7)
- `src/core/save_load/states/failure_respawn_state.gd` — `class_name FailureRespawnState` (placeholder; F&R epic refines)
- `src/core/save_load/states/guard_record.gd` — `class_name GuardRecord` (top-level per ADR-0003 IG 11)
- `tests/unit/foundation/save_game_round_trip_test.gd` — 9 test functions; AC-7 round-trip is comprehensive (all 7 sub-resources + nested GuardRecord + StringName key-type preservation per AC-7 spec)

**Deviations**:
- ADVISORY: TR-SAV-002 registry text lists 6 sub-resources; ADR-0003 + story spec require 7 (adds failure_respawn). Implementation followed ADR. Recommend `/architecture-review` next pass to refresh `tr-registry.yaml` text.

**Code review fixes applied during review**:
- Added StringName key-type preservation assertion to AC-7 round-trip (qa-tester BLOCKING — story explicitly required `keys()[0] is StringName` check)
- Added `ResourceLoader.CACHE_MODE_IGNORE` to round-trip load (prevents stale cache returns in repeated same-session runs)
- Added missing field assertions in round-trip: `player.rotation`, `guard.last_known_target_position`, `inventory.collected_gadget_flags`, `mission.section_id`, `mission.triggers_fired`
- Wrapped `assert_str()` calls on StringName values with `String()` coercion for GdUnit4 type-safety
- Added doc comments to `PlayerState.position/rotation/health` fields
- Replaced `is_equal(2)` with `is_equal(SaveGame.FORMAT_VERSION)` to make the round-trip survive a future FORMAT_VERSION bump

**Tech debt logged**: None. The TR registry staleness is an architecture-doc cleanup task, not code tech debt.

**Test runner notes**:
- New `class_name`s require one `godot --headless --editor --quit-after 2` invocation to refresh the global class cache before GdUnit4 CLI sees them. Documented in session state.
- Test cleanup: `after_test()` removes `user://test_round_trip.res` after each test via `DirAccess` with `file_exists()` guard (no-op for non-I/O tests).

**Critical proof point**: AC-7 round-trip succeeded → proves all 7 typed `@export` sub-resources serialize correctly through `ResourceSaver.save(... FLAG_COMPRESS)` + `ResourceLoader.load`. No IG 11 violations (the F2 trap from Sprint 01 verification) slipped through. StringName Dictionary keys preserved. GuardRecord-as-Dictionary-value round-trips cleanly.
