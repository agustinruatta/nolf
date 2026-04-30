# Story 002: SaveLoadService autoload + save_to_slot atomic write

> **Epic**: Save / Load
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3-4 hours (L — autoload registration + atomic-write protocol + perf test + power-loss simulation)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/save-load.md`
**Requirement**: TR-SAV-001 (binary `.res` format), TR-SAV-003 (caller-assembly), TR-SAV-005 (atomic write), TR-SAV-013 (perf budget)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Save Format Contract) + ADR-0007 (Autoload Load Order Registry)
**ADR Decision Summary**: `SaveLoadService` is an autoload at line 3 of `project.godot [autoload]` (per ADR-0007 §Key Interfaces, after `Events` line 1 and `EventLogger` line 2, before `InputContext` line 4). It writes/reads files only — it does NOT query game systems to assemble a `SaveGame`. Atomic write protocol: write to `slot_N.tmp.res` → verify `ResourceSaver.save() == OK` → `DirAccess.rename(tmp, final)` → write metadata sidecar → emit `Events.game_saved`. On any failure: emit `Events.save_failed(reason)`, return `false`, leave previous good save intact.

**Engine**: Godot 4.6 | **Risk**: LOW (post-Sprint-01)
**Engine Notes**: Sprint 01 verification spike (2026-04-29) on Godot 4.6.2 stable closed all 3 ADR-0003 verification gates: G1 (`ResourceSaver.save` with `FLAG_COMPRESS` round-trip integrity), G2 (`DirAccess.rename` atomic on Linux — Windows verification deferred to first Production sprint), G3 (`Resource.duplicate_deep`). Two findings folded into ADR-0003 Amendment A5: F1 (atomic-write tmp filename MUST end in `.res` not `.tmp` — `ResourceSaver.save()` selects format from extension and returns `ERR_FILE_UNRECOGNIZED` for `.tmp`), F2 (top-level `class_name` discipline — already addressed in Story 001). Production code may rely on the verified APIs without re-verifying.

**Control Manifest Rules (Foundation)**:
- Required: atomic write pattern — `slot_N.tmp.res` → verify OK → `DirAccess.rename(tmp, final)` (ADR-0003 IG 5; tmp basename MUST end in `.res` per finding F1)
- Required: `SaveLoadService` accepts a pre-assembled `SaveGame` — does NOT query game systems (ADR-0003 IG 2)
- Required: 8 save slots — `slot_0` autosave + `slot_1`..`slot_7` manual (ADR-0003 IG 7)
- Required: on save failure, emit `Events.save_failed(reason)`, return `false`, leave previous good save intact (ADR-0003 IG 9)
- Required: `_init()` MUST NOT reference any other autoload by name; `_ready()` MAY reference autoloads at earlier line numbers only (ADR-0007 IG 3, IG 4)
- Forbidden: `SaveLoadService` querying game systems to assemble `SaveGame` — pattern `save_service_assembles_state` (lint enforced in Story 009)
- Performance: ≤2 ms save latency (5 KB save, SSD); ≤10 ms worst case (spinning disk)

---

## Acceptance Criteria

*From GDD §Acceptance Criteria + ADR-0003 §Key Interfaces:*

- [ ] **AC-1**: `src/core/save_load/save_load_service.gd` declares `class_name SaveLoadService extends Node` with the `FailureReason` enum (`NONE`, `IO_ERROR`, `VERSION_MISMATCH`, `CORRUPT_FILE`, `SLOT_NOT_FOUND`, `RENAME_FAILED`) and the `SAVE_DIR: String = "user://saves/"` const.
- [ ] **AC-2**: `project.godot [autoload]` block contains `SaveLoad="*res://src/core/save_load/save_load_service.gd"` at line 3 (after `Events` line 1, `EventLogger` line 2; before `InputContext` line 4) — verbatim match with ADR-0007 §Key Interfaces.
- [ ] **AC-3**: `save_to_slot(slot: int, save_game: SaveGame) -> bool` follows the atomic write sequence: (1) `ResourceSaver.save(save_game, "user://saves/slot_<N>.tmp.res", ResourceSaver.FLAG_COMPRESS)`, (2) check return == `OK`, (3) `DirAccess.rename(tmp, final)`. The tmp filename MUST end in `.res` (Sprint 01 finding F1).
- [ ] **AC-4**: GIVEN `ResourceSaver.save()` returns a non-OK error, WHEN `save_to_slot` responds, THEN `Events.save_failed.emit(FailureReason.IO_ERROR)` fires AND the previous slot file (if any) is untouched on disk AND the function returns `false`. (AC-7 from GDD.)
- [ ] **AC-5**: GIVEN `DirAccess.rename(tmp, final)` returns non-OK, WHEN `save_to_slot` responds, THEN `Events.save_failed.emit(FailureReason.RENAME_FAILED)` fires AND tmp file is cleaned up AND previous final-slot file is untouched AND the function returns `false`.
- [ ] **AC-6**: GIVEN a successful save, WHEN the function completes, THEN `Events.game_saved.emit(slot, save_game.section_id)` fires AND the function returns `true` AND `user://saves/slot_<N>.res` exists on disk.
- [ ] **AC-7**: GIVEN a normal save operation on SSD with a populated `SaveGame` (~5 KB), WHEN save completes, THEN elapsed time from `save_to_slot` call to `Events.game_saved` emit is ≤10 ms (per ADR-0003 budget; AC-22 from GDD).
- [ ] **AC-8**: Power-loss simulation — GIVEN a previous good save at `user://saves/slot_3.res` and a save in progress that is killed mid-`ResourceSaver.save()` (simulated by writing the tmp file then NOT renaming, then re-launching the test), WHEN the test re-reads slot 3, THEN the previous good save loads intact AND no half-written tmp file is present after cleanup.
- [ ] **AC-9**: GIVEN `save_load_service.gd` source, WHEN grepped for `PlayerCharacter`, `StealthAI`, `Inventory`, `MissionScripting`, or any other gameplay system class name, THEN zero matches (per `save_service_assembles_state` forbidden pattern; AC-24 from GDD). *Classification: lint check (formal registration in Story 009).*
- [ ] **AC-10**: `_ready()` references only autoloads at lines 1–2 (`Events`, `EventLogger`) — never `InputContext`, `LevelStreamingService`, or any later autoload. `_init()` references no autoloads (per ADR-0007 §Cross-Autoload Reference Safety rules 3 + 4).

