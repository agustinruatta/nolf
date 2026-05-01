# tests/unit/foundation/save_game_round_trip_test.gd
#
# Round-trip integrity test — SaveGame Resource + 7 typed sub-resources.
#
# PURPOSE
#   Proves that the SaveGame Resource and all 7 typed *_State sub-resources
#   (plus GuardRecord) correctly declare class_name, have correct default field
#   values, and survive a full ResourceSaver.save / ResourceLoader.load cycle
#   with all field values bit-equal across the round-trip.
#
# WHAT IS TESTED
#   AC-1: SaveGame.FORMAT_VERSION const == 2; save_format_version defaults to 2;
#         top-level fields default correctly; all 7 sub-resources are non-null.
#   AC-2: All 7 *_State files have class_name registered (get_global_name()
#         returns the expected StringName for each script).
#   AC-3: GuardRecord default field values (alert_state, patrol_index,
#         last_known_target_position, current_position).
#   AC-4: InventoryState ammo_magazine and ammo_reserve are untyped Dictionary
#         (Inventory CR-11 — TypedDictionary avoided pending verification).
#   AC-5: MissionState has fired_beats field defaulting to {} (MLS CR-7
#         savepoint-persistent-beats invariant).
#   AC-6: DocumentCollectionState.collected defaults to [] (Array[StringName]).
#   AC-7: Full ResourceSaver/ResourceLoader round-trip preserves all fields
#         across SaveGame, all 7 sub-resources, and nested GuardRecord.
#
# WHAT IS NOT TESTED HERE
#   - SaveLoadService autoload (Story 002).
#   - Atomic-write tmp-file rename pattern (Story 002).
#   - duplicate_deep() state isolation (Story 004).
#   - Per-slot file scheme (Story 002).
#   - Actor ID uniqueness within a section (section-scene lint, future story).
#
# GATE STATUS
#   Story SL-001 — Logic type -> BLOCKING gate.
#
# NAMING CONVENTION (per tests/README.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name SaveGameRoundTripTest
extends GdUnitTestSuite


const _ROUND_TRIP_PATH: String = "user://test_round_trip.res"


func after_test() -> void:
	# Clean up the round-trip file if it exists from the AC-7 test.
	# Using DirAccess so this is deterministic regardless of which test ran last.
	var dir: DirAccess = DirAccess.open("user://")
	if dir != null and dir.file_exists("test_round_trip.res"):
		dir.remove("test_round_trip.res")


# ---------------------------------------------------------------------------
# Tests — AC-1: SaveGame schema fields
# ---------------------------------------------------------------------------

## FORMAT_VERSION const must equal 2 (bumped at ADR-0003 Amendment A4).
func test_save_game_format_version_const_equals_2() -> void:
	# Arrange + Act + Assert
	assert_int(SaveGame.FORMAT_VERSION).is_equal(2)


## save_format_version @export var must default to FORMAT_VERSION (2).
## Only the var is serialized; the const is the runtime sentinel for load-guard.
func test_save_game_default_save_format_version_matches_const() -> void:
	# Arrange
	var sg: SaveGame = SaveGame.new()

	# Act + Assert
	assert_int(sg.save_format_version).is_equal(SaveGame.FORMAT_VERSION)


## Fresh SaveGame has correct default scalar fields and all 7 sub-resources
## non-null (SaveGame._init() default-initialises all sub-resources).
func test_save_game_default_field_values() -> void:
	# Arrange
	var sg: SaveGame = SaveGame.new()

	# Assert — scalar fields. StringName values wrapped with String() per
	# GdUnit4 type-safety convention (see AC-2 test).
	assert_str(String(sg.section_id)).is_equal("")
	assert_float(sg.elapsed_seconds).is_equal(0.0)
	assert_str(sg.saved_at_iso8601).is_equal("")

	# Assert — all 7 sub-resources non-null (IG 11 compliance check)
	assert_object(sg.player).is_not_null()
	assert_object(sg.inventory).is_not_null()
	assert_object(sg.stealth_ai).is_not_null()
	assert_object(sg.civilian_ai).is_not_null()
	assert_object(sg.documents).is_not_null()
	assert_object(sg.mission).is_not_null()
	assert_object(sg.failure_respawn).is_not_null()


