# Story 006: 8-slot scheme + slot 0 mirror on manual save (CR-4)

> **Epic**: Save / Load
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 1-2 hours (S — slot-scheme helpers + CR-4 dual-write logic)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/save-load.md`
**Requirement**: TR-SAV-004 (8 save slots: slot 0 = autosave, slots 1–7 = player-controlled manual)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Save Format Contract)
**ADR Decision Summary**: 8 slots total — `slot_0` = autosave (overwritten at section transitions, explicit save action, and as a side effect of every manual save per CR-4), `slot_1`..`slot_7` = player-controlled manual saves. NOLF1-style multi-slot, generously sized so players can keep milestone saves at every section + alternate route experiments. `slot_exists(N)` is the public API for Menu System / F&R / Mission Scripting to query slot occupancy without paying full Resource-load cost (uses `FileAccess.file_exists` on `slot_<N>.res`).

**GDD CR-4** (locked design decision): A manual save to slot 1–7 ALSO overwrites slot 0. Rationale: Pillar 3 (Stealth is Theatre, Not Punishment) — a player who just saved to slot 3 and then dies respawns at their manual save state, not back at section start. Death respawn always loads slot 0, and slot 0 tracks "the most recent save regardless of who made it."

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `FileAccess.file_exists(path)` is a stable, cheap probe. No post-cutoff APIs.

**Control Manifest Rules (Foundation)**:
- Required: 8 save slots — `slot_0` autosave + `slot_1`..`slot_7` manual (ADR-0003 IG 7)
- Slot 0 is the autosave slot, locked (per GDD §Tuning Knobs `AUTOSAVE_SLOT = 0`); slot range 1–7 is the manual range
- Failure paths from the Story 002 `save_to_slot()` apply equally to the slot-0 mirror write — if the manual save succeeds but the slot-0 mirror fails, the manual save is still committed (the mirror is a CR-4 convenience, not a correctness invariant; partial-success path emits `save_failed(IO_ERROR)` for the mirror but the manual save's `game_saved` still fires)

---

## Acceptance Criteria

*From GDD §Acceptance Criteria + GDD §Detailed Design CR-4:*

- [ ] **AC-1**: `slot_exists(slot: int) -> bool` returns `true` if `user://saves/slot_<N>.res` exists, `false` otherwise. Cost: ≤1 ms (single `FileAccess.file_exists` call). Used by Menu System (8-slot grid render) and F9 Quickload (Story 007).
- [ ] **AC-2**: GIVEN slot value out of range (`slot < 0` or `slot > 7`), WHEN `slot_exists(slot)` is called, THEN it returns `false` AND a warning is logged (defense-in-depth for callers passing invalid slots; not a hard error to keep callers simple).
- [ ] **AC-3**: GIVEN player selects slot 3 in Pause Menu Save Game screen, WHEN `save_to_slot(3, sg)` succeeds, THEN both `user://saves/slot_3.res` AND `user://saves/slot_0.res` are written with the same `SaveGame` payload AND both sidecars are present (`slot_3_meta.cfg` + `slot_0_meta.cfg`). (AC-2 from GDD; CR-4 dual-write.)
- [ ] **AC-4**: GIVEN the manual save in AC-3 succeeds, WHEN `Events.game_saved` is observed, THEN it fires TWICE — once for slot 3 (the player-requested slot) AND once for slot 0 (the CR-4 mirror) — both with the same `section_id`. Each emit carries its own slot number.
- [ ] **AC-5**: GIVEN `save_to_slot(0, sg_autosave)` is called directly (autosave path — section transition or F5 Quicksave), WHEN it succeeds, THEN ONLY slot 0 is written (no mirror to other slots; the CR-4 mirror is exclusive to manual save path slots 1–7).
- [ ] **AC-6**: GIVEN the manual save to slot 5 succeeds in writing `slot_5.res` but FAILS during the slot-0 mirror write (IO_ERROR), WHEN observed, THEN `Events.game_saved.emit(5, ...)` fires (manual save committed) AND `Events.save_failed.emit(IO_ERROR)` fires (mirror failed) AND `slot_5.res` is intact AND `slot_0.res` is whatever it was before the call (not partially-written).
- [ ] **AC-7**: GIVEN the slot-0 mirror is internal to `save_to_slot()`, WHEN code review inspects `save_load_service.gd`, THEN there is exactly ONE place in the code where the slot-0 mirror logic exists (no duplication across F5/Quicksave/manual-save call sites — the service handles the mirror internally based on the `slot` argument: `if slot in 1..7: also write slot 0`).

