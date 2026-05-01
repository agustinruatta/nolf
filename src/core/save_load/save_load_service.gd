# res://src/core/save_load/save_load_service.gd
#
# SaveLoadService — persistence autoload per ADR-0003 (Save Format Contract).
# Registered as autoload key `SaveLoad` at line 3 of project.godot per ADR-0007
# §Key Interfaces (after Events line 1, EventLogger line 2; before
# InputContext line 4).
#
# Responsibility: file I/O only — write/read SaveGame Resources to/from disk.
# This service does NOT query game systems. Callers (Mission Scripting,
# Failure & Respawn, player save action) build a SaveGame Resource by reading
# state from each owning system, then pass it in. Per ADR-0003 IG 2 +
# forbidden pattern `save_service_assembles_state`.
#
# Atomic write per ADR-0003 IG 5: tmp filename MUST end in `.res` (Sprint 01
# finding F1 — `.tmp` returns ERR_FILE_UNRECOGNIZED from ResourceSaver.save).
#
# Cross-Autoload Reference Safety per ADR-0007: _init() references no other
# autoloads; _ready() may reference Events / EventLogger only (lines 1, 2).
#
# Class name / autoload key split mirrors Events/SignalBusEvents and
# EventLogger/SignalBusEventLogger precedents — class_name `SaveLoadService`
# is distinct from autoload key `SaveLoad`, avoiding any class-hides-singleton
# parser conflict.

class_name SaveLoadService
extends Node

## Reasons a save or load operation can fail. Emitted as the argument of
## Events.save_failed when applicable. Order is locked — adding new variants
## must append at the end (consumer code may switch on int values).
enum FailureReason {
	NONE,
	IO_ERROR,           ## ResourceSaver.save() returned non-OK
	VERSION_MISMATCH,   ## save_format_version != FORMAT_VERSION (Story 003)
	CORRUPT_FILE,       ## ResourceLoader.load() returned null or wrong type (Story 003)
	SLOT_NOT_FOUND,     ## slot_N.res does not exist (Story 003)
	RENAME_FAILED,      ## DirAccess.rename() returned non-OK
}

## Directory under user:// where save slots and metadata sidecars live.
## Created on demand by save_to_slot if missing.
const SAVE_DIR: String = "user://saves/"

## Total number of save slots (slot 0 through slot 7 inclusive).
## Slot 0 is reserved for autosave. Slots 1–7 are player-controlled manual saves.
## ADR-0003 IG 7 + TR-SAV-004.
const SLOT_COUNT: int = 8

## The autosave slot index. Written at every section transition, explicit F5
## Quicksave action, and as a CR-4 mirror on every manual save (slots 1–7).
## Death respawn always loads slot 0 — see GDD CR-4 rationale.
const AUTOSAVE_SLOT: int = 0

## Inclusive range of player-controlled manual save slots.
## Vector2i(x, y) where x = first manual slot, y = last manual slot.
## A save to any slot in this range also writes slot 0 as a mirror (CR-4).
const MANUAL_SLOT_RANGE: Vector2i = Vector2i(1, 7)


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

# Per ADR-0007 IG 3: _init() MUST NOT reference any other autoload. We do not
# even read the autoload tree from here. Default Node._init() suffices.

func _ready() -> void:
	# Per ADR-0007 §Cross-Autoload Reference Safety rule 2, this _ready() MAY
	# reference Events (line 1) and EventLogger (line 2) only. We do not need
	# to reference either at boot for now — emit-time references happen in
	# save_to_slot below, after the autoload tree is fully constructed.
	pass


# ---------------------------------------------------------------------------
# Public API — slot existence probe
# ---------------------------------------------------------------------------