---

## Implementation Notes

*Derived from ADR-0003 §Implementation Guidelines + §Architecture diagram + ADR-0007 §Canonical Registration Table:*

**Autoload registration**: Add line 3 to `project.godot [autoload]` block. The full block must match ADR-0007 §Key Interfaces verbatim (10 entries, `*res://` prefix on each). For Sprint 01 the entries before this story may have been stub `extends Node` pass-throughs — replace `SaveLoad` with the production `SaveLoadService` class.

**`SaveLoadService` shape** (from ADR-0003 §Key Interfaces):

```gdscript
class_name SaveLoadService extends Node

enum FailureReason {
    NONE,
    IO_ERROR,
    VERSION_MISMATCH,
    CORRUPT_FILE,
    SLOT_NOT_FOUND,
    RENAME_FAILED,
}

const SAVE_DIR: String = "user://saves/"

func save_to_slot(slot: int, save_game: SaveGame) -> bool:
    # 1. Ensure SAVE_DIR exists (DirAccess.make_dir_recursive_absolute)
    # 2. Compute paths: tmp = "user://saves/slot_N.tmp.res", final = "user://saves/slot_N.res"
    # 3. ResourceSaver.save(save_game, tmp, ResourceSaver.FLAG_COMPRESS)
    # 4. If non-OK: emit Events.save_failed(IO_ERROR); return false
    # 5. DirAccess.rename(tmp, final)
    # 6. If non-OK: cleanup tmp; emit save_failed(RENAME_FAILED); return false
    # 7. (Story 005) write metadata sidecar
    # 8. Emit Events.game_saved(slot, save_game.section_id)
    # 9. Return true
```

**Atomic write tmp suffix** (Sprint 01 finding F1): tmp basename ends in `.res` (e.g., `slot_0.tmp.res`), NOT `.tmp`. `ResourceSaver.save()` selects format from extension; `.tmp` returns `ERR_FILE_UNRECOGNIZED` (15).

**`SaveGame` assembly is NOT this story's responsibility.** Tests construct a `SaveGame` directly (using Story 001's data layer) and pass it in. Mission Scripting will assemble `SaveGame` in its own epic; F&R will assemble in its own epic.