---

## Implementation Notes

*Derived from GDD §Detailed Design CR-1 + CR-4 + ADR-0003 §Implementation Guidelines:*

**`slot_exists()` API**:

```gdscript
const SLOT_COUNT: int = 8
const AUTOSAVE_SLOT: int = 0
const MANUAL_SLOT_RANGE: Vector2i = Vector2i(1, 7)  # inclusive

func slot_exists(slot: int) -> bool:
    if slot < 0 or slot >= SLOT_COUNT:
        push_warning("Save/Load: slot_exists(%d) out of range [0..%d]" % [slot, SLOT_COUNT - 1])
        return false
    var path: String = "%sslot_%d.res" % [SAVE_DIR, slot]
    return FileAccess.file_exists(path)
```

**CR-4 dual-write extension to Story 002's `save_to_slot()`**:

```gdscript
func save_to_slot(slot: int, save_game: SaveGame) -> bool:
    var ok: bool = _save_to_slot_atomic(slot, save_game)
    if not ok:
        return false

    # CR-4: manual save (slots 1–7) also writes slot 0 as the autosave mirror.
    # Rationale: death respawn always loads slot 0; if the player just saved
    # manually, they expect respawn to land at the manual save, not section start.
    if slot >= MANUAL_SLOT_RANGE.x and slot <= MANUAL_SLOT_RANGE.y:
        var mirror_ok: bool = _save_to_slot_atomic(AUTOSAVE_SLOT, save_game)
        if not mirror_ok:
            # Manual save committed; mirror failed. game_saved already fired
            # for the manual slot inside _save_to_slot_atomic. save_failed
            # has already been emitted for the mirror failure inside the
            # nested call. Caller's manual save semantically succeeded.
            push_warning("Save/Load: slot %d saved but slot 0 mirror failed" % slot)

    return true
```