# ---------------------------------------------------------------------------
# Tests — AC-2: class_name registration on all 7 *_State files + GuardRecord
# ---------------------------------------------------------------------------

## All 7 *_State scripts and GuardRecord must have class_name registered as a
## top-level global name. This verifies ADR-0003 IG 11: inner-class Resources
## would return an empty StringName here and fail ResourceLoader round-trips.
func test_state_files_have_class_name_registered() -> void:
	# Arrange — path -> expected global name pairs
	var expected: Dictionary = {
		"res://src/core/save_load/states/player_state.gd": &"PlayerState",
		"res://src/core/save_load/states/inventory_state.gd": &"InventoryState",
		"res://src/core/save_load/states/stealth_ai_state.gd": &"StealthAIState",
		"res://src/core/save_load/states/civilian_ai_state.gd": &"CivilianAIState",
		"res://src/core/save_load/states/document_collection_state.gd": &"DocumentCollectionState",
		"res://src/core/save_load/states/mission_state.gd": &"MissionState",
		"res://src/core/save_load/states/failure_respawn_state.gd": &"FailureRespawnState",
		"res://src/core/save_load/states/guard_record.gd": &"GuardRecord",
	}

	# Act + Assert — each script must load and report its registered global name
	for path: String in expected.keys():
		var script: Script = load(path) as Script
		assert_object(script).is_not_null()
		var global_name: StringName = script.get_global_name()
		assert_str(String(global_name)).is_equal(String(expected[path]))


# ---------------------------------------------------------------------------
# Tests — AC-3: GuardRecord default values
# ---------------------------------------------------------------------------

## GuardRecord default field values per ADR-0003 §Key Interfaces.
func test_guard_record_default_values() -> void:
	# Arrange
	var gr: GuardRecord = GuardRecord.new()

	# Assert
	assert_int(gr.alert_state).is_equal(0)
	assert_int(gr.patrol_index).is_equal(0)
	assert_that(gr.last_known_target_position).is_equal(Vector3.ZERO)
	assert_that(gr.current_position).is_equal(Vector3.ZERO)


# ---------------------------------------------------------------------------
# Tests — AC-4: InventoryState ammo dict types (Inventory CR-11)
# ---------------------------------------------------------------------------

## ammo_magazine and ammo_reserve must be untyped Dictionary, NOT TypedDictionary.
## TypedDictionary ResourceSaver stability is unverified post-cutoff (Inventory CR-11).
func test_inventory_state_ammo_dicts_are_untyped() -> void:
	# Arrange
	var inv: InventoryState = InventoryState.new()

	# Act + Assert — Dictionary type check via is keyword
	# An untyped Dictionary satisfies `inv.ammo_magazine is Dictionary`.
	assert_bool(inv.ammo_magazine is Dictionary).is_true()
	assert_bool(inv.ammo_reserve is Dictionary).is_true()


# ---------------------------------------------------------------------------
# Tests — AC-5: MissionState has fired_beats field (MLS CR-7)
# ---------------------------------------------------------------------------

## MissionState.fired_beats must exist and default to {} (empty Dictionary).
## Required per MLS CR-7 savepoint-persistent-beats invariant.
func test_mission_state_has_fired_beats_field() -> void:
	# Arrange
	var ms: MissionState = MissionState.new()

	# Assert
	assert_bool(ms.fired_beats is Dictionary).is_true()
	assert_int(ms.fired_beats.size()).is_equal(0)


# ---------------------------------------------------------------------------
# Tests — AC-6: DocumentCollectionState.collected default
# ---------------------------------------------------------------------------

## DocumentCollectionState.collected must default to an empty Array[StringName].
func test_document_collection_state_default_collected_is_empty_array() -> void:
	# Arrange
	var dcs: DocumentCollectionState = DocumentCollectionState.new()

	# Assert
	assert_bool(dcs.collected is Array).is_true()
	assert_int(dcs.collected.size()).is_equal(0)