## Returns true if user://saves/slot_<slot>.res exists on disk; false otherwise.
##
## Cost: ≤1 ms — single FileAccess.file_exists call (no Resource load).
## Used by the Menu System (8-slot grid render) and F9 Quickload (Story 007)
## to check slot occupancy without loading the full SaveGame Resource.
##
## Out-of-range guard: returns false and logs a warning for any slot value
## outside [0, SLOT_COUNT). This is defense-in-depth for callers passing
## invalid slots — not a hard error, so callers can stay simple.
##
## Usage example:
##   if SaveLoad.slot_exists(0):
##       SaveLoad.load_from_slot(0)  # quickload the autosave
##   else:
##       show_no_quicksave_toast()
func slot_exists(slot: int) -> bool:
	if slot < 0 or slot >= SLOT_COUNT:
		push_warning(
			"Save/Load: slot_exists(%d) out of range [0..%d]" % [slot, SLOT_COUNT - 1]
		)
		return false
	var path: String = "%sslot_%d.res" % [SAVE_DIR, slot]
	return FileAccess.file_exists(path)


# ---------------------------------------------------------------------------
# Public API — save
# ---------------------------------------------------------------------------

## Atomically writes the given SaveGame to user://saves/slot_<slot>.res and
## writes a paired metadata sidecar to user://saves/slot_<slot>_meta.cfg.
##
## CR-4 mirror (ADR-0003 IG 7 + GDD CR-4): if slot is in the manual save
## range [1, 7], this method also writes slot 0 as an autosave mirror so
## that death respawn (which always loads slot 0) lands at the player's most
## recent manual save rather than at section start. The mirror is a
## convenience, not a correctness invariant — if the mirror write fails, the
## manual save is still committed (game_saved fires for the manual slot), and
## save_failed(IO_ERROR) fires for the mirror failure. Per IG 9, the previous
## slot 0 content is preserved by the atomic-write protocol in that case.
##
## Emit order on a manual save (slot 1–7): game_saved(slot, ...) fires FIRST
## (manual save committed), then game_saved(0, ...) fires for the mirror.
## Subscribers that only care about manual saves filter to slot != 0.
##
## Returns true on success (including partial-success where sidecar failed);
## false only when the primary slot write itself failed. Mirror failure is
## non-fatal (returns true, push_warning logged).
##
## Usage example:
##   var sg := build_save_game()  # caller assembles state from owning systems
##   var ok := SaveLoad.save_to_slot(3, sg)
##   if not ok:
##       show_save_error_dialog()
func save_to_slot(slot: int, save_game: SaveGame) -> bool:
	# Write the requested slot atomically (7-step protocol in helper).
	var ok: bool = _save_to_slot_atomic(slot, save_game)
	if not ok:
		return false

	# CR-4: manual save (slots 1–7) also writes slot 0 as the autosave mirror.
	# Rationale: death respawn always loads slot 0; if the player just saved
	# manually, they expect respawn to land at the manual save, not section start.
	# This is the ONLY place in the codebase where a direct slot-0 write is
	# initiated by the service for the mirror path (AC-7 single-source-of-truth).
	if slot >= MANUAL_SLOT_RANGE.x and slot <= MANUAL_SLOT_RANGE.y:
		var mirror_ok: bool = _save_to_slot_atomic(AUTOSAVE_SLOT, save_game)
		if not mirror_ok:
			# Manual save committed; mirror failed. game_saved(slot, ...) already
			# fired inside _save_to_slot_atomic above. save_failed(IO_ERROR) or
			# save_failed(RENAME_FAILED) was emitted inside the failed mirror
			# _save_to_slot_atomic call. Return true — manual save semantically
			# succeeded (ADR-0003 IG 9: never destroy a good save).
			push_warning(
				"Save/Load: slot %d saved but slot 0 mirror failed" % slot
			)

	return true


# ---------------------------------------------------------------------------
# Public API — load
# ---------------------------------------------------------------------------

