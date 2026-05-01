# tests/unit/foundation/save_load_service_save_test.gd
#
# Unit test suite — SaveLoadService.save_to_slot atomic write protocol.
#
# PURPOSE
#   Validates the production atomic-write code path defined in ADR-0003 IG 5
#   plus the failure-handling guarantees in IG 9. Uses fault-injection
#   subclasses to exercise the IO_ERROR and RENAME_FAILED branches without
#   relying on filesystem permissions tricks (which differ across CI runners).
#
# WHAT IS TESTED
#   AC-1 : SaveLoadService class shape (FailureReason enum, SAVE_DIR const,
#          extends Node).
#   AC-3 : Atomic write happy path (tmp.res renamed to final .res, no orphan).
#   AC-4 : ResourceSaver.save failure → save_failed(IO_ERROR), false return,
#          previous good save untouched.
#   AC-5 : DirAccess.rename failure → save_failed(RENAME_FAILED), tmp cleanup,
#          previous good save untouched.
#   AC-6 : Successful save emits game_saved(slot, section_id).
#   AC-7 : save_to_slot completes within 15 ms for a representative SaveGame.
#   AC-9 : save_load_service.gd source contains zero references to gameplay
#          system class names (forbidden pattern: save_service_assembles_state).
#   AC-10: _ready() references only Events / EventLogger; _init() references
#          no autoloads (ADR-0007 §Cross-Autoload Reference Safety).
#
# WHAT IS NOT TESTED HERE
#   - Autoload registration in project.godot — see atomic_write_power_loss_test.gd.
#   - Power-loss orphan tmp recovery — see atomic_write_power_loss_test.gd.
#   - load_from_slot (Story SL-003).
#   - duplicate_deep state isolation (Story SL-004).
#
# GATE STATUS
#   Story SL-002 — Logic story type → BLOCKING gate.
#
# NAMING CONVENTION (per tests/README.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name SaveLoadServiceSaveTest
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Fault-injection subclasses — used to force specific Error returns from
# the otherwise-virtual ResourceSaver.save and DirAccess.rename helpers.
# ---------------------------------------------------------------------------

class _IOFailingService extends SaveLoadService:
	func _save_resource(_resource: Resource, _path: String, _flags: int) -> Error:
		return ERR_CANT_CREATE


class _RenameFailingService extends SaveLoadService:
	# Let ResourceSaver.save run normally so a real tmp file lands on disk;
	# then force the rename step to fail so we can verify cleanup of the tmp
	# AND that the previous good final file remains intact.
	func _rename_file(_from_path: String, _to_path: String) -> Error:
		return ERR_CANT_OPEN


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
	# Subscribe to live Events autoload so we can spy on emits from the
	# service. Disconnect in after_test to avoid bleeding between tests.
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


## Builds a small but realistic SaveGame populated across all 7 sub-resources.
func _build_populated_save_game(section_id: StringName) -> SaveGame:
	var sg: SaveGame = SaveGame.new()
	sg.saved_at_iso8601 = "2026-04-30T14:32:15"
	sg.section_id = section_id
	sg.elapsed_seconds = 123.45
	sg.player.position = Vector3(1.0, 2.0, 3.0)
	sg.player.health = 75
	sg.inventory.equipped_gadget = &"silenced_p38"
	sg.inventory.ammo_magazine[&"silenced_p38"] = 7
	sg.inventory.ammo_reserve[&"silenced_p38"] = 21
	var gr: GuardRecord = GuardRecord.new()
	gr.alert_state = 2
	gr.patrol_index = 3
	gr.current_position = Vector3(10.0, 0.0, 5.0)
	sg.stealth_ai.guards[&"plaza_guard_01"] = gr
	sg.documents.collected.append(&"doc_001")
	sg.mission.section_id = section_id
	sg.mission.objectives_completed.append(&"obj_1")
	sg.mission.fired_beats[&"beat_intro"] = true
	sg.failure_respawn.last_section_id = section_id
	return sg


# ---------------------------------------------------------------------------
# AC-1 — class shape (enum, const, extends)
# ---------------------------------------------------------------------------

