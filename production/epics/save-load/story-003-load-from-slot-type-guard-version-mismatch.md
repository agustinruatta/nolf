# Story 003: load_from_slot + type-guard + version-mismatch refusal

> **Epic**: Save / Load
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2 hours (M — read path mirrors write path; type-guard + version compare logic)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/save-load.md`
**Requirement**: TR-SAV-008 (refuse-load-on-mismatch versioning), TR-SAV-012 (type-guard after every load)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Save Format Contract)
**ADR Decision Summary**: `load_from_slot()` reads `user://saves/slot_<N>.res` via `ResourceLoader.load`, type-guards against null and class mismatch (binary `.res` returns `null` silently on class-name lookup failure — the most likely silent bug), checks `save_format_version == FORMAT_VERSION` (refuse-load-on-mismatch versioning), and emits `Events.game_loaded(slot)` on success or `Events.save_failed(reason)` on any failure. Returns the loaded `SaveGame` (caller is responsible for `duplicate_deep()` before handing nested state to live systems — Story 004's discipline).

**Engine**: Godot 4.6 | **Risk**: LOW (post-Sprint-01)
**Engine Notes**: `ResourceLoader.load()` is stable Godot 4.0+. The silent-null-on-class-mismatch behavior is a known Godot footgun documented in ADR-0003 §Risks (probability HIGH, impact MEDIUM) — the type-guard pattern is the mandatory defense. Sprint 01 verification confirmed `ResourceSaver`/`ResourceLoader` round-trip integrity for the SaveGame schema (Gate 1).

**Control Manifest Rules (Foundation)**:
- Required: type-guard after every load — `if loaded == null or not (loaded is SaveGame): emit save_failed(CORRUPT_FILE); return null` (ADR-0003 IG 4)
- Required: `SaveGame.FORMAT_VERSION` is the runtime sentinel for compare-on-load; `save_format_version` (the `@export var`) is the on-disk value (ADR-0003 IG 1)
- Required: on save/load failure, emit `Events.save_failed(reason)`, return null/false, leave the previous good save intact (ADR-0003 IG 9)
- Forbidden: auto-delete or auto-recover destructively on load failure (ADR-0003 IG 9)

---

## Acceptance Criteria

*From GDD §Acceptance Criteria + ADR-0003 §Key Interfaces:*

