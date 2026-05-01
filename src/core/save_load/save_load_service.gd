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
# Public API — save
# ---------------------------------------------------------------------------

## Atomically writes the given SaveGame to user://saves/slot_<slot>.res.
##
## Atomic write protocol (ADR-0003 IG 5):
##   1. Ensure SAVE_DIR exists.
##   2. ResourceSaver.save(save_game, slot_<slot>.tmp.res, FLAG_COMPRESS).
##   3. If non-OK: emit save_failed(IO_ERROR), return false (previous final
##      file untouched).
##   4. DirAccess.rename(tmp, final).
##   5. If non-OK: clean up tmp, emit save_failed(RENAME_FAILED), return
##      false (previous final file untouched).
##   6. Emit Events.game_saved(slot, save_game.section_id), return true.
##
## NOTE: this method does NOT write the metadata sidecar — Story SL-005 owns
## that. The service emits game_saved on the .res rename success; callers
## that need metadata can subscribe to game_saved and write the sidecar.
##
## Returns true on full success; false on any failure (with a save_failed
## emit identifying the reason).
func save_to_slot(slot: int, save_game: SaveGame) -> bool:
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

	# Step 6 — success. Emit game_saved with slot + section_id.
	Events.game_saved.emit(slot, save_game.section_id)
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
# Internal helpers — overridable for fault injection in tests
# ---------------------------------------------------------------------------

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