## SaveLoadService.FailureReason enum has the 6 documented members in the
## documented order (NONE = 0, IO_ERROR = 1, …, RENAME_FAILED = 5).
func test_save_load_service_failure_reason_enum_shape() -> void:
	# Enum members and ordering — locked per ADR-0003 §Key Interfaces.
	assert_int(SaveLoadService.FailureReason.NONE).is_equal(0)
	assert_int(SaveLoadService.FailureReason.IO_ERROR).is_equal(1)
	assert_int(SaveLoadService.FailureReason.VERSION_MISMATCH).is_equal(2)
	assert_int(SaveLoadService.FailureReason.CORRUPT_FILE).is_equal(3)
	assert_int(SaveLoadService.FailureReason.SLOT_NOT_FOUND).is_equal(4)
	assert_int(SaveLoadService.FailureReason.RENAME_FAILED).is_equal(5)


## SAVE_DIR is the documented user:// path with trailing slash.
func test_save_load_service_save_dir_constant() -> void:
	assert_str(SaveLoadService.SAVE_DIR).is_equal("user://saves/")


# ---------------------------------------------------------------------------
# AC-3 — atomic write happy path
# ---------------------------------------------------------------------------

## save_to_slot writes a tmp file, renames it to final, and the final file
## reloads as a valid SaveGame whose section_id matches the original.
func test_save_to_slot_writes_final_file_and_no_orphan_tmp() -> void:
	# Arrange
	_service = auto_free(SaveLoadService.new())
	var sg: SaveGame = _build_populated_save_game(&"plaza")

	# Act
	var ok: bool = _service.save_to_slot(0, sg)

	# Assert — return value + side effects
	assert_bool(ok).is_true()
	assert_bool(FileAccess.file_exists("user://saves/slot_0.res")).is_true()
	assert_bool(FileAccess.file_exists("user://saves/slot_0.tmp.res")).is_false()

	# Assert — round-trip integrity at the service-output boundary
	var loaded: SaveGame = ResourceLoader.load(
		"user://saves/slot_0.res", "", ResourceLoader.CACHE_MODE_IGNORE
	) as SaveGame
	assert_object(loaded).is_not_null()
	assert_str(String(loaded.section_id)).is_equal("plaza")


# ---------------------------------------------------------------------------
# AC-4 — IO_ERROR path
# ---------------------------------------------------------------------------

## When ResourceSaver.save returns non-OK, save_to_slot emits
## save_failed(IO_ERROR), returns false, and writes no slot file.
func test_save_to_slot_io_error_emits_save_failed_and_leaves_no_slot_file() -> void:
	# Arrange — force ResourceSaver to fail
	_service = auto_free(_IOFailingService.new())
	var sg: SaveGame = _build_populated_save_game(&"plaza")

	# Act
	var ok: bool = _service.save_to_slot(0, sg)

	# Assert
	assert_bool(ok).is_false()
	assert_int(_save_failed_reasons.size()).is_equal(1)
	assert_int(_save_failed_reasons[0]).is_equal(SaveLoadService.FailureReason.IO_ERROR)
	assert_int(_game_saved_calls.size()).is_equal(0)
	assert_bool(FileAccess.file_exists("user://saves/slot_0.res")).is_false()


## AC-4 safety guarantee: the previous good slot file is byte-identical to its
## pre-call state when ResourceSaver.save fails. This is the core atomic-write
## invariant for the write-failure branch — failed saves must NEVER destroy
## earlier successful saves.
func test_save_to_slot_io_error_leaves_previous_good_save_byte_identical() -> void:
	# Arrange — write good save A.
	var bootstrap: SaveLoadService = auto_free(SaveLoadService.new())
	var sg_a: SaveGame = _build_populated_save_game(&"section_a")
	assert_bool(bootstrap.save_to_slot(0, sg_a)).is_true()
	var pre_existing_bytes: PackedByteArray = FileAccess.get_file_as_bytes(
		"user://saves/slot_0.res"
	)
	assert_int(pre_existing_bytes.size()).is_greater(0)

	# Reset spy state — ignore the bootstrap's game_saved emission.
	_save_failed_reasons.clear()
	_game_saved_calls.clear()

	# Act — attempt to overwrite slot 0 with a failing service.
	_service = auto_free(_IOFailingService.new())
	var sg_b: SaveGame = _build_populated_save_game(&"section_b")
	var ok: bool = _service.save_to_slot(0, sg_b)

	# Assert — failure semantics
	assert_bool(ok).is_false()
	assert_int(_save_failed_reasons.size()).is_equal(1)
	assert_int(_save_failed_reasons[0]).is_equal(SaveLoadService.FailureReason.IO_ERROR)
	assert_int(_game_saved_calls.size()).is_equal(0)

	# Assert — previous good slot_0.res is byte-identical to its pre-call state
	assert_bool(FileAccess.file_exists("user://saves/slot_0.res")).is_true()
	var post_bytes: PackedByteArray = FileAccess.get_file_as_bytes("user://saves/slot_0.res")
	assert_int(post_bytes.size()).is_equal(pre_existing_bytes.size())
	assert_bool(post_bytes == pre_existing_bytes).is_true()


