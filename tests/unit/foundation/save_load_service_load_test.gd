# tests/unit/foundation/save_load_service_load_test.gd
#
# Unit test suite — SaveLoadService.load_from_slot type-guard + version-mismatch
# refusal protocol.
#
# PURPOSE
#   Validates the production read code path defined in ADR-0003 IG 1 + IG 4.
#   The type-guard step (binary .res returns null silently on class mismatch)
#   is the most likely silent-corruption vector per ADR-0003 §Risks; this suite
#   covers all four failure paths plus the happy path round-trip.
#
# WHAT IS TESTED
#   AC-1: Happy path — load_from_slot returns the SaveGame.
#   AC-2: Missing file → save_failed(SLOT_NOT_FOUND), null return.
#   AC-3: Corrupt or non-SaveGame Resource → save_failed(CORRUPT_FILE), null.
#   AC-4: save_format_version mismatch (older OR future) → save_failed(VERSION_MISMATCH),
#         null return, slot file NOT deleted (refuse-load-on-mismatch).
#   AC-5: Successful load emits game_loaded(slot); returned save_format_version
#         matches FORMAT_VERSION.
#   AC-6: On-disk round-trip — Story 002 wrote, Story 003 reads, all 7
#         sub-resources field-equal.
#   AC-7: Load latency under 5 ms (CI gate; production target 2 ms).
#   AC-8: No cross-call state leak — second load returns disk truth, not
#         the previously-mutated instance.
#
# WHAT IS NOT TESTED HERE
#   - duplicate_deep state isolation — Story SL-004.
#   - Metadata sidecar slot_metadata() API — Story SL-005.
#   - 8-slot scheme + slot_exists helper — Story SL-006.
#
# GATE STATUS
#   Story SL-003 — Logic story type → BLOCKING gate.
#
# NAMING CONVENTION (per tests/README.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name SaveLoadServiceLoadTest
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Shared state + setup/teardown
# ---------------------------------------------------------------------------

var _service: SaveLoadService = null
var _save_failed_reasons: Array[int] = []
var _game_loaded_slots: Array[int] = []


func before_test() -> void:
	_save_failed_reasons.clear()
	_game_loaded_slots.clear()
	_clean_save_dir()
	Events.save_failed.connect(_on_save_failed)
	Events.game_loaded.connect(_on_game_loaded)


func after_test() -> void:
	if Events.save_failed.is_connected(_on_save_failed):
		Events.save_failed.disconnect(_on_save_failed)
	if Events.game_loaded.is_connected(_on_game_loaded):
		Events.game_loaded.disconnect(_on_game_loaded)
	_service = null
	_clean_save_dir()


func _on_save_failed(reason: int) -> void:
	_save_failed_reasons.append(reason)


func _on_game_loaded(slot: int) -> void:
	_game_loaded_slots.append(slot)


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


func _build_populated_save_game(section_id: StringName) -> SaveGame:
	var sg: SaveGame = SaveGame.new()
	sg.saved_at_iso8601 = "2026-04-30T14:32:15"
	sg.section_id = section_id
	sg.elapsed_seconds = 42.5
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
# AC-1 — Happy path read returns loaded SaveGame
# ---------------------------------------------------------------------------

## load_from_slot returns a non-null SaveGame for a valid slot file with the
## scalar fields preserved.
func test_load_from_slot_happy_path_returns_save_game() -> void:
	# Arrange — write via the production save path so the test exercises the
	# real on-disk format produced by Story 002.
	_service = auto_free(SaveLoadService.new())
	var sg: SaveGame = _build_populated_save_game(&"plaza")
	assert_bool(_service.save_to_slot(3, sg)).is_true()
	# Reset spy state — drop the bootstrap save's events.
	_save_failed_reasons.clear()
	_game_loaded_slots.clear()

	# Act
	var loaded: SaveGame = _service.load_from_slot(3)

	# Assert
	assert_object(loaded).is_not_null()
	assert_str(String(loaded.section_id)).is_equal("plaza")
	assert_float(loaded.elapsed_seconds).is_equal_approx(42.5, 0.001)
	assert_int(_game_loaded_slots.size()).is_equal(1)
	assert_int(_game_loaded_slots[0]).is_equal(3)
	assert_int(_save_failed_reasons.size()).is_equal(0)


# ---------------------------------------------------------------------------
# AC-2 — Missing file returns SLOT_NOT_FOUND
# ---------------------------------------------------------------------------

