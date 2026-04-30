# Story 005: Metadata sidecar (slot_N_meta.cfg) + slot_metadata API

> **Epic**: Save / Load
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3 hours (M — sidecar write integration into save_to_slot + slot_metadata API + fallback path)
> **Manifest Version**: 2026-04-30

## Context

**GDD**: `design/gdd/save-load.md`
**Requirement**: TR-SAV-009 (metadata sidecar `slot_N_meta.cfg` ConfigFile read-only by Menu, avoids full `.res` load)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (Save Format Contract)
**ADR Decision Summary**: Every `slot_N.res` has a paired `slot_N_meta.cfg` (ConfigFile) with fields `section_id`, `section_display_name`, `saved_at_iso8601`, `elapsed_seconds`, `screenshot_path`, `save_format_version`. Menu System reads ONLY the sidecar to render save cards (avoids paying full Resource-load cost per slot in the 8-slot grid). The sidecar is written as step 4 of the atomic-write sequence (after rename succeeds, before `Events.game_saved` emits). On partial-success (rename OK but sidecar write fails), `slot_metadata()` returns a minimal fallback Dictionary built from the `.res`'s own `saved_at_iso8601` field.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `ConfigFile` is stable Godot 4.0+. `ConfigFile.save(path)` returns an `Error`; `ConfigFile.load(path)` likewise. ISO 8601 timestamps generated via `Time.get_datetime_string_from_system(true)` (UTC; `true` requests ISO 8601 format). No post-cutoff APIs.

**Control Manifest Rules (Foundation)**:
- Required: every `slot_N.res` has a paired `slot_N_meta.cfg` (ConfigFile) with the documented fields (ADR-0003 IG 8)
- Required: Menu System reads ONLY the sidecar to render save cards — `slot_metadata()` MUST NOT trigger a full `.res` load (ADR-0003 IG 8)
- Required: on partial-success path (rename OK but sidecar write fails), still emit `Events.game_saved` (with a logged warning), and `slot_metadata()` returns a minimal fallback Dictionary (per GDD Edge Cases)

---

## Acceptance Criteria

*From GDD §Acceptance Criteria + ADR-0003 §Implementation Guidelines:*

- [ ] **AC-1**: After a successful `save_to_slot(N, sg)`, `user://saves/slot_<N>_meta.cfg` exists and contains a `[meta]` section with keys `section_id`, `section_display_name`, `saved_at_iso8601`, `elapsed_seconds`, `screenshot_path`, `save_format_version` (per ADR-0003 IG 8 field list).
- [ ] **AC-2**: `slot_metadata(slot: int) -> Dictionary` reads ONLY `user://saves/slot_<N>_meta.cfg` via `ConfigFile.load`, returning a Dictionary with the 6 documented fields. Verified by file-I/O instrumentation: during the call, `slot_<N>.res` is NOT read (AC-11 from GDD).
- [ ] **AC-3**: GIVEN `slot_3.res` exists but `slot_3_meta.cfg` is missing, WHEN `slot_metadata(3)` is called, THEN a minimal fallback Dictionary is returned with `saved_at_iso8601` extracted from the `.res`'s own `saved_at_iso8601` field, plus default values for the other 5 fields (`section_id = ""`, `section_display_name = ""`, `elapsed_seconds = 0.0`, `screenshot_path = ""`, `save_format_version = SaveGame.FORMAT_VERSION`). (AC-12 from GDD; partial-save-recovery path.)
- [ ] **AC-4**: GIVEN `slot_3.res` exists, `slot_3_meta.cfg` is missing, AND the `.res` itself is corrupt or missing `saved_at_iso8601`, WHEN `slot_metadata(3)` is called, THEN a Dictionary with all empty/default values is returned (`saved_at_iso8601 = ""`); the function does NOT throw.
- [ ] **AC-5**: GIVEN both `slot_3.res` and `slot_3_meta.cfg` are missing, WHEN `slot_metadata(3)` is called, THEN an empty Dictionary `{}` is returned (callers test `is_empty()` to detect "slot has no save"; this matches the Menu System's `EMPTY` slot state).
- [ ] **AC-6**: Sidecar write in `save_to_slot()` is step 4 of the atomic sequence — after `DirAccess.rename(tmp, final)` succeeds, before `Events.game_saved` emits. If sidecar write fails (`ConfigFile.save() != OK`), the rename has already committed the `.res` — partial-success: log a warning, emit `Events.game_saved` anyway, and `slot_metadata()` will fall back to AC-3's path on subsequent reads.
- [ ] **AC-7**: `saved_at_iso8601` is in canonical UTC ISO 8601 format (e.g., `"2026-04-30T14:30:00"` — `Time.get_datetime_string_from_system(true)`). `section_display_name` is the localization key for the section name (per CR-§Cross-References — Localization Scaffold owns string keys). `elapsed_seconds` is a float (game-time elapsed; assembled by Mission Scripting at save time and passed through the SaveGame).
- [ ] **AC-8**: GIVEN a save is overwritten (new `save_to_slot(3, sg2)` call on an existing slot 3), WHEN the call completes, THEN `slot_3_meta.cfg` reflects `sg2`'s metadata (NOT `sg1`'s); the sidecar is overwritten in lockstep with the `.res`.