## Reads user://saves/slot_<slot>.res and returns the loaded SaveGame.
##
## Type-guard + version-mismatch protocol (ADR-0003 IG 1 + IG 4):
##   1. If file does not exist → emit save_failed(SLOT_NOT_FOUND), return null.
##   2. ResourceLoader.load(path).
##   3. If null OR not a SaveGame → emit save_failed(CORRUPT_FILE), return null.
##      Binary `.res` returns null silently on class_name lookup failure — this
##      is the most likely silent-corruption bug per ADR-0003 §Risks (HIGH/MED).
##   4. If save_format_version != FORMAT_VERSION → emit save_failed(VERSION_MISMATCH),
##      return null. The slot file is NOT deleted (refuse-load-on-mismatch
##      preserves it for Menu System's CORRUPT-slot display per IG 9).
##   5. Emit Events.game_loaded(slot), return the loaded SaveGame.
##
## CALLER RESPONSIBILITY (ADR-0003 IG 3): the returned SaveGame is the live
## loaded instance. Callers MUST call `duplicate_deep()` before handing nested
## state to live systems — Story SL-004 is the canonical caller-side pattern.
## This method does NOT call duplicate_deep itself; doing so would break the
## return-on-failure contract (you cannot duplicate_deep a null) and double
## the load cost for callers that legitimately want the bare loaded instance
## (e.g., Menu System's read-only slot preview).
##
## Returns the loaded SaveGame on success; null on any failure (with a
## save_failed emit identifying the reason).
func load_from_slot(slot: int) -> SaveGame:
	var path: String = SAVE_DIR + "slot_%d.res" % slot

	# Step 1 — slot file present?
	if not FileAccess.file_exists(path):
		Events.save_failed.emit(FailureReason.SLOT_NOT_FOUND)
		return null

	# Step 2 — load. CACHE_MODE_IGNORE forces a fresh disk read so callers
	# always get the on-disk truth (mitigates the cross-call state-leak risk
	# in AC-8 — Story SL-004 still mandates duplicate_deep at the call site).
	var loaded: Resource = _load_resource(path)

	# Step 3 — type-guard. Catches both null (load failure / class mismatch)
	# and class-substitution (a non-SaveGame Resource at the slot path).
	if loaded == null or not (loaded is SaveGame):
		Events.save_failed.emit(FailureReason.CORRUPT_FILE)
		return null

	var save_game: SaveGame = loaded as SaveGame

	# Step 4 — version compare. Both lower (older save) and higher (future
	# build) versions are refused. No migration path at MVP per TR-SAV-008.
	if save_game.save_format_version != SaveGame.FORMAT_VERSION:
		Events.save_failed.emit(FailureReason.VERSION_MISMATCH)
		return null

	# Step 5 — success. Emit game_loaded with slot.
	# Caller is responsible for calling .duplicate_deep() before handing
	# nested state to live systems. See ADR-0003 IG 3 + Story SL-004.
	# Forbidden pattern: forgotten_duplicate_deep_on_load (lint in Story 009).
	Events.game_loaded.emit(slot)
	return save_game


# ---------------------------------------------------------------------------
# Public API — metadata sidecar (ADR-0003 IG 8)
# ---------------------------------------------------------------------------

## Returns a Dictionary of metadata fields for the given slot without loading
## the full .res file. The Menu System MUST use this method to render save
## cards — it MUST NOT call load_from_slot for display purposes.
##
## Fast path: reads slot_<slot>_meta.cfg via ConfigFile.load.
## Fallback path: if the sidecar is absent, reads saved_at_iso8601 from the
##   .res itself and returns a minimal Dictionary with defaults for other keys.
## Empty path: if both files are absent, returns an empty Dictionary {}.
##   Callers test result.is_empty() to detect "slot has no save" (Menu: EMPTY
##   slot state).
##
## The returned Dictionary always contains these keys when non-empty:
##   section_id          : String   (e.g., "restaurant")
##   section_display_name: String   (e.g., "meta.section.restaurant")
##   saved_at_iso8601    : String   (e.g., "2026-04-30T14:30:00")
##   elapsed_seconds     : float
##   screenshot_path     : String   (empty at MVP; reserved for Menu System epic)
##   save_format_version : int
##
## Usage example:
##   var meta := SaveLoad.slot_metadata(slot_index)
##   if meta.is_empty():
##       show_empty_slot_card(slot_index)
##   else:
##       show_save_card(meta["section_display_name"], meta["saved_at_iso8601"])
func slot_metadata(slot: int) -> Dictionary:
	var meta_path: String = SAVE_DIR + "slot_%d_meta.cfg" % slot
	var res_path: String = SAVE_DIR + "slot_%d.res" % slot

	# Fast path — sidecar present. Avoids full .res load (ADR-0003 IG 8).
	if FileAccess.file_exists(meta_path):
		var cfg: ConfigFile = ConfigFile.new()
		if cfg.load(meta_path) == OK:
			return _meta_dict_from_cfg(cfg)

	# Sidecar missing — fallback to partial recovery from the .res itself.
	# This path accepts the full .res load cost (acceptable per GDD Edge Cases
	# note: "fallback path WILL load the .res").
	if FileAccess.file_exists(res_path):
		return _fallback_meta_from_res(res_path)

	# Both missing — slot is empty.
	return {}