## When the slot file does not exist, load_from_slot returns null and emits
## save_failed(SLOT_NOT_FOUND). No game_loaded emit.
func test_load_from_slot_missing_file_emits_slot_not_found() -> void:
	# Arrange — clean dir; no slot file present.
	_service = auto_free(SaveLoadService.new())
	assert_bool(FileAccess.file_exists("user://saves/slot_5.res")).is_false()

	# Act
	var loaded: SaveGame = _service.load_from_slot(5)

	# Assert
	assert_object(loaded).is_null()
	assert_int(_save_failed_reasons.size()).is_equal(1)
	assert_int(_save_failed_reasons[0]).is_equal(SaveLoadService.FailureReason.SLOT_NOT_FOUND)
	assert_int(_game_loaded_slots.size()).is_equal(0)


# ---------------------------------------------------------------------------
# AC-3 — Corrupt or non-SaveGame Resource returns CORRUPT_FILE
# ---------------------------------------------------------------------------

## When the slot file contains corrupted bytes that ResourceLoader.load
## cannot parse, load_from_slot returns null and emits save_failed(CORRUPT_FILE).
## ResourceLoader.load logs an internal error to console — that is expected
## Godot behaviour and NOT a test failure.
func test_load_from_slot_corrupt_bytes_emits_corrupt_file() -> void:
	# Arrange — ensure save dir exists, then write garbage bytes to slot_3.res.
	DirAccess.make_dir_recursive_absolute(SaveLoadService.SAVE_DIR)
	var f: FileAccess = FileAccess.open("user://saves/slot_3.res", FileAccess.WRITE)
	assert_object(f).is_not_null()
	f.store_buffer(PackedByteArray([0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x00, 0x00, 0x00]))
	f.close()
	_service = auto_free(SaveLoadService.new())

	# Act
	var loaded: SaveGame = _service.load_from_slot(3)

	# Assert
	assert_object(loaded).is_null()
	assert_int(_save_failed_reasons.size()).is_equal(1)
	assert_int(_save_failed_reasons[0]).is_equal(SaveLoadService.FailureReason.CORRUPT_FILE)
	assert_int(_game_loaded_slots.size()).is_equal(0)
	# Refuse-load-on-corrupt does NOT delete the file — Menu System will mark
	# the slot as CORRUPT for the player (per ADR-0003 IG 9).
	assert_bool(FileAccess.file_exists("user://saves/slot_3.res")).is_true()


## When the slot file contains a valid Resource of a different class (not
## SaveGame), load_from_slot must catch the type mismatch via the `is SaveGame`
## guard and emit save_failed(CORRUPT_FILE).
func test_load_from_slot_wrong_class_emits_corrupt_file() -> void:
	# Arrange — write a non-SaveGame Resource at the slot path. We use a
	# simple top-level Resource subclass (PlayerState from SL-001) that is
	# clearly not a SaveGame and is class_name-registered.
	DirAccess.make_dir_recursive_absolute(SaveLoadService.SAVE_DIR)
	var foreign: PlayerState = PlayerState.new()
	foreign.health = 50
	var save_err: Error = ResourceSaver.save(
		foreign, "user://saves/slot_3.res", ResourceSaver.FLAG_COMPRESS
	)
	assert_int(save_err).is_equal(OK)
	_service = auto_free(SaveLoadService.new())

	# Act
	var loaded: SaveGame = _service.load_from_slot(3)

	# Assert — type-guard catches the substitution
	assert_object(loaded).is_null()
	assert_int(_save_failed_reasons.size()).is_equal(1)
	assert_int(_save_failed_reasons[0]).is_equal(SaveLoadService.FailureReason.CORRUPT_FILE)
	assert_int(_game_loaded_slots.size()).is_equal(0)


# ---------------------------------------------------------------------------
# AC-4 — Version mismatch (lower or higher) returns VERSION_MISMATCH
# ---------------------------------------------------------------------------