---

## Implementation Notes

*Derived from ADR-0003 §Implementation Guidelines §IG 8 + GDD §Edge Cases:*

**Sidecar write path** (extension to Story 002's `save_to_slot()`):

```gdscript
# After DirAccess.rename(tmp, final) succeeds:
var meta_path: String = "%sslot_%d_meta.cfg" % [SAVE_DIR, slot]
var cfg: ConfigFile = ConfigFile.new()
cfg.set_value("meta", "section_id", String(save_game.section_id))
cfg.set_value("meta", "section_display_name", _section_display_name_key(save_game.section_id))
cfg.set_value("meta", "saved_at_iso8601", save_game.saved_at_iso8601)
cfg.set_value("meta", "elapsed_seconds", save_game.elapsed_seconds)
cfg.set_value("meta", "screenshot_path", "")  # populated by Story 005's optional screenshot extension or left empty at MVP
cfg.set_value("meta", "save_format_version", save_game.save_format_version)

var err: int = cfg.save(meta_path)
if err != OK:
    push_warning("Save/Load: sidecar write failed for slot %d (err=%d) — proceeding with partial-success path" % [slot, err])
# Continue to emit game_saved regardless — the .res is already committed
Events.game_saved.emit(slot, save_game.section_id)
```

**`slot_metadata()` API** (new):

```gdscript
func slot_metadata(slot: int) -> Dictionary:
    var meta_path: String = "%sslot_%d_meta.cfg" % [SAVE_DIR, slot]
    var res_path: String = "%sslot_%d.res" % [SAVE_DIR, slot]

    # Sidecar present — fast path (avoids full .res load)
    if FileAccess.file_exists(meta_path):
        var cfg: ConfigFile = ConfigFile.new()
        if cfg.load(meta_path) == OK:
            return _meta_dict_from_cfg(cfg)

    # Sidecar missing — fallback to partial recovery from the .res itself
    if FileAccess.file_exists(res_path):
        return _fallback_meta_from_res(res_path)

    # Both missing — slot is empty
    return {}
```

**`_section_display_name_key()`**: maps a `section_id: StringName` to a localization key (e.g., `&"restaurant"` → `"meta.section.restaurant"`). At MVP this can be a simple string interpolation; localization-scaffold epic will refine the key prefix.

**Screenshot field at MVP**: leave `screenshot_path = ""`. The optional thumbnail capture (`get_viewport().get_texture().get_image()` downsampled to 320×180, saved as `slot_N_thumb.png`) is referenced in the GDD §Tuning Knobs but is **deferred to Menu System epic** (it's a Menu-render concern, not a save-correctness concern). Sidecar still has the field for future-proofing.

**Why the sidecar is mandatory**: per GDD §UI Requirements, Menu System renders 8 save cards on the Load Game screen. Each card needs section name + timestamp + thumbnail + elapsed time. Without the sidecar, rendering the grid requires loading 8 full `SaveGame` Resources (~5 KB × 8 = 40 KB + parsing cost × 8) just to display metadata — wasteful when each card needs only ~200 bytes of data.

**Atomicity scope**: the sidecar is NOT part of the atomic-write contract. The `.res` is the source of truth (refuse-load-on-mismatch versioning is checked against `save_format_version` IN the `.res`, not the sidecar). The sidecar is a render-cache. If the sidecar is missing/stale, AC-3's fallback path handles it gracefully.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: atomic write of `.res` itself (already done; this story extends step 4)
- Story 003: `load_from_slot()` (full `.res` load — separate API; sidecar is the render-cache, not the load path)
- Story 006: 8-slot scheme + slot 0 mirror (slot scheme uses `slot_metadata` indirectly via Menu System — that integration is Story 006's concern)
- Optional thumbnail screenshot (`slot_N_thumb.png`) — deferred to Menu System epic
- Localization key generation for `section_display_name` — owned by Localization Scaffold epic; this story uses a simple key prefix at MVP (`meta.section.<section_id>`)

---

## QA Test Cases

**AC-1 — Sidecar exists with all 6 fields after successful save**
- **Given**: a populated `SaveGame` with `section_id = &"restaurant"`, `saved_at_iso8601 = "2026-04-30T14:30:00"`, `elapsed_seconds = 123.45`, `save_format_version = 2`
- **When**: `SaveLoad.save_to_slot(0, sg)` succeeds
- **Then**: `user://saves/slot_0_meta.cfg` exists; loading it via `ConfigFile.load` returns OK; `cfg.get_value("meta", "section_id") == "restaurant"`, `cfg.get_value("meta", "saved_at_iso8601") == "2026-04-30T14:30:00"`, `cfg.get_value("meta", "elapsed_seconds") == 123.45`, `cfg.get_value("meta", "save_format_version") == 2`, `cfg.get_value("meta", "section_display_name") == "meta.section.restaurant"`, `cfg.get_value("meta", "screenshot_path") == ""`
- **Edge cases**: empty section_id → sidecar still has the key with empty value; numeric fields preserved as numeric (not stringified)

**AC-2 — slot_metadata reads sidecar only, not .res**
- **Given**: `slot_0.res` and `slot_0_meta.cfg` both exist (from a prior successful save)
- **When**: `SaveLoad.slot_metadata(0)` is called with file-I/O instrumentation (e.g., a wrapper around `FileAccess.open` that logs which paths are opened during the call)
- **Then**: returned Dictionary contains all 6 expected fields; instrumentation log shows `slot_0_meta.cfg` was opened; `slot_0.res` was NOT opened during the call
- **Edge cases**: Godot's internal caching may keep a reference to a previously-loaded `.res` — instrumentation must detect *new* opens during this specific call, not pre-existing references

**AC-3 — Fallback Dictionary when sidecar missing but .res present**
- **Given**: `slot_3.res` exists with `saved_at_iso8601 = "2026-04-29T10:00:00"`; `slot_3_meta.cfg` is manually deleted
- **When**: `SaveLoad.slot_metadata(3)` is called
- **Then**: returns a Dictionary `{section_id: "", section_display_name: "", saved_at_iso8601: "2026-04-29T10:00:00", elapsed_seconds: 0.0, screenshot_path: "", save_format_version: <FORMAT_VERSION>}`
- **Edge cases**: `.res` parse cost — fallback path WILL load the `.res` (acceptable; defense-in-depth); function still returns within the load latency budget (~2 ms per ADR-0003 §Performance)

**AC-4 — Both sidecar and .res missing fields → empty/default Dictionary**
- **Given**: `slot_3.res` exists but is corrupt OR has no `saved_at_iso8601` field; `slot_3_meta.cfg` is missing
- **When**: `slot_metadata(3)` is called
- **Then**: returns Dictionary with all-empty/default values; `saved_at_iso8601 == ""`; function does NOT throw or fail
- **Edge cases**: corrupt `.res` triggers `ResourceLoader.load` to return null — fallback path catches the null and returns the all-defaults Dictionary

**AC-5 — Both files missing → empty Dictionary**
- **Given**: neither `slot_5.res` nor `slot_5_meta.cfg` exist
- **When**: `slot_metadata(5)` is called
- **Then**: returns `{}` (empty Dictionary); `result.is_empty() == true`; no exceptions
- **Edge cases**: `user://saves/` directory itself missing → still returns `{}` (defense-in-depth)

**AC-6 — Atomic-write sequence: sidecar is step 4**
- **Given**: a populated SaveGame; `save_to_slot(0, sg)` is instrumented to log each step
- **When**: the function runs to completion successfully
- **Then**: log order is: (1) tmp write, (2) tmp write OK, (3) rename to final, (4) sidecar write, (5) `Events.game_saved` emit; sidecar write happens BETWEEN rename and emit
- **Edge cases**: sidecar write fails → log shows "sidecar failed" warning, emit STILL fires (partial-success path); subsequent `slot_metadata(0)` exercises AC-3's fallback

**AC-7 — Field formats**
- **Given**: a save with `saved_at_iso8601` generated via `Time.get_datetime_string_from_system(true)` at known wall-clock time
- **When**: the sidecar is read
- **Then**: `saved_at_iso8601` matches the canonical ISO 8601 pattern `YYYY-MM-DDTHH:MM:SS`; `section_display_name` follows the pattern `"meta.section.<section_id>"` (string-prefix verification)
- **Edge cases**: section_id is StringName `&""` → `section_display_name` is `"meta.section."` (empty suffix; not a crash); future Localization Scaffold epic refines the key generation

**AC-8 — Sidecar overwritten on subsequent save**
- **Given**: `slot_3.res` and `slot_3_meta.cfg` exist with `section_id = "plaza"` from a prior save
- **When**: `save_to_slot(3, sg_new)` is called with `sg_new.section_id = &"restaurant"`
- **Then**: `slot_3_meta.cfg`'s `section_id` field equals `"restaurant"` after the call (NOT `"plaza"`); other fields also reflect `sg_new`
- **Edge cases**: simultaneous reads during write — out of scope here (Story 008's state machine handles concurrency)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/foundation/save_load_metadata_sidecar_test.gd` — must exist and pass (covers all 8 ACs)
- Naming follows Foundation-layer convention
- Determinism: tests clean up `user://saves/` in setup AND teardown; constructed metadata fixtures use known timestamps and section IDs

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (`save_to_slot` is the integration point for sidecar write), Story 003 (fallback path's `.res` read uses the same `ResourceLoader.load` pattern), Story 001 (SaveGame has `saved_at_iso8601` and `save_format_version` fields)
- Unlocks: Menu System epic (Load Game screen renders save cards from `slot_metadata()`); Story 006 (slot scheme can use `slot_metadata().is_empty()` as a slot-state probe)