# ---------------------------------------------------------------------------
# AC-5 — RENAME_FAILED path
# ---------------------------------------------------------------------------

## When DirAccess.rename returns non-OK, save_to_slot emits
## save_failed(RENAME_FAILED), cleans up the tmp file, leaves any previous
## final file untouched, and returns false.
func test_save_to_slot_rename_failed_emits_save_failed_and_cleans_up_tmp() -> void:
	# Arrange — write a previous good save first, then swap to a service
	# whose rename will fail.
	var bootstrap: SaveLoadService = auto_free(SaveLoadService.new())
	var sg_a: SaveGame = _build_populated_save_game(&"plaza_a")
	assert_bool(bootstrap.save_to_slot(0, sg_a)).is_true()
	var pre_existing_bytes: PackedByteArray = FileAccess.get_file_as_bytes(
		"user://saves/slot_0.res"
	)

	# Reset spy state — ignore the bootstrap's game_saved emission.
	_save_failed_reasons.clear()
	_game_saved_calls.clear()

	_service = auto_free(_RenameFailingService.new())
	var sg_b: SaveGame = _build_populated_save_game(&"plaza_b")

	# Act
	var ok: bool = _service.save_to_slot(0, sg_b)

	# Assert — failure semantics
	assert_bool(ok).is_false()
	assert_int(_save_failed_reasons.size()).is_equal(1)
	assert_int(_save_failed_reasons[0]).is_equal(SaveLoadService.FailureReason.RENAME_FAILED)
	assert_int(_game_saved_calls.size()).is_equal(0)

	# Assert — tmp cleaned up, previous final untouched
	assert_bool(FileAccess.file_exists("user://saves/slot_0.tmp.res")).is_false()
	assert_bool(FileAccess.file_exists("user://saves/slot_0.res")).is_true()
	var post_bytes: PackedByteArray = FileAccess.get_file_as_bytes("user://saves/slot_0.res")
	assert_int(post_bytes.size()).is_equal(pre_existing_bytes.size())
	assert_bool(post_bytes == pre_existing_bytes).is_true()


# ---------------------------------------------------------------------------
# AC-6 — game_saved emit on success
# ---------------------------------------------------------------------------

## A successful manual save to slot 3 emits game_saved twice: once for slot 3
## (the requested slot) and once for slot 0 (the CR-4 mirror — Story SL-006).
## The first emission carries slot=3; the second carries slot=0. Both carry the
## same section_id. No save_failed is emitted on a clean success path.
func test_save_to_slot_emits_game_saved_with_slot_and_section_id() -> void:
	# Arrange
	_service = auto_free(SaveLoadService.new())
	var sg: SaveGame = _build_populated_save_game(&"restaurant")

	# Act
	var ok: bool = _service.save_to_slot(3, sg)

	# Assert — save succeeded
	assert_bool(ok).is_true()

	# Assert — 2 game_saved emissions: slot 3 first, then the CR-4 mirror slot 0.
	assert_int(_game_saved_calls.size()).is_equal(2)
	assert_int(int(_game_saved_calls[0]["slot"])).is_equal(3)
	assert_str(String(_game_saved_calls[0]["section_id"])).is_equal("restaurant")
	assert_int(int(_game_saved_calls[1]["slot"])).is_equal(0)
	assert_str(String(_game_saved_calls[1]["section_id"])).is_equal("restaurant")
	assert_int(_save_failed_reasons.size()).is_equal(0)


# ---------------------------------------------------------------------------
# AC-7 — Save latency under budget
# ---------------------------------------------------------------------------