# ---------------------------------------------------------------------------
# Internal helpers — overridable for fault injection in tests
# ---------------------------------------------------------------------------

## Executes the full 7-step atomic write protocol for a single slot.
##
## This is the internal building block used by save_to_slot (once for the
## primary slot, and once for the CR-4 mirror on manual saves). It is NOT
## a test seam — it is a private implementation detail. To fault-inject at
## the ResourceSaver or DirAccess level, override _save_resource or
## _rename_file respectively (the existing test seams below).
##
## Steps:
##   1. Ensure SAVE_DIR exists (idempotent).
##   2. ResourceSaver.save to tmp file.
##   3. If non-OK: emit save_failed(IO_ERROR), return false.
##   4. DirAccess.rename(tmp, final).
##   5. If non-OK: clean up tmp, emit save_failed(RENAME_FAILED), return false.
##   6. Write metadata sidecar (partial-success: sidecar fail logs, does not abort).
##   7. Emit Events.game_saved(slot, section_id), return true.
func _save_to_slot_atomic(slot: int, save_game: SaveGame) -> bool:
	# Step 1 — ensure SAVE_DIR exists. Idempotent; a no-op if it already does.
	var dir_err: Error = DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
		Events.save_failed.emit(FailureReason.IO_ERROR)
		return false

	var tmp_path: String = SAVE_DIR + "slot_%d.tmp.res" % slot
	var final_path: String = SAVE_DIR + "slot_%d.res" % slot

	# Step 2 — write to tmp file. tmp suffix MUST end in `.res` per F1.
	var save_err: Error = _save_resource(save_game, tmp_path, ResourceSaver.FLAG_COMPRESS)

	# Step 3 — bail out on save failure. Previous final file untouched.
	if save_err != OK:
		# Best-effort tmp cleanup (may not exist if save_err was an early
		# failure). Ignore cleanup failures — IG 9 forbids destructive recovery.
		_remove_if_exists(tmp_path)
		Events.save_failed.emit(FailureReason.IO_ERROR)
		return false

	# Step 4 — atomic rename. Linux verified in Sprint 01 G2; Windows TBD.
	var rename_err: Error = _rename_file(tmp_path, final_path)

	# Step 5 — bail out on rename failure. Previous final file still untouched.
	if rename_err != OK:
		_remove_if_exists(tmp_path)
		Events.save_failed.emit(FailureReason.RENAME_FAILED)
		return false

	# Step 6 — write metadata sidecar. The .res is already committed above, so
	# sidecar failure is a partial-success: log, do not abort. Callers may
	# observe the fallback path from slot_metadata() on subsequent reads.
	var meta_path: String = SAVE_DIR + "slot_%d_meta.cfg" % slot
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("meta", "section_id", String(save_game.section_id))
	cfg.set_value("meta", "section_display_name", _section_display_name_key(save_game.section_id))
	cfg.set_value("meta", "saved_at_iso8601", save_game.saved_at_iso8601)
	cfg.set_value("meta", "elapsed_seconds", save_game.elapsed_seconds)
	cfg.set_value("meta", "screenshot_path", "")
	cfg.set_value("meta", "save_format_version", save_game.save_format_version)
	var sidecar_err: Error = _write_sidecar(cfg, meta_path)
	if sidecar_err != OK:
		push_warning(
			"Save/Load: sidecar write failed for slot %d (err=%d) — partial-success path" % [
				slot, sidecar_err
			]
		)

	# Step 7 — success. Emit game_saved with slot + section_id.
	Events.game_saved.emit(slot, save_game.section_id)
	return true