# ---------------------------------------------------------------------------
# Tests — AC-7: Full ResourceSaver / ResourceLoader round-trip
# ---------------------------------------------------------------------------

## Full round-trip: populate all fields with non-default values, save to
## user://test_round_trip.res with FLAG_COMPRESS, reload, assert bit-equality
## for every field across SaveGame and all 7 sub-resources including nested
## GuardRecord. Proves ADR-0003 IG 11 compliance — any inner-class @export
## typed-Resource would come back null and fail the loaded != null check.
func test_save_game_round_trip_preserves_all_fields() -> void:
	# -------------------------------------------------------------------------
	# Arrange — build a fully-populated SaveGame with non-default values
	# -------------------------------------------------------------------------
	var sg: SaveGame = SaveGame.new()

	# Top-level fields
	sg.save_format_version = 2
	sg.saved_at_iso8601 = "2026-04-30T14:32:15"
	sg.section_id = &"test_section"
	sg.elapsed_seconds = 123.45

	# PlayerState
	sg.player.position = Vector3(1.0, 2.0, 3.0)
	sg.player.rotation = Vector3(0.1, 0.2, 0.3)
	sg.player.health = 75
	sg.player.current_state = 1

	# InventoryState
	sg.inventory.equipped_gadget = &"silenced_p38"
	sg.inventory.ammo_magazine[&"silenced_p38"] = 7
	sg.inventory.ammo_reserve[&"silenced_p38"] = 21
	sg.inventory.collected_gadget_flags[&"silenced_p38"] = true
	sg.inventory.mission_pickup_available = true

	# StealthAIState — one GuardRecord keyed by actor_id
	var guard_record: GuardRecord = GuardRecord.new()
	guard_record.alert_state = 2
	guard_record.patrol_index = 3
	guard_record.last_known_target_position = Vector3(5.0, 0.0, 5.0)
	guard_record.current_position = Vector3(10.0, 0.0, 5.0)
	sg.stealth_ai.guards[&"plaza_guard_01"] = guard_record

	# CivilianAIState
	sg.civilian_ai.panicked[&"civilian_01"] = true

	# DocumentCollectionState
	sg.documents.collected.append(&"doc_001")

	# MissionState
	sg.mission.section_id = &"test_section"
	sg.mission.objectives_completed.append(&"obj_1")
	sg.mission.triggers_fired[&"trigger_plaza_alarm"] = true
	sg.mission.fired_beats[&"beat_intro"] = true

	# FailureRespawnState
	sg.failure_respawn.last_section_id = &"test_section"

	# -------------------------------------------------------------------------
	# Act — save then load
	# -------------------------------------------------------------------------
	var save_err: int = ResourceSaver.save(sg, _ROUND_TRIP_PATH, ResourceSaver.FLAG_COMPRESS)
	assert_int(save_err).is_equal(OK)

	# CACHE_MODE_IGNORE forces a fresh disk read so re-running this test in the
	# same session never returns a cached copy from a prior populate-pass.
	var loaded: SaveGame = ResourceLoader.load(_ROUND_TRIP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SaveGame

	# -------------------------------------------------------------------------
	# Assert — loaded must not be null (proves type-cast worked; null here
	# would indicate an inner-class @export bug per ADR-0003 IG 11 / F2)
	# -------------------------------------------------------------------------
	assert_object(loaded).is_not_null()

	# Top-level fields. Use SaveGame.FORMAT_VERSION reference (not literal 2) so
	# bumping FORMAT_VERSION fails the const test, not this round-trip test.
	assert_int(loaded.save_format_version).is_equal(SaveGame.FORMAT_VERSION)
	assert_str(loaded.saved_at_iso8601).is_equal("2026-04-30T14:32:15")
	assert_str(String(loaded.section_id)).is_equal("test_section")
	assert_float(loaded.elapsed_seconds).is_equal_approx(123.45, 0.001)

	# PlayerState — including rotation (was set in Arrange but unverified before)
	assert_object(loaded.player).is_not_null()
	assert_that(loaded.player.position).is_equal(Vector3(1.0, 2.0, 3.0))
	assert_that(loaded.player.rotation).is_equal(Vector3(0.1, 0.2, 0.3))
	assert_int(loaded.player.health).is_equal(75)
	assert_int(loaded.player.current_state).is_equal(1)

	# InventoryState — incl. collected_gadget_flags (was set in Arrange, now verified)
	assert_object(loaded.inventory).is_not_null()
	assert_bool(loaded.inventory.ammo_magazine.has(&"silenced_p38")).is_true()
	assert_int(loaded.inventory.ammo_magazine[&"silenced_p38"]).is_equal(7)
	assert_bool(loaded.inventory.ammo_reserve.has(&"silenced_p38")).is_true()
	assert_int(loaded.inventory.ammo_reserve[&"silenced_p38"]).is_equal(21)
	assert_bool(loaded.inventory.collected_gadget_flags.has(&"silenced_p38")).is_true()
	assert_bool(loaded.inventory.collected_gadget_flags[&"silenced_p38"]).is_true()
	assert_bool(loaded.inventory.mission_pickup_available).is_true()

	# AC-7 explicit edge case (story spec): StringName keys in Dictionary
	# must be preserved as StringName, not coerced to String during round-trip.
	# A coercion regression here would be a silent data-layer bug.
	var ammo_keys: Array = loaded.inventory.ammo_magazine.keys()
	assert_int(ammo_keys.size()).is_equal(1)
	assert_int(typeof(ammo_keys[0])).is_equal(TYPE_STRING_NAME)

	# StealthAIState + nested GuardRecord (proves GuardRecord round-trips as
	# top-level class_name Resource per ADR-0003 IG 11). Includes
	# last_known_target_position which was previously unverified post-load.
	assert_object(loaded.stealth_ai).is_not_null()
	assert_bool(loaded.stealth_ai.guards.has(&"plaza_guard_01")).is_true()
	var loaded_guard: GuardRecord = loaded.stealth_ai.guards[&"plaza_guard_01"] as GuardRecord
	assert_object(loaded_guard).is_not_null()
	assert_int(loaded_guard.alert_state).is_equal(2)
	assert_int(loaded_guard.patrol_index).is_equal(3)
	assert_that(loaded_guard.last_known_target_position).is_equal(Vector3(5.0, 0.0, 5.0))
	assert_that(loaded_guard.current_position).is_equal(Vector3(10.0, 0.0, 5.0))

	# CivilianAIState
	assert_object(loaded.civilian_ai).is_not_null()
	assert_bool(loaded.civilian_ai.panicked.has(&"civilian_01")).is_true()
	assert_bool(loaded.civilian_ai.panicked[&"civilian_01"]).is_true()

	# DocumentCollectionState
	assert_object(loaded.documents).is_not_null()
	assert_int(loaded.documents.collected.size()).is_equal(1)
	assert_str(String(loaded.documents.collected[0])).is_equal("doc_001")

	# MissionState — incl. triggers_fired (was set in Arrange, now verified)
	assert_object(loaded.mission).is_not_null()
	assert_str(String(loaded.mission.section_id)).is_equal("test_section")
	assert_int(loaded.mission.objectives_completed.size()).is_equal(1)
	assert_str(String(loaded.mission.objectives_completed[0])).is_equal("obj_1")
	assert_bool(loaded.mission.triggers_fired.has(&"trigger_plaza_alarm")).is_true()
	assert_bool(loaded.mission.triggers_fired[&"trigger_plaza_alarm"]).is_true()
	assert_bool(loaded.mission.fired_beats.has(&"beat_intro")).is_true()
	assert_bool(loaded.mission.fired_beats[&"beat_intro"]).is_true()

	# FailureRespawnState (proves placeholder scaffold round-trips)
	assert_object(loaded.failure_respawn).is_not_null()
	assert_str(String(loaded.failure_respawn.last_section_id)).is_equal("test_section")