**Signal emits** rely on signals declared by the Signal Bus epic (`Events.game_saved`, `Events.save_failed`). These signal declarations are scheduled in `production/epics/signal-bus/story-002-builtin-type-signals.md`. If they are not yet declared at implementation time, this story is BLOCKED until they are.

**Power-loss simulation** (AC-8): the test creates a tmp file at `user://saves/slot_3.tmp.res` without renaming it (simulating mid-write process kill), creates a previous-good `slot_3.res`, then re-launches a fresh `SaveLoadService` instance and verifies (a) `slot_3.res` still loads correctly, (b) the orphan tmp can be cleaned up by a subsequent successful save (or explicit cleanup pass) without affecting `slot_3.res`.

**Performance test** (AC-7): instrument `Time.get_ticks_usec()` at function entry and at `Events.game_saved` emit; assert elapsed ≤10 ms on a populated SaveGame. Run in CI on a representative SSD; flag if a future change regresses past 5 ms (50% of budget).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: SaveGame Resource + 7 typed sub-resources (data layer — already done)
- Story 003: `load_from_slot()` — read path with type-guard + version-mismatch
- Story 004: `duplicate_deep()` discipline + production-scope isolation test
- Story 005: metadata sidecar (`slot_N_meta.cfg`) write + `slot_metadata()` API
- Story 006: 8-slot scheme + slot-0 mirror on manual save (CR-4)
- Story 007: Quicksave/Quickload (F5/F9) + InputContext gating
- Story 008: Sequential save queueing (state machine)
- Story 009: Anti-pattern fences + registry entries + lint guards (formal grep test)

---

## QA Test Cases

**AC-1 — SaveLoadService class shape**
- **Given**: `src/core/save_load/save_load_service.gd` source
- **When**: a unit test loads the script and inspects properties
- **Then**: `class_name == "SaveLoadService"`; extends `Node`; `FailureReason` enum has 6 members in the documented order; `SAVE_DIR == "user://saves/"`
- **Edge cases**: missing `class_name` → autoload still registers but `class_name`-typed references break

**AC-2 — Autoload registered at line 3**
- **Given**: `project.godot` `[autoload]` block
- **When**: a unit test parses the block (read file, find `[autoload]` section, enumerate entries in declared order)
- **Then**: line 3 entry is `SaveLoad="*res://src/core/save_load/save_load_service.gd"`; lines 1, 2, 4 match ADR-0007 entries (`Events`, `EventLogger`, `InputContext`); `*res://` prefix is present on all entries
- **Edge cases**: alphabetical reorder by Godot editor → test fails (per ADR-0007 IG 1: "no reordering by the Godot editor UI"); missing `*` prefix → script-mode (broken — fails)

**AC-3 — Atomic write happy path**
- **Given**: a populated `SaveGame` from Story 001's test fixture; `user://saves/` exists; no previous `slot_0.res`
- **When**: `SaveLoad.save_to_slot(0, sg)`
- **Then**: function returns `true`; `user://saves/slot_0.tmp.res` does NOT exist (renamed away); `user://saves/slot_0.res` exists; reloading via `ResourceLoader.load("user://saves/slot_0.res") as SaveGame` returns a SaveGame whose `section_id` matches the original's
- **Edge cases**: tmp filename `.tmp` (not `.res`) → `ResourceSaver.save()` returns `ERR_FILE_UNRECOGNIZED` (Sprint 01 F1); test must verify the `.res` suffix on tmp

**AC-4 — IO_ERROR on ResourceSaver failure**
- **Given**: a populated `SaveGame`; `user://saves/` is read-only (or use a fault-injection wrapper that forces `ResourceSaver.save` to return non-OK)
- **When**: `save_to_slot(0, sg)` is called
- **Then**: function returns `false`; `Events.save_failed` was emitted exactly once with `FailureReason.IO_ERROR`; previous `slot_0.res` (if any) is byte-identical to its pre-call state
- **Edge cases**: previous slot file did not exist → only the absence-of-tmp invariant matters; verify no tmp file leaked