## Test seam: subclasses may override to force a specific Error result for
## ResourceSaver fault-injection coverage (AC-4). Production code MUST NOT
## call this directly — use save_to_slot.
func _save_resource(resource: Resource, path: String, flags: int) -> Error:
	return ResourceSaver.save(resource, path, flags)


## Test seam: subclasses may override to force a specific Error result for
## DirAccess.rename fault-injection coverage (AC-5). Production code MUST
## NOT call this directly — use save_to_slot.
##
## Uses the static DirAccess.rename(absolute, absolute) form — empirically
## verified by Sprint 01 G2 on Linux. Eliminates the open-dir + relative-
## basename indirection of the older form (which adds an ERR_CANT_OPEN
## failure mode that cannot trigger here since SAVE_DIR was just created).
func _rename_file(from_path: String, to_path: String) -> Error:
	return DirAccess.rename_absolute(from_path, to_path)


## Test seam: subclasses may override to force a specific result from the
## load step. CACHE_MODE_IGNORE forces a fresh disk read so the state-leak
## test (AC-8) sees on-disk truth on every call. Production code MUST NOT
## call this directly — use load_from_slot.
func _load_resource(path: String) -> Resource:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)


## Best-effort cleanup. Returns whether the file existed AND was removed.
## Failures are silent — IG 9 forbids destructive recovery on save failure.
func _remove_if_exists(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	return DirAccess.remove_absolute(path) == OK


## Test seam: subclasses may override to force a specific Error result from
## the sidecar ConfigFile.save step (AC-6 partial-success fault injection).
## Production code MUST NOT call this directly — use save_to_slot.
func _write_sidecar(cfg: ConfigFile, path: String) -> Error:
	return cfg.save(path)


## Builds the 6-field metadata Dictionary from a successfully-loaded ConfigFile
## sidecar. All values are read from the [meta] section; missing keys fall back
## to typed defaults so the returned Dictionary always has the full 6 fields.
func _meta_dict_from_cfg(cfg: ConfigFile) -> Dictionary:
	return {
		"section_id": cfg.get_value("meta", "section_id", ""),
		"section_display_name": cfg.get_value("meta", "section_display_name", ""),
		"saved_at_iso8601": cfg.get_value("meta", "saved_at_iso8601", ""),
		"elapsed_seconds": cfg.get_value("meta", "elapsed_seconds", 0.0),
		"screenshot_path": cfg.get_value("meta", "screenshot_path", ""),
		"save_format_version": cfg.get_value("meta", "save_format_version", SaveGame.FORMAT_VERSION),
	}


## Builds a minimal fallback Dictionary by loading the .res and extracting
## saved_at_iso8601. Used when the sidecar is missing (partial-success path
## from AC-3; also handles the corrupt-or-null .res case per AC-4).
##
## If the .res is corrupt, null, or lacks saved_at_iso8601, all values are
## empty/default — the function NEVER throws.
func _fallback_meta_from_res(res_path: String) -> Dictionary:
	var fallback: Dictionary = {
		"section_id": "",
		"section_display_name": "",
		"saved_at_iso8601": "",
		"elapsed_seconds": 0.0,
		"screenshot_path": "",
		"save_format_version": SaveGame.FORMAT_VERSION,
	}
	var loaded: Resource = _load_resource(res_path)
	if loaded == null or not (loaded is SaveGame):
		return fallback
	var sg: SaveGame = loaded as SaveGame
	fallback["saved_at_iso8601"] = sg.saved_at_iso8601
	return fallback


## Maps a section_id StringName to a localization key string.
## At MVP: simple key-prefix interpolation per ADR-0003 IG 8.
## Localization Scaffold epic owns refinement of the key scheme.
##
## Examples:
##   _section_display_name_key(&"restaurant") -> "meta.section.restaurant"
##   _section_display_name_key(&"")           -> "meta.section."
func _section_display_name_key(section_id: StringName) -> String:
	return "meta.section." + String(section_id)