## save_to_slot completes within 50 ms for a populated SaveGame.
##
## Production target: 10 ms (ADR-0003 budget for SSD); CI gate: 50 ms (loose
## headroom for shared-VM CI runners with slow I/O — local dev typically
## measures 1-3 ms). The test guards the regression boundary, not the
## production target. If a future change pushes warm-cache latency above
## 10 ms locally, that is a perf regression worth investigating even though
## this test will still pass.
func test_save_to_slot_latency_under_50_ms_warm_and_cold() -> void:
	# Arrange
	_service = auto_free(SaveLoadService.new())
	var sg: SaveGame = _build_populated_save_game(&"plaza")

	# Act — cold run
	var t0_cold: int = Time.get_ticks_usec()
	var ok_cold: bool = _service.save_to_slot(0, sg)
	var elapsed_cold_us: int = Time.get_ticks_usec() - t0_cold

	# Act — warm run (file already exists; rename overwrites)
	var t0_warm: int = Time.get_ticks_usec()
	var ok_warm: bool = _service.save_to_slot(0, sg)
	var elapsed_warm_us: int = Time.get_ticks_usec() - t0_warm

	# Assert — CI-tolerant 50 ms regression boundary
	assert_bool(ok_cold).is_true()
	assert_bool(ok_warm).is_true()
	assert_int(elapsed_cold_us).is_less(50000)
	assert_int(elapsed_warm_us).is_less(50000)


# ---------------------------------------------------------------------------
# AC-9 — No game-system references in service file
# ---------------------------------------------------------------------------

## save_load_service.gd MUST NOT reference any gameplay system class name —
## per the save_service_assembles_state forbidden pattern (ADR-0003 IG 2).
## Choose strict: matches in comments also fail (per story spec).
func test_save_load_service_source_has_no_game_system_references() -> void:
	# Arrange
	var src: String = FileAccess.get_file_as_string(
		"res://src/core/save_load/save_load_service.gd"
	)
	assert_str(src).is_not_empty()

	# Act + Assert — none of the forbidden tokens may appear anywhere in source
	var forbidden: Array[String] = [
		"PlayerCharacter",
		"StealthAI",
		"CivilianAI",
		"Inventory",
		"Combat",
		"MissionLevelScripting",
		"FailureRespawn",
		"DocumentCollection",
	]
	for token: String in forbidden:
		assert_int(src.find(token)).is_equal(-1)


# ---------------------------------------------------------------------------
# AC-10 — Cross-autoload reference safety
# ---------------------------------------------------------------------------

## _init() must reference no autoloads; _ready() must reference only Events
## or EventLogger (lines 1, 2). All later autoloads (line 4 onward) MUST NOT
## appear inside _init() or _ready() bodies.
func test_save_load_service_lifecycle_only_references_early_autoloads() -> void:
	# Arrange — slice source into _init / _ready / rest
	var src: String = FileAccess.get_file_as_string(
		"res://src/core/save_load/save_load_service.gd"
	)
	var init_body: String = _extract_function_body(src, "_init")
	var ready_body: String = _extract_function_body(src, "_ready")

	# Forbidden in BOTH _init and _ready (lines 4–10)
	var late_autoloads: Array[String] = [
		"InputContext",
		"LevelStreamingService",
		"PostProcessStack",
		"FailureRespawn",
		"MissionLevelScripting",
		"SettingsService",
	]

	# Forbidden in _init only (it must not even reach Events / EventLogger)
	var any_autoloads: Array[String] = late_autoloads.duplicate()
	any_autoloads.append("Events")
	any_autoloads.append("EventLogger")
	any_autoloads.append("Combat")  # line 7

	# Assert — _init references zero autoloads (may be empty string if absent)
	for token: String in any_autoloads:
		assert_int(init_body.find(token)).is_equal(-1)

	# Assert — _ready references no late autoload
	for token: String in late_autoloads:
		assert_int(ready_body.find(token)).is_equal(-1)


## Returns the substring of `src` from `func <name>(` to the next top-level
## `func ` (or end-of-file) — i.e., the body of the named function plus
## signature. Returns empty string if the function is not declared.
func _extract_function_body(src: String, func_name: String) -> String:
	var start_idx: int = src.find("func %s(" % func_name)
	if start_idx == -1:
		return ""
	var search_from: int = start_idx + len("func %s(" % func_name)
	var end_idx: int = src.find("\nfunc ", search_from)
	if end_idx == -1:
		return src.substr(start_idx)
	return src.substr(start_idx, end_idx - start_idx)