- [ ] **AC-1**: `load_from_slot(slot: int) -> SaveGame` reads `user://saves/slot_<N>.res` via `ResourceLoader.load(path)`. Returns the loaded `SaveGame` on success, `null` on any failure.
- [ ] **AC-2**: GIVEN `slot_<N>.res` does not exist on disk, WHEN `load_from_slot(N)` is called, THEN the function returns `null` AND `Events.save_failed.emit(FailureReason.SLOT_NOT_FOUND)` fires AND no other side effects occur.
- [ ] **AC-3**: GIVEN `ResourceLoader.load(path)` returns `null` (binary `.res` silent class-mismatch failure) OR returns a Resource that is not a `SaveGame`, WHEN `load_from_slot` processes the result, THEN the function returns `null` AND `Events.save_failed.emit(FailureReason.CORRUPT_FILE)` fires. (AC-10 from GDD.)
- [ ] **AC-4**: GIVEN a saved `slot_<N>.res` whose `save_format_version` field is lower than `SaveGame.FORMAT_VERSION` (currently `2`), WHEN `load_from_slot(N)` is called, THEN the function returns `null` AND `Events.save_failed.emit(FailureReason.VERSION_MISMATCH)` fires AND the `slot_<N>.res` file is NOT deleted (per ADR-0003 IG 9 — refuse-load-on-mismatch keeps the file for Menu System to display as `CORRUPT` slot state). (AC-9 from GDD.)
- [ ] **AC-5**: GIVEN a successful load, WHEN the function returns, THEN `Events.game_loaded.emit(slot)` fires AND the returned SaveGame's `save_format_version == FORMAT_VERSION`.
- [ ] **AC-6**: GIVEN the round-trip Story 002 wrote (`save_to_slot(3, sg)`), WHEN `load_from_slot(3)` is called, THEN the returned SaveGame's fields match `sg` field-by-field (`section_id`, `elapsed_seconds`, all 7 sub-resources). (AC-15 from GDD; on-disk round-trip.)
- [ ] **AC-7**: GIVEN a load operation, WHEN the I/O phase completes (before `duplicate_deep` and before scene transition), THEN elapsed time is ≤2 ms (per ADR-0003 budget; AC-23 from GDD).
- [ ] **AC-8**: `load_from_slot()` does NOT call `duplicate_deep()` itself — the caller is responsible (per ADR-0003 IG 3; documented in Story 004's discipline). Test: instrument loaded SaveGame's identity; mutate it; subsequent `load_from_slot()` of the same slot returns a freshly-loaded instance whose state is from disk, not from the previously-mutated instance (i.e., no caching that would leak state).

---

## Implementation Notes

*Derived from ADR-0003 §Key Interfaces + §Implementation Guidelines:*

```gdscript
func load_from_slot(slot: int) -> SaveGame:
    var path: String = "%sslot_%d.res" % [SAVE_DIR, slot]

    if not FileAccess.file_exists(path):
        Events.save_failed.emit(FailureReason.SLOT_NOT_FOUND)
        return null

    var loaded: Resource = ResourceLoader.load(path)
    if loaded == null or not (loaded is SaveGame):
        Events.save_failed.emit(FailureReason.CORRUPT_FILE)
        return null

    var save_game: SaveGame = loaded as SaveGame
    if save_game.save_format_version != SaveGame.FORMAT_VERSION:
        Events.save_failed.emit(FailureReason.VERSION_MISMATCH)
        return null

    Events.game_loaded.emit(slot)
    return save_game
```

**Type-guard pattern is non-negotiable** (IG 4 — registered as a mandatory check in the control manifest): binary `.res` returns `null` silently when the class registered in the file does not match a known `class_name` at load time. Without the guard, callers would dereference a null SaveGame downstream — silent crash.

**`save_format_version` vs `FORMAT_VERSION`**: the `const FORMAT_VERSION` is the runtime sentinel. The `@export var save_format_version` (Story 001) is what's serialized. On load, compare the deserialized var against the const. Lower → VERSION_MISMATCH. Higher → also VERSION_MISMATCH (a save written by a future build). Equal → OK.

**No `duplicate_deep()` here** (Story 004's responsibility): this story just hands back the loaded instance. Callers (Mission Scripting, F&R, Menu System) call `duplicate_deep()` before handing nested state to live systems. Documented in IG 3.

**No caching**: each `load_from_slot()` call performs a fresh `ResourceLoader.load()`. Godot's `ResourceLoader` does cache by path internally — that's fine for this pattern because the cached resource is the *parsed* resource, and `duplicate_deep()` (Story 004) isolates downstream mutations. The test in AC-8 verifies that the load path itself does not retain inappropriate caching beyond Godot's default behavior.

**`Events.game_loaded` signal** is declared by the Signal Bus epic (story 002 / 004). This story emits it; if not yet declared at implementation time, the story is BLOCKED.

**Performance test** (AC-7): `Time.get_ticks_usec()` from function entry to `Events.game_loaded` emit (or `Events.save_failed` emit on failure paths). Excludes `duplicate_deep` cost (which is the caller's). Budget: ≤2 ms on a representative ~5 KB save.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: data layer (already done)
- Story 002: write path + autoload registration (already done)
- Story 004: `duplicate_deep()` discipline at the call site (separate concern from the load itself)
- Story 005: metadata sidecar — `slot_metadata()` reads a *different* file (`slot_N_meta.cfg`); this story only handles the full Resource load
- Story 006: 8-slot scheme + `slot_exists()` — slot-validity helpers
- Story 008: state machine — `LOADING` state blocks save calls during a load (orchestration, not the read itself)

---

## QA Test Cases

**AC-1 — Happy path read returns loaded SaveGame**
- **Given**: a `slot_3.res` written by Story 002's save path with a known `section_id = &"plaza"` and `elapsed_seconds = 42.5`
- **When**: `SaveLoad.load_from_slot(3)` is called
- **Then**: returns a non-null `SaveGame` whose `section_id == &"plaza"` and `elapsed_seconds == 42.5`; `Events.game_loaded` emitted exactly once with slot=3; no `Events.save_failed` emit
- **Edge cases**: file exists but is a non-SaveGame Resource (e.g., a stray `Texture2D` written as `slot_3.res`) → fails AC-3 path

**AC-2 — Missing file returns SLOT_NOT_FOUND**
- **Given**: `user://saves/slot_5.res` does not exist
- **When**: `load_from_slot(5)` is called
- **Then**: returns `null`; `Events.save_failed` emitted exactly once with `FailureReason.SLOT_NOT_FOUND`; no `Events.game_loaded` emit; no file system mutations
- **Edge cases**: directory `user://saves/` doesn't exist → still treated as SLOT_NOT_FOUND (defense-in-depth: `FileAccess.file_exists` on a path in a missing dir returns false)

**AC-3 — Corrupt file returns CORRUPT_FILE**
- **Given**: `slot_3.res` exists but contains corrupted binary data (e.g., a deliberately malformed file written via `FileAccess.store_buffer` with garbage bytes) OR contains a valid Resource of a different class (e.g., a `Texture2D.res` renamed to `slot_3.res`)
- **When**: `load_from_slot(3)` is called
- **Then**: returns `null`; `Events.save_failed` emitted with `FailureReason.CORRUPT_FILE`; no `Events.game_loaded` emit; the corrupt file is NOT deleted (Menu System will mark it as `CORRUPT` slot state)
- **Edge cases**: `ResourceLoader.load` raises an error to console — that's expected (Godot's behavior); the test should accept the console error and verify the function's return + signal behavior

**AC-4 — Version mismatch returns VERSION_MISMATCH (no file deletion)**
- **Given**: a `slot_3.res` with `save_format_version = 1` (constructed by manually setting the field on a SaveGame instance and saving — simulating a save written by a prior build)
- **When**: `load_from_slot(3)` is called with current `FORMAT_VERSION = 2`
- **Then**: returns `null`; `Events.save_failed` emitted with `FailureReason.VERSION_MISMATCH`; no `Events.game_loaded` emit; the `slot_3.res` file still exists on disk after the call (NOT deleted — refuse-load-on-mismatch preserves the file for Menu's `CORRUPT` display)
- **Edge cases**: future-version save (`save_format_version = 99`, written by a hypothetical newer build) → also returns VERSION_MISMATCH; both directions of mismatch are refused

**AC-5 — game_loaded signal payload**
- **Given**: a valid `slot_2.res`
- **When**: `load_from_slot(2)` succeeds
- **Then**: `Events.game_loaded` emitted with slot argument `2`; returned SaveGame's `save_format_version == FORMAT_VERSION` (i.e., `2`)
- **Edge cases**: subscriber list empty → emit is no-op but signal-spy assertion still passes

**AC-6 — On-disk round-trip integrity**
- **Given**: a populated SaveGame `sg_original` written via `save_to_slot(3, sg_original)` (Story 002 happy path)
- **When**: `load_from_slot(3)` is called
- **Then**: returned SaveGame's every field equals `sg_original`'s field-by-field — `section_id`, `elapsed_seconds`, `player.position`, `player.health`, `inventory.ammo_magazine[&"silenced_p38"]`, `stealth_ai.guards[&"plaza_guard_01"].alert_state`, `mission.fired_beats[&"beat_intro"]`, `documents.collected`, etc.
- **Edge cases**: `StringName` keys must round-trip as StringName (not String); typed Dictionary values inside guards must round-trip per-field

**AC-7 — Load latency ≤2 ms**
- **Given**: a representative `slot_0.res` (~5 KB populated)
- **When**: `load_from_slot(0)` runs on local SSD
- **Then**: elapsed time `Time.get_ticks_usec()` from function entry to `Events.game_loaded` emit ≤2000 µs
- **Edge cases**: cold cache (first load after game start) — test runs load three times, asserts third run ≤2 ms; CI threshold 5 ms with warning

**AC-8 — No cross-call state leak**
- **Given**: `load_from_slot(3)` returns SaveGame instance A; caller mutates `A.section_id = &"mutated"`
- **When**: `load_from_slot(3)` is called a second time, returning SaveGame instance B
- **Then**: `B.section_id` reflects the on-disk value, NOT `&"mutated"`; (Note: depending on Godot's ResourceLoader cache behavior, A and B may be the same instance — if so, the test must clarify that the state-leak risk is exactly why callers must `duplicate_deep()` per Story 004; the assertion is "the loaded instance after the second call reflects on-disk state when read fresh")
- **Edge cases**: Godot's resource cache returns the same instance — that's expected; the test demonstrates exactly why the `duplicate_deep()` discipline (Story 004) exists

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/foundation/save_load_service_load_test.gd` — must exist and pass (covers all 8 ACs)
- Naming follows Foundation-layer convention
- Determinism: tests clean up `user://saves/` in setup AND teardown; corrupted-file fixtures are constructed in-test (no committed binary fixtures)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (SaveGame schema), Story 002 (`save_to_slot` writes the files this story reads; `Events.save_failed` + `FailureReason` enum)
- Unlocks: Story 004 (`duplicate_deep` discipline operates on the SaveGame this story returns), Story 005 (metadata sidecar API parallels this — same FailureReason taxonomy), Story 007 (F9 Quickload calls `load_from_slot(0)`), Story 008 (state machine wraps `load_from_slot`)
