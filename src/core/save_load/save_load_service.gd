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
#
# State machine (Story SL-008, ADR-0003 §States and Transitions):
#   IDLE    — no I/O in progress; default state; any call proceeds immediately.
#   SAVING  — atomic write in flight; second save or quickload are queued.
#   LOADING — ResourceLoader read in flight; any save or second load are queued.
# Queue is FIFO, max depth MAX_QUEUE_DEPTH (4). A 5th queued op is rejected
# (returns false / null) with a logged warning. Drain occurs after every
# completed operation.
#
# AC-10 state-exit discipline: state transitions to IDLE BEFORE any
# save_failed / game_saved / game_loaded signal emission. A subscriber that
# synchronously calls save_to_slot from a failure handler will see IDLE.

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

## Internal state machine states (Story SL-008, GDD §Detailed Design States).
## Read via the public current_state property. Do NOT set externally.
enum State {
	IDLE,    ## No I/O in progress. Default. All calls proceed immediately.
	SAVING,  ## Atomic write in flight. Further saves + quickload are queued.
	LOADING, ## ResourceLoader read in flight. All saves + further loads are queued.
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

## Maximum number of pending operations in the FIFO queue (Story SL-008 AC-8).
## 4 gives 2× headroom over the realistic worst-case of 2 (autosave + F5).
## A 5th enqueue attempt is rejected with a warning — defense against runaway
## signal cascades. Future: revisit if 4 is too low.
const MAX_QUEUE_DEPTH: int = 4

# ---------------------------------------------------------------------------
# State machine fields (Story SL-008)
# ---------------------------------------------------------------------------

## Current service state. One of the State enum values: IDLE, SAVING, LOADING.
## Read-only from outside this class — no public setter.
## Use _set_state(new_state) internally for all transitions.
##
## Usage example:
##   if SaveLoad.current_state == SaveLoadService.State.IDLE:
##       SaveLoad.save_to_slot(0, sg)
##   else:
##       # service is busy; save_to_slot will queue the call automatically
##       SaveLoad.save_to_slot(0, sg)
var current_state: int = State.IDLE

## FIFO queue of pending I/O operations (Callables). Each entry is a zero-arg
## Callable that performs a _do_save or _do_load operation.
## Max depth: MAX_QUEUE_DEPTH. See _enqueue() and _drain_queue().
var _queue: Array = []


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
	#
	# Story SL-007: Attach QuicksaveInputHandler as a child Node. The helper
	# queries the input-routing context only inside its _unhandled_input callback
	# (guaranteed post tree-init), not here. ADR-0007 §Cross-Autoload Reference
	# Safety rule 3: line 3 must not reference line 4 during boot. AC-9 of SL-007.
	var handler: QuicksaveInputHandler = QuicksaveInputHandler.new()
	add_child(handler)


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
## State machine (Story SL-008): if the service is IDLE, the write runs
## immediately and returns true on success / false on failure. If the service
## is SAVING or LOADING, the call is queued (FIFO) and returns true to signal
## "accepted". Returns false only when the queue is full (MAX_QUEUE_DEPTH
## exceeded) — an exceptional condition that indicates a runaway signal cascade.
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
## AC-10 re-entrance contract: state is IDLE before any signal emits. A
## save_failed subscriber that immediately calls save_to_slot again will see
## current_state == IDLE and proceed normally.
##
## Returns true on success OR on accepted queue enqueue.
## Returns false only when queue is full (defense-in-depth) or primary IO fails.
##
## Usage example:
##   var sg := build_save_game()  # caller assembles state from owning systems
##   var ok := SaveLoad.save_to_slot(3, sg)
##   if not ok:
##       show_save_error_dialog()
func save_to_slot(slot: int, save_game: SaveGame) -> bool:
	if current_state != State.IDLE:
		return _enqueue(func() -> void: _do_save(slot, save_game))
	return _do_save(slot, save_game)


# ---------------------------------------------------------------------------
# Public API — load
# ---------------------------------------------------------------------------

## Reads user://saves/slot_<slot>.res and returns the loaded SaveGame.
##
## State machine (Story SL-008): if the service is IDLE, the load runs
## immediately and returns the SaveGame (or null on failure). If the service
## is SAVING or LOADING, the call is queued and this method returns null with
## a push_warning. Callers must subscribe to Events.game_loaded to receive
## the result when the queued load eventually completes.
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
## save_failed emit identifying the reason). Also returns null when queued —
## callers must use Events.game_loaded for async completion.
func load_from_slot(slot: int) -> SaveGame:
	if current_state != State.IDLE:
		push_warning(
			"Save/Load: load_from_slot(%d) called while busy (state=%d) — queuing" % [
				slot, current_state
			]
		)
		_enqueue(func() -> void: _do_load(slot))
		return null
	return _do_load(slot)


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
# Internal — state machine operations (Story SL-008)
# ---------------------------------------------------------------------------

## Transitions internal state to new_state. All state changes MUST go through
## this helper — never assign current_state directly outside this method.
## Centralises the transition point for state-spy hooks in tests.
func _set_state(new_state: int) -> void:
	current_state = new_state


## Performs a guarded save: sets SAVING, runs the full save (primary + CR-4
## mirror), sets IDLE, drains queue, THEN emits signals. This ordering satisfies
## AC-10: state is IDLE before any save_failed or game_saved emit fires.
##
## Returns true if the primary slot write succeeded (mirror failure is
## non-fatal and returns true per ADR-0003 IG 9).
func _do_save(slot: int, sg: SaveGame) -> bool:
	_set_state(State.SAVING)

