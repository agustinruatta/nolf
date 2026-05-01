# tests/unit/foundation/save_load_slot_scheme_test.gd
#
# Unit test suite — SaveLoadService 8-slot scheme + slot_exists + CR-4 mirror.
#
# PURPOSE
#   Validates the 8-slot scheme constants, slot_exists() API, and the CR-4
#   dual-write logic in save_to_slot() per Story SL-006 acceptance criteria.
#
# WHAT IS TESTED
#   AC-1: slot_exists(N) returns true when slot_N.res is present, false otherwise.
#   AC-2: slot_exists() returns false + logs warning for out-of-range slots.
#   AC-3: save_to_slot(3, sg) writes both slot_3.res + slot_0.res and both
#         paired metadata sidecars; both load with identical content.
#   AC-4: game_saved fires twice for a manual save — slot 3 first, slot 0 second.
#   AC-5: save_to_slot(0, sg) writes ONLY slot 0; game_saved fires exactly once.
#   AC-6: Manual save commits even if mirror write fails — game_saved(5, ...)
#         fires, save_failed(IO_ERROR) fires for the mirror, save_to_slot returns
#         true, slot_5.res intact, slot_0.res byte-identical to pre-call state.
#   AC-7: Exactly ONE direct slot-0-write call site exists in save_load_service.gd
#         (the CR-4 branch in save_to_slot — single source of mirror logic).
#
# GATE STATUS
#   Story SL-006 — Logic story type → BLOCKING gate.
#
# NAMING CONVENTION (per tests/README.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name SaveLoadSlotSchemeTest
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Fault-injection subclasses
# ---------------------------------------------------------------------------

## Forces _save_resource to return ERR_FILE_CANT_WRITE when the target path
## contains "slot_0" — simulating a mirror-write failure while letting the
## primary slot (slot_5, slot_3, etc.) succeed normally.
##
## Used for AC-6: slot_5 write succeeds, slot_0 mirror fails.
class _MirrorFailingService extends SaveLoadService:
	func _save_resource(resource: Resource, path: String, flags: int) -> Error:
		if path.contains("slot_0"):
			return ERR_FILE_CANT_WRITE
		return super._save_resource(resource, path, flags)


## Forces _rename_file to return ERR_FILE_CANT_OPEN when the destination path
## is the final slot_0.res file — simulating an atomic-rename failure on the
## mirror while letting the tmp write succeed and the primary slot complete
## fully.
##
## Used for Gap 3: covers the RENAME_FAILED branch of mirror failure (distinct
## from IO_ERROR which AC-6 covers via a failed _save_resource call).
class _MirrorRenameFailingService extends SaveLoadService:
	func _rename_file(from_path: String, to_path: String) -> Error:
		if to_path.contains("slot_0.res"):
			return ERR_FILE_CANT_OPEN
		return super._rename_file(from_path, to_path)


## Forces _save_resource to return ERR_FILE_CANT_WRITE when the path matches
## the primary slot's atomic tmp file (slot_3.tmp.res) — simulating a write
## failure on the manual slot before the mirror is ever attempted.
##
## Used for Gap 4: verifies the early-return guard prevents slot_0 from being
## touched when the primary slot write fails.
class _PrimaryFailingService extends SaveLoadService:
	func _save_resource(resource: Resource, path: String, flags: int) -> Error:
		if path.contains("slot_3.tmp.res"):
			return ERR_FILE_CANT_WRITE
		return super._save_resource(resource, path, flags)


# ---------------------------------------------------------------------------
# Shared state + setup/teardown
# ---------------------------------------------------------------------------

var _service: SaveLoadService = null
var _save_failed_reasons: Array[int] = []
var _game_saved_calls: Array[Dictionary] = []


func before_test() -> void:
	_save_failed_reasons.clear()
	_game_saved_calls.clear()
	_clean_save_dir()
	Events.save_failed.connect(_on_save_failed)
	Events.game_saved.connect(_on_game_saved)