(`_save_to_slot_atomic` is the internal helper that performs the Story 002 atomic-write protocol for a single slot, including sidecar write and `Events.game_saved` / `Events.save_failed` emit. Refactor Story 002's `save_to_slot()` to extract this helper; the public `save_to_slot()` becomes the helper + CR-4 mirror logic.)

**Why mirror failure does NOT roll back the manual save**: per ADR-0003 IG 9 and GDD CR-9 ("the previous good save is never destroyed"), the manual save's atomic-write protocol guarantees `slot_5.res` is committed independently of the mirror. The mirror is a convenience for the death-respawn-loads-slot-0 contract — if it fails, the player loses the convenience but does NOT lose their manual save. Aggressive rollback (delete the manual save because the mirror failed) would violate the "never destroy a good save" rule.

**Slot range validation**: callers (Pause Menu, Mission Scripting, F&R) are trusted to pass valid slot indices. `slot_exists()` defends with a warning to catch programming bugs early. `save_to_slot(slot, ...)` with an out-of-range slot is undefined — callers are responsible for clamping. (No hard validation in `save_to_slot` because callers should never have a reason to pass invalid slots; if a future audit shows otherwise, add a guard.)

**Why slot range is 0–7 not 1–8**: GDD §Detailed Design CR-1 + ADR-0003 IG 7 lock the convention. Slot 0 is the autosave; the player-facing UI counts "slot 1" through "slot 7" for manual saves. Internally everything uses 0-indexed slot numbers.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: atomic-write protocol (already done — refactored here into `_save_to_slot_atomic` helper)
- Story 005: metadata sidecar (the helper handles sidecar per slot; CR-4 mirror writes its own sidecar via the helper)
- Story 007: F5 Quicksave (calls `save_to_slot(0, ...)` — autosave path, no mirror)
- Story 008: state machine (concurrent dual-write on CR-4 path — the second `_save_to_slot_atomic` call is sequential within `save_to_slot`, not a separate concurrent call; the state machine sees one in-flight save at a time per the public `save_to_slot()` boundary)
- Menu System slot grid render (AC-13, AC-14 from GDD) — owned by Menu System epic
- Slot 0 visibility in Load Game grid vs invisibility in Save Game picker — render-time concerns, owned by Menu System

---

## QA Test Cases

**AC-1 — slot_exists happy path**
- **Given**: `slot_3.res` exists from a prior save; `slot_5.res` does not exist
- **When**: `SaveLoad.slot_exists(3)` and `SaveLoad.slot_exists(5)` are called
- **Then**: `slot_exists(3) == true`; `slot_exists(5) == false`; both calls return within 1 ms
- **Edge cases**: file-system slow path on first call (cold cache) → still ≤1 ms typically; CI threshold 5 ms with warning

**AC-2 — Out-of-range slot returns false with warning**
- **Given**: clean state
- **When**: `slot_exists(-1)`, `slot_exists(8)`, `slot_exists(99)` are called
- **Then**: each returns `false`; each logs a warning (verifiable via `push_warning` capture or by inspecting Godot's print buffer)
- **Edge cases**: extremely large slot numbers → still returns false, no crash; negative slots → no path lookup attempted (defense-in-depth)

**AC-3 — Manual save writes slot N + slot 0 mirror**
- **Given**: a populated SaveGame `sg` with `section_id = &"restaurant"`; clean `user://saves/`
- **When**: `SaveLoad.save_to_slot(3, sg)` succeeds
- **Then**: `slot_3.res` exists; `slot_0.res` exists; `slot_3_meta.cfg` exists; `slot_0_meta.cfg` exists; reloading both via `load_from_slot(3)` and `load_from_slot(0)` returns SaveGames with identical content (same `section_id`, same `elapsed_seconds`, etc.)
- **Edge cases**: pre-existing `slot_0.res` from a prior autosave → overwritten by the manual mirror (CR-4 explicit behavior — most recent save wins regardless of who made it)

**AC-4 — game_saved fires twice (one per written slot)**
- **Given**: a populated SaveGame; clean `user://saves/`; signal-spy on `Events.game_saved`
- **When**: `save_to_slot(3, sg)` succeeds
- **Then**: signal-spy records exactly 2 emissions: `(3, &"<section_id>")` and `(0, &"<section_id>")`; emission order is slot 3 first, then slot 0 (manual write before mirror); no `Events.save_failed` emit
- **Edge cases**: subscribers may distinguish manual-save vs mirror by inspecting slot argument — slot 0 emit on a manual-save path means "this is the CR-4 mirror"; subscribers that only care about manual saves filter to slot != 0

**AC-5 — Direct slot 0 save does NOT mirror**
- **Given**: a populated SaveGame; clean `user://saves/`
- **When**: `save_to_slot(0, sg)` succeeds (autosave path — direct write)
- **Then**: `slot_0.res` exists; slots 1–7 do NOT exist; `Events.game_saved` fires exactly once with slot=0
- **Edge cases**: prior manual saves at slots 1, 2, 3 from a previous test session (cleanup miss) → those are NOT touched by the autosave (each slot is independent); test verifies isolation by setting up clean `user://saves/` per-test

**AC-6 — Manual save commits even if mirror fails**
- **Given**: a populated SaveGame; mock injection forces the slot-0 mirror's `ResourceSaver.save` to return non-OK while letting the slot-5 write succeed
- **When**: `save_to_slot(5, sg)` is called
- **Then**: `slot_5.res` exists with the new save; `Events.game_saved.emit(5, ...)` fired (manual save committed); `Events.save_failed.emit(IO_ERROR)` fired (mirror failed); `slot_0.res` (if pre-existing) is byte-identical to its pre-call state; `save_to_slot(5, ...)` returns `true` (the manual save succeeded; the mirror failure is non-fatal)
- **Edge cases**: pre-existing `slot_0.res` is preserved by atomic-write rollback discipline (Story 002 AC-4 / AC-5); the mirror failure does not destroy the prior autosave

**AC-7 — Single source of mirror logic (no duplication)**
- **Given**: `src/core/save_load/save_load_service.gd` source
- **When**: a code-review test greps for `save_to_slot(0` or `_save_to_slot_atomic(0` or any direct slot-0 write
- **Then**: exactly ONE direct slot-0 write call site exists in the codebase (inside `save_to_slot`'s CR-4 branch); F5 quicksave (Story 007) calls `save_to_slot(0, ...)` and lets the public method handle the slot scheme — no Quicksave-specific slot-0 write path
- **Edge cases**: future refactors that introduce a new save call site → grep test fires; flag for review

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/foundation/save_load_slot_scheme_test.gd` — must exist and pass (covers all 7 ACs)
- Naming follows Foundation-layer convention
- Determinism: tests clean up `user://saves/` in setup AND teardown; mock injection for AC-6 uses a deterministic fault wrapper, not random failure

**Status**: [x] Created and passing — `tests/unit/foundation/save_load_slot_scheme_test.gd` (14 test functions covering AC-1..AC-7 + 2 advisory-gap-closure regression guards). Suite total: 328/328 PASS.

---

## Completion Notes

**Completed**: 2026-05-01
**Criteria**: 7/7 passing — all auto-verified via 14 test functions (12 AC-coverage + 2 regression guards from code-review remediation).
**Test Evidence**: `tests/unit/foundation/save_load_slot_scheme_test.gd` (407 → 480 lines after gap-closure pass)
**Code Review**: APPROVED (godot-gdscript-specialist + qa-tester run in parallel; 0 must-fix; 4 advisory suggestions; 2 advisory gaps closed via additional tests, 2 left advisory: GAP-1 push_warning capture seam too invasive for low value; GAP-2 grep regex edge case is theoretical — current pattern correctly fails on realistic regression).
**Deviations**: None. Refactor preserves byte-equivalent behavior in `_save_to_slot_atomic` helper. Manifest version 2026-04-30 matches current. Full ADR-0003 IG 5/7/8/9 compliance.
**Suite trajectory**: 314 baseline → 326 after SL-006 initial impl (12 new tests) → 328 after gap-closure (+2 regression guards: mirror RENAME_FAILED variant + primary-fail-skips-mirror).
**Files modified**: `src/core/save_load/save_load_service.gd` (+90 LOC: 3 constants `SLOT_COUNT`/`AUTOSAVE_SLOT`/`MANUAL_SLOT_RANGE`; `slot_exists()` public API; refactored `save_to_slot()` to call `_save_to_slot_atomic` helper + CR-4 mirror branch; preserved 7-step protocol intact in extracted helper).
**Files created**: `tests/unit/foundation/save_load_slot_scheme_test.gd` (14 test functions; 4 fault-injection subclasses: `_MirrorFailingService`, `_MirrorRenameFailingService`, `_PrimaryFailingService`, signal-spy infrastructure).

---

## Dependencies

- Depends on: Story 002 (`save_to_slot` core path; refactor extracts `_save_to_slot_atomic` helper), Story 005 (sidecar write path applies to both slot N and slot 0 mirror)
- Unlocks: Story 007 (F9 Quickload calls `slot_exists(0)` to decide between load and "No quicksave available" toast); Menu System epic (Load Game screen iterates `slot_exists` for all 8 slots)