	# Run IO for primary slot — no signals emitted yet.
	var primary: Dictionary = _save_to_slot_io_only(slot, sg)

	# CR-4 mirror: manual save (slots 1–7) also writes slot 0.
	var mirror_result: Dictionary = {}
	if primary["ok"] and slot >= MANUAL_SLOT_RANGE.x and slot <= MANUAL_SLOT_RANGE.y:
		mirror_result = _save_to_slot_io_only(AUTOSAVE_SLOT, sg)

	# AC-10: transition to IDLE BEFORE emitting any signals. A save_failed
	# subscriber that calls save_to_slot synchronously will see IDLE.
	_set_state(State.IDLE)
	_drain_queue()

	# Emit signals after state is IDLE and queue drain has started.
	if not primary["ok"]:
		# Primary slot failed — emit failure and return false.
		Events.save_failed.emit(primary["reason"])
		return false

	# Primary slot succeeded — emit game_saved for the primary slot.
	Events.game_saved.emit(slot, primary["section_id"])

	# Handle mirror result if a mirror was attempted.
	if not mirror_result.is_empty():
		if mirror_result["ok"]:
			Events.game_saved.emit(AUTOSAVE_SLOT, mirror_result["section_id"])
		else:
			push_warning(
				"Save/Load: slot %d saved but slot 0 mirror failed" % slot
			)
			Events.save_failed.emit(mirror_result["reason"])

	return true


## Performs a guarded load: sets LOADING, runs the full load (IO + type-guard
## + version check), sets IDLE, drains queue, THEN emits signals.
## AC-10 ordering applies: state is IDLE before game_loaded or save_failed emit.
##
## Returns the loaded SaveGame on success; null on any failure.
func _do_load(slot: int) -> SaveGame:
	_set_state(State.LOADING)

	var path: String = SAVE_DIR + "slot_%d.res" % slot
	var failure_reason: int = FailureReason.NONE
	var loaded_sg: SaveGame = null

	# Step 1 — slot file present?
	if not FileAccess.file_exists(path):
		failure_reason = FailureReason.SLOT_NOT_FOUND
	else:
		# Step 2 — load from disk.
		var loaded: Resource = _load_resource(path)

		# Step 3 — type-guard.
		if loaded == null or not (loaded is SaveGame):
			failure_reason = FailureReason.CORRUPT_FILE
		else:
			var sg: SaveGame = loaded as SaveGame
			# Step 4 — version compare.
			if sg.save_format_version != SaveGame.FORMAT_VERSION:
				failure_reason = FailureReason.VERSION_MISMATCH
			else:
				# Step 5 — success.
				loaded_sg = sg

	# AC-10: transition to IDLE BEFORE emitting any signals.
	_set_state(State.IDLE)
	_drain_queue()

	# Emit signals after state is IDLE.
	if failure_reason != FailureReason.NONE:
		Events.save_failed.emit(failure_reason)
	else:
		Events.game_loaded.emit(slot)