## When the saved save_format_version is LOWER than FORMAT_VERSION (a save
## from a prior build), load_from_slot refuses with VERSION_MISMATCH and
## leaves the file on disk for Menu System to display as CORRUPT.
func test_load_from_slot_older_version_emits_version_mismatch() -> void:
	# Arrange — construct a SaveGame with an older save_format_version, save
	# it, then attempt to load.
	_service = auto_free(SaveLoadService.new())
	var sg: SaveGame = _build_populated_save_game(&"plaza")
	sg.save_format_version = SaveGame.FORMAT_VERSION - 1  # Simulate older save.
	DirAccess.make_dir_recursive_absolute(SaveLoadService.SAVE_DIR)
	var save_err: Error = ResourceSaver.save(
		sg, "user://saves/slot_3.res", ResourceSaver.FLAG_COMPRESS
	)
	assert_int(save_err).is_equal(OK)

	# Act
	var loaded: SaveGame = _service.load_from_slot(3)

	# Assert
	assert_object(loaded).is_null()
	assert_int(_save_failed_reasons.size()).is_equal(1)
	assert_int(_save_failed_reasons[0]).is_equal(SaveLoadService.FailureReason.VERSION_MISMATCH)
	assert_int(_game_loaded_slots.size()).is_equal(0)
	# Refuse-load-on-mismatch does NOT delete the file (IG 9).
	assert_bool(FileAccess.file_exists("user://saves/slot_3.res")).is_true()


## When the saved save_format_version is HIGHER than FORMAT_VERSION (a save
## from a hypothetical future build), the same VERSION_MISMATCH path fires.
## Both directions of mismatch are refused.
func test_load_from_slot_newer_version_emits_version_mismatch() -> void:
	# Arrange
	_service = auto_free(SaveLoadService.new())
	var sg: SaveGame = _build_populated_save_game(&"plaza")
	sg.save_format_version = SaveGame.FORMAT_VERSION + 99  # Hypothetical future.
	DirAccess.make_dir_recursive_absolute(SaveLoadService.SAVE_DIR)
	var save_err: Error = ResourceSaver.save(
		sg, "user://saves/slot_3.res", ResourceSaver.FLAG_COMPRESS
	)
	assert_int(save_err).is_equal(OK)

	# Act
	var loaded: SaveGame = _service.load_from_slot(3)

	# Assert
	assert_object(loaded).is_null()
	assert_int(_save_failed_reasons.size()).is_equal(1)
	assert_int(_save_failed_reasons[0]).is_equal(SaveLoadService.FailureReason.VERSION_MISMATCH)
	assert_int(_game_loaded_slots.size()).is_equal(0)
	assert_bool(FileAccess.file_exists("user://saves/slot_3.res")).is_true()


# ---------------------------------------------------------------------------
# AC-5 — game_loaded signal payload + save_format_version on returned save
# ---------------------------------------------------------------------------

## A successful load emits game_loaded with the slot number, and the returned
## SaveGame's save_format_version equals the runtime FORMAT_VERSION sentinel.
func test_load_from_slot_success_emits_game_loaded_with_slot() -> void:
	# Arrange
	_service = auto_free(SaveLoadService.new())
	var sg: SaveGame = _build_populated_save_game(&"plaza")
	assert_bool(_service.save_to_slot(2, sg)).is_true()
	_save_failed_reasons.clear()
	_game_loaded_slots.clear()

	# Act
	var loaded: SaveGame = _service.load_from_slot(2)

	# Assert
	assert_object(loaded).is_not_null()
	assert_int(_game_loaded_slots.size()).is_equal(1)
	assert_int(_game_loaded_slots[0]).is_equal(2)
	assert_int(loaded.save_format_version).is_equal(SaveGame.FORMAT_VERSION)
	assert_int(_save_failed_reasons.size()).is_equal(0)


# ---------------------------------------------------------------------------
# AC-6 — On-disk round-trip integrity (write via Story 002, read via Story 003)
# ---------------------------------------------------------------------------