**AC-5 — RENAME_FAILED on rename failure**
- **Given**: a populated `SaveGame`; `ResourceSaver.save()` succeeds but `DirAccess.rename()` is forced to fail (file lock, mock injection)
- **When**: `save_to_slot(0, sg)` is called
- **Then**: function returns `false`; `Events.save_failed` emitted with `FailureReason.RENAME_FAILED`; tmp file at `user://saves/slot_0.tmp.res` is cleaned up (NOT left orphaned); previous `slot_0.res` (if any) is byte-identical to its pre-call state
- **Edge cases**: cleanup-on-rename-fail itself fails → log warning, still return false (do not destructively retry — ADR-0003 IG 9)

**AC-6 — game_saved emit on success**
- **Given**: a populated `SaveGame` with `section_id = &"restaurant"`
- **When**: `save_to_slot(3, sg)` succeeds
- **Then**: `Events.game_saved` emitted exactly once with arguments `(3, &"restaurant")`; no `Events.save_failed` emit; function returns `true`
- **Edge cases**: subscriber list empty → emit is no-op but assertion of "emitted" still passes (use signal-spy helper)

**AC-7 — Save latency ≤10 ms**
- **Given**: a populated `SaveGame` (~5 KB representative payload)
- **When**: `save_to_slot(0, sg)` runs on local SSD
- **Then**: elapsed time `Time.get_ticks_usec()` from function entry to `Events.game_saved` emit is ≤10000 µs
- **Edge cases**: warm cache vs cold cache — test runs save twice and asserts both runs are ≤10 ms; CI runner variability — set CI threshold to 15 ms with warning; local dev threshold 10 ms

**AC-8 — Power-loss simulation (orphan tmp + previous good intact)**
- **Given**: a previous good `slot_3.res` (written successfully by a prior save); manually create an orphan `slot_3.tmp.res` (simulating a process kill mid-write); fresh `SaveLoadService` instance loaded from autoload
- **When**: a test asserts `slot_3.res` still loads as a valid SaveGame; then a subsequent `save_to_slot(3, new_sg)` runs
- **Then**: the prior `slot_3.res` loaded correctly before the new save; after the new save, `slot_3.res` reflects the new payload AND no orphan tmp remains
- **Edge cases**: orphan tmp is a different format/version than current → cleanup must not crash on parse failure; multiple orphan tmps from different slots → each handled independently

**AC-9 — No game-system references in service file**
- **Given**: `src/core/save_load/save_load_service.gd` source
- **When**: a test greps the file for `PlayerCharacter`, `StealthAI`, `CivilianAI`, `Inventory`, `Combat`, `MissionLevelScripting`, `FailureRespawn`, or `DocumentCollection`
- **Then**: zero matches (per `save_service_assembles_state` forbidden pattern; AC-24 from GDD)
- **Edge cases**: comment containing the word "PlayerCharacter" — test should ignore comment-only matches OR the convention is "no such mentions even in comments" (choose strict — comments rot and a future search-and-replace would create false negatives)

**AC-10 — Cross-autoload reference safety**
- **Given**: `save_load_service.gd` source
- **When**: a static analysis test inspects `_init()` and `_ready()` bodies
- **Then**: `_init()` body contains zero references to autoload names (`Events`, `EventLogger`, `InputContext`, `LevelStreamingService`, `PostProcessStack`, `Combat`, `FailureRespawn`, `MissionLevelScripting`, `SettingsService`); `_ready()` body may reference only `Events` or `EventLogger` (lines 1, 2)
- **Edge cases**: `_ready()` references `InputContext` (line 4) → fails ADR-0007 §Cross-Autoload Reference Safety rule 3

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/foundation/save_load_service_save_test.gd` — must exist and pass (covers AC-1, AC-3, AC-4, AC-5, AC-6, AC-7, AC-9, AC-10)
- `tests/integration/foundation/atomic_write_power_loss_test.gd` — must exist and pass (covers AC-2, AC-8)
- Naming follows Foundation-layer convention from signal-bus stories
- Determinism: tests clean up `user://saves/` in setup AND teardown; no cross-test pollution

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (SaveGame Resource + 7 sub-resources must exist), Signal Bus story 002 (`Events.game_saved` and `Events.save_failed` signal declarations must exist)
- Unlocks: Story 003 (load_from_slot reads what this story writes), Story 005 (sidecar write hooks into save_to_slot success path), Story 006 (slot scheme uses save_to_slot), Story 008 (state machine wraps this)