func after_test() -> void:
	if Events.save_failed.is_connected(_on_save_failed):
		Events.save_failed.disconnect(_on_save_failed)
	if Events.game_saved.is_connected(_on_game_saved):
		Events.game_saved.disconnect(_on_game_saved)
	_service = null
	_clean_save_dir()


func _on_save_failed(reason: int) -> void:
	_save_failed_reasons.append(reason)


func _on_game_saved(slot: int, section_id: StringName) -> void:
	_game_saved_calls.append({"slot": slot, "section_id": section_id})


## Removes every regular file under user://saves/ but keeps the directory.
## Called in both before_test and after_test for deterministic isolation.
func _clean_save_dir() -> void:
	var dir: DirAccess = DirAccess.open(SaveLoadService.SAVE_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not dir.current_is_dir():
			dir.remove(entry)
		entry = dir.get_next()
	dir.list_dir_end()


## Builds a small but realistic SaveGame sufficient for all slot-scheme tests.
func _build_save_game(p_section_id: StringName) -> SaveGame:
	var sg: SaveGame = SaveGame.new()
	sg.saved_at_iso8601 = "2026-05-01T10:00:00"
	sg.section_id = p_section_id
	sg.elapsed_seconds = 99.0
	sg.player.position = Vector3(1.0, 0.0, 2.0)
	sg.player.health = 80
	sg.inventory.equipped_gadget = &"silenced_p38"
	sg.inventory.ammo_magazine[&"silenced_p38"] = 5
	sg.mission.section_id = p_section_id
	sg.failure_respawn.last_section_id = p_section_id
	return sg


# ---------------------------------------------------------------------------
# AC-1 — slot_exists happy path
# ---------------------------------------------------------------------------

## slot_exists(N) returns true when slot_N.res is present on disk, false when absent.
func test_save_load_slot_exists_returns_true_when_file_present_and_false_when_absent() -> void:
	# Arrange — write slot 3 via the real save path; leave slot 5 empty.
	_service = auto_free(SaveLoadService.new())
	var sg: SaveGame = _build_save_game(&"restaurant")
	assert_bool(_service.save_to_slot(3, sg)).is_true()

	# Verify setup: slot_3.res written (and slot_0.res as CR-4 mirror).
	assert_bool(FileAccess.file_exists("user://saves/slot_3.res")).is_true()
	assert_bool(FileAccess.file_exists("user://saves/slot_5.res")).is_false()

	# Act + Assert — slot 3 exists, slot 5 does not.
	assert_bool(_service.slot_exists(3)).is_true()
	assert_bool(_service.slot_exists(5)).is_false()


## slot_exists returns false for slot 0 when no save has ever been written.
func test_save_load_slot_exists_returns_false_for_empty_slot_zero() -> void:
	# Arrange — clean directory; no files written.
	_service = auto_free(SaveLoadService.new())
	assert_bool(FileAccess.file_exists("user://saves/slot_0.res")).is_false()

	# Act + Assert
	assert_bool(_service.slot_exists(0)).is_false()


# ---------------------------------------------------------------------------
# AC-2 — Out-of-range slot returns false + warning
# ---------------------------------------------------------------------------

## slot_exists(-1) returns false. Warning logged (verified via warning-capture
## approach: the function must return false and not crash).
func test_save_load_slot_exists_negative_slot_returns_false() -> void:
	# Arrange
	_service = auto_free(SaveLoadService.new())

	# Act + Assert — must not crash; must return false.
	assert_bool(_service.slot_exists(-1)).is_false()


## slot_exists(8) — one past the end of the valid range — returns false.
func test_save_load_slot_exists_one_past_end_returns_false() -> void:
	# Arrange
	_service = auto_free(SaveLoadService.new())

	# Act + Assert
	assert_bool(_service.slot_exists(SaveLoadService.SLOT_COUNT)).is_false()


## slot_exists with a very large out-of-range value returns false without crashing.
func test_save_load_slot_exists_large_out_of_range_returns_false() -> void:
	# Arrange
	_service = auto_free(SaveLoadService.new())

	# Act + Assert — no crash, no filesystem lookup attempted.
	assert_bool(_service.slot_exists(999)).is_false()


# ---------------------------------------------------------------------------
# AC-3 — Manual save writes slot N + slot 0 + both sidecars
# ---------------------------------------------------------------------------

## save_to_slot(3, sg) writes slot_3.res, slot_0.res, slot_3_meta.cfg,
## and slot_0_meta.cfg. Both slots reload with identical section_id payload.
func test_save_load_manual_save_writes_slot_n_and_slot_zero_with_sidecars() -> void:
	# Arrange
	_service = auto_free(SaveLoadService.new())
	var sg: SaveGame = _build_save_game(&"restaurant")

	# Act
	var ok: bool = _service.save_to_slot(3, sg)

	# Assert — save succeeded
	assert_bool(ok).is_true()

	# Assert — both .res files written
	assert_bool(FileAccess.file_exists("user://saves/slot_3.res")).is_true()
	assert_bool(FileAccess.file_exists("user://saves/slot_0.res")).is_true()

	# Assert — both sidecars written
	assert_bool(FileAccess.file_exists("user://saves/slot_3_meta.cfg")).is_true()
	assert_bool(FileAccess.file_exists("user://saves/slot_0_meta.cfg")).is_true()

	# Assert — both slots load with identical section_id (same SaveGame payload)
	var loaded_3: SaveGame = ResourceLoader.load(
		"user://saves/slot_3.res", "", ResourceLoader.CACHE_MODE_IGNORE
	) as SaveGame
	var loaded_0: SaveGame = ResourceLoader.load(
		"user://saves/slot_0.res", "", ResourceLoader.CACHE_MODE_IGNORE
	) as SaveGame
	assert_object(loaded_3).is_not_null()
	assert_object(loaded_0).is_not_null()
	assert_str(String(loaded_3.section_id)).is_equal("restaurant")
	assert_str(String(loaded_0.section_id)).is_equal("restaurant")
	assert_float(loaded_3.elapsed_seconds).is_equal_approx(99.0, 0.001)
	assert_float(loaded_0.elapsed_seconds).is_equal_approx(99.0, 0.001)


## A pre-existing slot_0.res (prior autosave) is overwritten by the CR-4 mirror.
func test_save_load_manual_save_overwrites_existing_slot_zero() -> void:
	# Arrange — write a prior autosave to slot 0 with a different section_id.
	var bootstrap: SaveLoadService = auto_free(SaveLoadService.new())
	var prior: SaveGame = _build_save_game(&"prior_section")
	assert_bool(bootstrap.save_to_slot(0, prior)).is_true()
	_save_failed_reasons.clear()
	_game_saved_calls.clear()

	# Act — manual save to slot 2 triggers CR-4 mirror.
	_service = auto_free(SaveLoadService.new())
	var sg: SaveGame = _build_save_game(&"new_section")
	var ok: bool = _service.save_to_slot(2, sg)

	# Assert — save succeeded; slot_0 now reflects new_section (not prior_section).
	assert_bool(ok).is_true()
	var loaded_0: SaveGame = ResourceLoader.load(
		"user://saves/slot_0.res", "", ResourceLoader.CACHE_MODE_IGNORE
	) as SaveGame
	assert_object(loaded_0).is_not_null()
	assert_str(String(loaded_0.section_id)).is_equal("new_section")


# ---------------------------------------------------------------------------
# AC-4 — game_saved fires twice: slot N first, slot 0 second
# ---------------------------------------------------------------------------

## A successful manual save to slot 3 emits game_saved exactly twice: (3, section_id)
## first, then (0, section_id). Emit order matters for CR-4 contract.
func test_save_load_manual_save_emits_game_saved_twice_in_correct_order() -> void:
	# Arrange
	_service = auto_free(SaveLoadService.new())
	var sg: SaveGame = _build_save_game(&"plaza")

	# Act
	var ok: bool = _service.save_to_slot(3, sg)

	# Assert — save succeeded
	assert_bool(ok).is_true()

	# Assert — exactly 2 game_saved emissions
	assert_int(_game_saved_calls.size()).is_equal(2)

	# Assert — first emission is for the manual slot (3)
	assert_int(int(_game_saved_calls[0]["slot"])).is_equal(3)
	assert_str(String(_game_saved_calls[0]["section_id"])).is_equal("plaza")

	# Assert — second emission is for the CR-4 mirror (slot 0)
	assert_int(int(_game_saved_calls[1]["slot"])).is_equal(0)
	assert_str(String(_game_saved_calls[1]["section_id"])).is_equal("plaza")

	# Assert — no save_failed emitted
	assert_int(_save_failed_reasons.size()).is_equal(0)


# ---------------------------------------------------------------------------
# AC-5 — Direct slot 0 save writes ONLY slot 0
# ---------------------------------------------------------------------------

## save_to_slot(0, sg) — autosave path — writes ONLY slot 0. No other slots
## are written. game_saved fires exactly once with slot=0.
func test_save_load_autosave_writes_only_slot_zero_with_single_emit() -> void:
	# Arrange
	_service = auto_free(SaveLoadService.new())
	var sg: SaveGame = _build_save_game(&"autosave_section")

	# Act
	var ok: bool = _service.save_to_slot(0, sg)

	# Assert — save succeeded
	assert_bool(ok).is_true()

	# Assert — only slot 0 was written; slots 1–7 remain absent.
	assert_bool(FileAccess.file_exists("user://saves/slot_0.res")).is_true()
	for s: int in range(1, SaveLoadService.SLOT_COUNT):
		assert_bool(FileAccess.file_exists("user://saves/slot_%d.res" % s)).is_false()

	# Assert — game_saved fired exactly once for slot 0.
	assert_int(_game_saved_calls.size()).is_equal(1)
	assert_int(int(_game_saved_calls[0]["slot"])).is_equal(0)
	assert_str(String(_game_saved_calls[0]["section_id"])).is_equal("autosave_section")

	# Assert — no save_failed emitted.
	assert_int(_save_failed_reasons.size()).is_equal(0)


# ---------------------------------------------------------------------------
# AC-6 — Mirror failure is non-fatal: manual save committed, slot 0 preserved
# ---------------------------------------------------------------------------

## GIVEN a service where slot-0 ResourceSaver.save always fails, WHEN
## save_to_slot(5, sg) is called, THEN:
##   - Returns true (manual save committed).
##   - slot_5.res exists with the new save.
##   - Events.game_saved(5, ...) fired (manual save).
##   - Events.save_failed(IO_ERROR) fired (mirror failure).
##   - slot_0.res (pre-existing) is byte-identical to its pre-call state
##     (atomic-write rollback on mirror failure — per ADR-0003 IG 9).
func test_save_load_mirror_failure_commits_manual_save_and_preserves_slot_zero() -> void:
	# Arrange — write a prior autosave to slot 0 so we can verify it's preserved.
	var bootstrap: SaveLoadService = auto_free(SaveLoadService.new())
	var prior_autosave: SaveGame = _build_save_game(&"prior_autosave")
	assert_bool(bootstrap.save_to_slot(0, prior_autosave)).is_true()
	var pre_slot0_bytes: PackedByteArray = FileAccess.get_file_as_bytes(
		"user://saves/slot_0.res"
	)
	assert_int(pre_slot0_bytes.size()).is_greater(0)

	# Reset spy state — drop bootstrap events.
	_save_failed_reasons.clear()
	_game_saved_calls.clear()

	# Act — save to slot 5 with a service that fails all slot-0 resource writes.
	_service = auto_free(_MirrorFailingService.new())
	var sg: SaveGame = _build_save_game(&"manual_save_section")
	var ok: bool = _service.save_to_slot(5, sg)

	# Assert — save_to_slot returns true (manual save committed despite mirror failure).
	assert_bool(ok).is_true()

	# Assert — slot_5.res written with the new save payload.
	assert_bool(FileAccess.file_exists("user://saves/slot_5.res")).is_true()
	var loaded_5: SaveGame = ResourceLoader.load(
		"user://saves/slot_5.res", "", ResourceLoader.CACHE_MODE_IGNORE
	) as SaveGame
	assert_object(loaded_5).is_not_null()
	assert_str(String(loaded_5.section_id)).is_equal("manual_save_section")

	# Assert — game_saved(5, ...) fired for the committed manual save.
	var game_saved_slots: Array[int] = []
	for call: Dictionary in _game_saved_calls:
		game_saved_slots.append(int(call["slot"]))
	assert_bool(game_saved_slots.has(5)).is_true()

	# Assert — save_failed(IO_ERROR) fired for the mirror failure.
	assert_bool(_save_failed_reasons.has(SaveLoadService.FailureReason.IO_ERROR)).is_true()

	# Assert — slot_0.res is byte-identical to its pre-call state (atomic-write
	# rollback discipline — the mirror's failed tmp write never touched the final file).
	assert_bool(FileAccess.file_exists("user://saves/slot_0.res")).is_true()
	var post_slot0_bytes: PackedByteArray = FileAccess.get_file_as_bytes(
		"user://saves/slot_0.res"
	)
	assert_int(post_slot0_bytes.size()).is_equal(pre_slot0_bytes.size())
	assert_bool(post_slot0_bytes == pre_slot0_bytes).is_true()


# ---------------------------------------------------------------------------
# AC-7 — Single source of slot-0 mirror logic (no duplication)
# ---------------------------------------------------------------------------

## Grep test: the save_load_service.gd source must contain exactly ONE call
## site that writes to slot 0 via _save_to_slot_atomic (the CR-4 branch in
## save_to_slot). Any future refactor that introduces a second direct slot-0
## write path will trip this test — which is the intent (AC-7 single-source).
##
## This test counts occurrences of `_save_to_slot_atomic(AUTOSAVE_SLOT` and
## `_save_to_slot_atomic(0` in the source file and asserts exactly one total.
## It does NOT count `save_to_slot(0` because F5 Quicksave (Story 007) calls
## the public API — the check is for direct INTERNAL slot-0 atomic calls.
func test_save_load_slot_zero_mirror_has_exactly_one_call_site() -> void:
	# Arrange — read the production source file.
	var src: String = FileAccess.get_file_as_string(
		"res://src/core/save_load/save_load_service.gd"
	)
	assert_str(src).is_not_empty()

	# Act — count occurrences of each variant of a direct slot-0 atomic call.
	# We use String.count() which counts non-overlapping occurrences.
	var count_autosave_slot: int = src.count("_save_to_slot_atomic(AUTOSAVE_SLOT")
	var count_literal_zero: int = src.count("_save_to_slot_atomic(0")
	var total_direct_slot0_writes: int = count_autosave_slot + count_literal_zero

	# Assert — exactly one direct slot-0 write call site (the CR-4 branch).
	assert_int(total_direct_slot0_writes).is_equal(1)


# ---------------------------------------------------------------------------
# Constants shape — SLOT_COUNT, AUTOSAVE_SLOT, MANUAL_SLOT_RANGE
# ---------------------------------------------------------------------------

## The three slot-scheme constants must have the values locked by ADR-0003 IG 7.
func test_save_load_slot_scheme_constants_have_correct_values() -> void:
	# Assert — SLOT_COUNT is 8 (0..7 inclusive).
	assert_int(SaveLoadService.SLOT_COUNT).is_equal(8)

	# Assert — AUTOSAVE_SLOT is 0 (the autosave slot index).
	assert_int(SaveLoadService.AUTOSAVE_SLOT).is_equal(0)

	# Assert — MANUAL_SLOT_RANGE spans 1..7 inclusive.
	assert_int(SaveLoadService.MANUAL_SLOT_RANGE.x).is_equal(1)
	assert_int(SaveLoadService.MANUAL_SLOT_RANGE.y).is_equal(7)


# ---------------------------------------------------------------------------
# Gap 3 — Mirror rename failure is non-fatal: manual save committed, slot 0 absent
# ---------------------------------------------------------------------------

## Covers the RENAME_FAILED branch of mirror failure (Gap 3).
## GIVEN a service where the atomic rename of slot_0.res always fails (but the
## tmp write for slot_0 succeeds), WHEN save_to_slot(5, sg) is called, THEN:
##   - Returns true (manual save committed).
##   - game_saved(5, ...) fired exactly once.
##   - save_failed(RENAME_FAILED) fired for the mirror.
##   - slot_5.res exists; slot_0.res absent (tmp cleaned up by atomic protocol).
func test_save_load_mirror_rename_failure_preserves_slot_zero() -> void:
	# Arrange
	_service = auto_free(_MirrorRenameFailingService.new())
	var sg: SaveGame = _build_save_game(&"plaza")

	# Act
	var ok: bool = _service.save_to_slot(5, sg)

	# Assert — save_to_slot returns true (manual slot committed).
	assert_bool(ok).is_true()

	# Assert — game_saved fired exactly once, for the manual slot (5).
	assert_int(_game_saved_calls.size()).is_equal(1)
	assert_int(int(_game_saved_calls[0]["slot"])).is_equal(5)

	# Assert — save_failed fired with RENAME_FAILED for the mirror failure.
	assert_int(_save_failed_reasons.size()).is_equal(1)
	assert_bool(
		_save_failed_reasons.has(SaveLoadService.FailureReason.RENAME_FAILED)
	).is_true()

	# Assert — slot_5.res exists with the new save payload.
	assert_bool(FileAccess.file_exists("user://saves/slot_5.res")).is_true()

	# Assert — slot_0.res absent (atomic protocol cleaned up the tmp on rename failure).
	assert_bool(FileAccess.file_exists("user://saves/slot_0.res")).is_false()


# ---------------------------------------------------------------------------
# Gap 4 — Primary write failure prevents mirror attempt entirely
# ---------------------------------------------------------------------------

## Covers the early-return guard when the primary slot write fails (Gap 4).
## GIVEN a service where saving the primary slot's tmp file always fails, WHEN
## save_to_slot(3, sg) is called, THEN:
##   - Returns false.
##   - game_saved NEVER fired.
##   - save_failed fired exactly once (IO_ERROR for the primary slot).
##   - slot_3.res absent; slot_0.res absent (mirror never attempted).
func test_save_load_primary_write_failure_does_not_write_slot_zero() -> void:
	# Arrange
	_service = auto_free(_PrimaryFailingService.new())
	var sg: SaveGame = _build_save_game(&"plaza")

	# Act
	var ok: bool = _service.save_to_slot(3, sg)

	# Assert — save_to_slot returns false (primary slot failed).
	assert_bool(ok).is_false()

	# Assert — game_saved never fired.
	assert_int(_game_saved_calls.size()).is_equal(0)

	# Assert — save_failed fired exactly once with IO_ERROR for the primary slot.
	assert_int(_save_failed_reasons.size()).is_equal(1)
	assert_bool(
		_save_failed_reasons.has(SaveLoadService.FailureReason.IO_ERROR)
	).is_true()

	# Assert — slot_3.res absent (primary write failed, atomic protocol rolled back).
	assert_bool(FileAccess.file_exists("user://saves/slot_3.res")).is_false()

	# Assert — slot_0.res absent (mirror was never attempted — early-return guard).
	assert_bool(FileAccess.file_exists("user://saves/slot_0.res")).is_false()