	return loaded_sg


## Appends a Callable to the FIFO queue if depth permits.
## Returns true ("accepted") if queued successfully.
## Returns false ("rejected") if the queue is already at MAX_QUEUE_DEPTH.
func _enqueue(op: Callable) -> bool:
	if _queue.size() >= MAX_QUEUE_DEPTH:
		push_warning(
			"Save/Load: queue full (%d) — dropping operation" % _queue.size()
		)
		return false
	_queue.append(op)
	return true


## Pops and executes the next queued operation (if any). Called after every
## completed _do_save / _do_load. The executed op may itself enqueue more —
## recursion is bounded by MAX_QUEUE_DEPTH (4).
func _drain_queue() -> void:
	if _queue.is_empty():
		return
	var next: Callable = _queue.pop_front()
	next.call()


# ---------------------------------------------------------------------------
# Internal helpers — overridable for fault injection in tests
# ---------------------------------------------------------------------------

## Executes the full 7-step atomic write protocol for a single slot.
## Returns a result Dictionary with keys:
##   ok         : bool          — true on full success
##   reason     : int           — FailureReason value (NONE on success)
##   section_id : StringName    — populated on success (from save_game)
##
## NO SIGNALS are emitted from this method. Signal emission is the
## responsibility of _do_save (after state transitions to IDLE — AC-10).
## This is the only internal building block for IO — _save_resource and
## _rename_file are the override seams for fault injection.
##
## Steps:
##   1. Ensure SAVE_DIR exists (idempotent).
##   2. ResourceSaver.save to tmp file.
##   3. If non-OK: return {ok=false, reason=IO_ERROR}.
##   4. DirAccess.rename(tmp, final).
##   5. If non-OK: clean up tmp, return {ok=false, reason=RENAME_FAILED}.
##   6. Write metadata sidecar (partial-success: sidecar fail logs only).
##   7. Return {ok=true, reason=NONE, section_id=save_game.section_id}.
func _save_to_slot_io_only(slot: int, save_game: SaveGame) -> Dictionary:
	# Step 1 — ensure SAVE_DIR exists. Idempotent; a no-op if it already does.
	var dir_err: Error = DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
		return {
			"ok": false,
			"reason": FailureReason.IO_ERROR,
			"section_id": &"",
		}

	var tmp_path: String = SAVE_DIR + "slot_%d.tmp.res" % slot
	var final_path: String = SAVE_DIR + "slot_%d.res" % slot

	# Step 2 — write to tmp file. tmp suffix MUST end in `.res` per F1.
	var save_err: Error = _save_resource(save_game, tmp_path, ResourceSaver.FLAG_COMPRESS)

	# Step 3 — bail out on save failure.
	if save_err != OK:
		_remove_if_exists(tmp_path)
		return {
			"ok": false,
			"reason": FailureReason.IO_ERROR,
			"section_id": &"",
		}

	# Step 4 — atomic rename.
	var rename_err: Error = _rename_file(tmp_path, final_path)

	# Step 5 — bail out on rename failure.
	if rename_err != OK:
		_remove_if_exists(tmp_path)
		return {
			"ok": false,
			"reason": FailureReason.RENAME_FAILED,
			"section_id": &"",
		}

	# Step 6 — write metadata sidecar (partial-success path; sidecar fail is
	# not fatal since the .res is already committed above).
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

	# Step 7 — success.
	return {
		"ok": true,
		"reason": FailureReason.NONE,
		"section_id": save_game.section_id,
	}


## Executes the full 7-step atomic write protocol for a single slot AND emits
## signals. This wrapper delegates IO to _save_to_slot_io_only and then emits
## game_saved or save_failed.
##
## This is NOT called by _do_save (which handles signal emission itself for
## AC-10 ordering). It exists for any external caller that needs atomic-write
## semantics with synchronous signal emission (e.g., post-MVP callers that
## bypass the state machine intentionally — not recommended).
##
## AC-9: _save_to_slot_atomic is NOT a test seam — override _save_resource or
## _rename_file for fault injection. This method MUST NOT modify the
## SaveLoadService state-machine field (see AC-9 enforcement test).
func _save_to_slot_atomic(slot: int, save_game: SaveGame) -> bool:
	var result: Dictionary = _save_to_slot_io_only(slot, save_game)
	if not result["ok"]:
		Events.save_failed.emit(result["reason"])
		return false
	Events.game_saved.emit(slot, result["section_id"])
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
## load step. CACHE_MODE_IGNORE forces a fresh disk read so callers
## always get the on-disk truth (mitigates the cross-call state-leak risk
## in AC-8 — Story SL-004 still mandates duplicate_deep at the call site).
## Production code MUST NOT call this directly — use load_from_slot.
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