## A SaveGame written by save_to_slot and read back by load_from_slot is
## field-equal across every populated sub-resource. This is the on-disk
## counterpart to SL-001's in-memory round-trip — proves the full
## save→disk→load contract is preserved end-to-end.
func test_load_from_slot_round_trip_preserves_all_sub_resources() -> void:
	# Arrange — populate, save.
	_service = auto_free(SaveLoadService.new())
	var sg_original: SaveGame = _build_populated_save_game(&"plaza")
	assert_bool(_service.save_to_slot(3, sg_original)).is_true()
	_save_failed_reasons.clear()
	_game_loaded_slots.clear()

	# Act
	var loaded: SaveGame = _service.load_from_slot(3)

	# Assert — top-level
	assert_object(loaded).is_not_null()
	assert_str(String(loaded.section_id)).is_equal("plaza")
	assert_float(loaded.elapsed_seconds).is_equal_approx(42.5, 0.001)

	# Assert — PlayerState
	assert_that(loaded.player.position).is_equal(Vector3(1.0, 2.0, 3.0))
	assert_int(loaded.player.health).is_equal(75)

	# Assert — InventoryState (StringName Dict keys preserved)
	assert_int(loaded.inventory.ammo_magazine[&"silenced_p38"]).is_equal(7)
	assert_int(loaded.inventory.ammo_reserve[&"silenced_p38"]).is_equal(21)
	var ammo_keys: Array = loaded.inventory.ammo_magazine.keys()
	assert_int(typeof(ammo_keys[0])).is_equal(TYPE_STRING_NAME)

	# Assert — StealthAIState (nested GuardRecord round-trips)
	assert_bool(loaded.stealth_ai.guards.has(&"plaza_guard_01")).is_true()
	var loaded_guard: GuardRecord = loaded.stealth_ai.guards[&"plaza_guard_01"] as GuardRecord
	assert_object(loaded_guard).is_not_null()
	assert_int(loaded_guard.alert_state).is_equal(2)
	assert_int(loaded_guard.patrol_index).is_equal(3)
	assert_that(loaded_guard.current_position).is_equal(Vector3(10.0, 0.0, 5.0))

	# Assert — DocumentCollectionState
	assert_int(loaded.documents.collected.size()).is_equal(1)
	assert_str(String(loaded.documents.collected[0])).is_equal("doc_001")

	# Assert — MissionState
	assert_int(loaded.mission.objectives_completed.size()).is_equal(1)
	assert_str(String(loaded.mission.objectives_completed[0])).is_equal("obj_1")
	assert_bool(loaded.mission.fired_beats[&"beat_intro"]).is_true()

	# Assert — FailureRespawnState placeholder field
	assert_str(String(loaded.failure_respawn.last_section_id)).is_equal("plaza")


# ---------------------------------------------------------------------------
# AC-7 — Load latency under budget
# ---------------------------------------------------------------------------

## load_from_slot completes within 5 ms for a representative SaveGame.
## Production target per ADR-0003: 2 ms (SSD); CI gate: 5 ms (loose headroom
## for shared-VM CI runners). The third call is asserted (AC-7 spec: "test
## runs load three times, asserts third run ≤2 ms; CI threshold 5 ms").
func test_load_from_slot_latency_third_call_under_5_ms() -> void:
	# Arrange — write once, then load three times (warming the cache).
	_service = auto_free(SaveLoadService.new())
	var sg: SaveGame = _build_populated_save_game(&"plaza")
	assert_bool(_service.save_to_slot(0, sg)).is_true()

	# Two priming loads — exercise any cache paths that might be involved
	# despite CACHE_MODE_IGNORE (ResourceLoader still amortizes cold-disk I/O).
	var _warm1: SaveGame = _service.load_from_slot(0)
	var _warm2: SaveGame = _service.load_from_slot(0)

	# Act — third (measured) load.
	var t0: int = Time.get_ticks_usec()
	var loaded: SaveGame = _service.load_from_slot(0)
	var elapsed_us: int = Time.get_ticks_usec() - t0

	# Assert
	assert_object(loaded).is_not_null()
	assert_int(elapsed_us).is_less(5000)


# ---------------------------------------------------------------------------
# AC-8 — No cross-call state leak (CACHE_MODE_IGNORE returns disk truth)
# ---------------------------------------------------------------------------

## Calling load_from_slot twice returns instances whose state reflects on-disk
## truth — even if the first instance was mutated post-load. The CACHE_MODE_IGNORE
## flag in _load_resource forces a fresh disk read on every call. This is the
## structural defense against the state-leak risk that motivates Story SL-004's
## duplicate_deep discipline at the call site.
func test_load_from_slot_second_call_returns_fresh_disk_state() -> void:
	# Arrange — save A, load it, mutate the loaded instance.
	_service = auto_free(SaveLoadService.new())
	var sg_a: SaveGame = _build_populated_save_game(&"section_a")
	assert_bool(_service.save_to_slot(3, sg_a)).is_true()

	var loaded_a: SaveGame = _service.load_from_slot(3)
	assert_object(loaded_a).is_not_null()
	assert_str(String(loaded_a.section_id)).is_equal("section_a")
	loaded_a.section_id = &"mutated_in_memory"
	assert_str(String(loaded_a.section_id)).is_equal("mutated_in_memory")

	# Act — second load. CACHE_MODE_IGNORE in _load_resource forces a fresh
	# read from disk; the mutation to loaded_a must not leak through.
	var loaded_b: SaveGame = _service.load_from_slot(3)

	# Assert — loaded_b reflects on-disk truth, not the in-memory mutation.
	assert_object(loaded_b).is_not_null()
	assert_str(String(loaded_b.section_id)).is_equal("section_a")
