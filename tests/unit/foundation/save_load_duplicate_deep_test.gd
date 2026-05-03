# tests/unit/foundation/save_load_duplicate_deep_test.gd
#
# Unit test suite — Resource.duplicate_deep() state-isolation discipline on
# the production SaveGame schema.
#
# PURPOSE
#   Validates that `original.duplicate_deep()` produces a fully isolated copy
#   of a populated SaveGame across all 7 sub-resources, and that mutations to
#   the copy do not propagate to the original. Sprint 01 G3 verified this on
#   a stub TestSaveGame; this suite extends the scope to the production
#   schema, including the godot-specialist 2026-04-22 §5 follow-up on
#   Dictionary[StringName, GuardRecord] (StealthAIState.guards).
#
# WHAT IS TESTED
#   AC-1: original != copy AND each of 7 sub-resources is a different instance.
#   AC-2: PlayerState.position mutation isolated.
#   AC-3: InventoryState ammo Dictionary[StringName, int] mutation isolated.
#   AC-4: StealthAIState.guards Dictionary[StringName, GuardRecord] mutation
#         isolated AND nested GuardRecord is a different instance.
#   AC-5: MissionState.fired_beats Dictionary[StringName, bool] mutation isolated.
#   AC-6: DocumentCollectionState.collected Array[StringName] mutation isolated.
#   AC-7: StringName keys remain interned-identical across duplicate_deep
#         (engine-level contract; documented expected behaviour).
#
# WHAT IS NOT TESTED HERE
#   - SaveLoadService.load_from_slot — Story SL-003.
#   - Static lint for forgotten_duplicate_deep_on_load — Story SL-009.
#   - Caller-site discipline at consumer epics — owned by Mission Scripting,
#     F&R, Menu System (each will call duplicate_deep at their own call sites).
#
# GATE STATUS
#   Story SL-004 — Logic story type → BLOCKING gate.
#
# NAMING CONVENTION (per tests/README.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name SaveLoadDuplicateDeepTest
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Fixture — populated SaveGame with all 7 sub-resources non-empty.
# ---------------------------------------------------------------------------

## Builds a SaveGame populated across every sub-resource with the values that
## the AC tests below mutate and assert against. Mirrors the fixture pattern
## from Story SL-001's round-trip test.
func _build_populated_save_game() -> SaveGame:
	var sg: SaveGame = SaveGame.new()
	sg.section_id = &"plaza"
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
	sg.civilian_ai.panicked[&"civilian_01"] = true
	sg.documents.collected.append(&"doc_001")
	sg.mission.section_id = &"plaza"
	sg.mission.objectives_completed.append(&"obj_1")
	sg.mission.fired_beats[&"beat_intro"] = true
	sg.failure_respawn.floor_applied_this_checkpoint = true
	return sg


# ---------------------------------------------------------------------------
# AC-1 — duplicate_deep produces fully isolated SaveGame instance
# ---------------------------------------------------------------------------

## After duplicate_deep, the SaveGame and all 7 sub-resources are different
## instances. This is the structural prerequisite for the per-field isolation
## tests below — if AC-1 fails, AC-2 through AC-6 are meaningless.
func test_duplicate_deep_produces_distinct_instances_for_all_sub_resources() -> void:
	# Arrange
	var original: SaveGame = _build_populated_save_game()

	# Act
	var copy: SaveGame = original.duplicate_deep() as SaveGame

	# Assert — top-level
	assert_object(copy).is_not_null()
	assert_bool(copy == original).is_false()  # Different Resource instances.

	# Assert — each of the 7 sub-resources is a different instance
	assert_bool(copy.player == original.player).is_false()
	assert_bool(copy.inventory == original.inventory).is_false()
	assert_bool(copy.stealth_ai == original.stealth_ai).is_false()
	assert_bool(copy.civilian_ai == original.civilian_ai).is_false()
	assert_bool(copy.documents == original.documents).is_false()
	assert_bool(copy.mission == original.mission).is_false()
	assert_bool(copy.failure_respawn == original.failure_respawn).is_false()


# ---------------------------------------------------------------------------
# AC-2 — Player position mutation isolated
# ---------------------------------------------------------------------------

## Mutating copy.player.position must not affect original.player.position.
## Vector3 is a value type so this is partly a baseline check, but it also
## confirms PlayerState itself was deep-copied (not just aliased).
func test_duplicate_deep_player_position_mutation_isolated() -> void:
	# Arrange
	var original: SaveGame = _build_populated_save_game()
	var copy: SaveGame = original.duplicate_deep() as SaveGame

	# Act
	copy.player.position = Vector3(99.0, 99.0, 99.0)

	# Assert
	assert_that(original.player.position).is_equal(Vector3(1.0, 2.0, 3.0))
	assert_that(copy.player.position).is_equal(Vector3(99.0, 99.0, 99.0))


# ---------------------------------------------------------------------------
# AC-3 — Ammo Dictionary[StringName, int] mutation isolated
# ---------------------------------------------------------------------------

## Mutating a value in the copy's ammo_magazine Dictionary must not propagate
## to the original. Extends Sprint 01 G3 (which used a stub TestSaveGame) to
## the production InventoryState schema.
func test_duplicate_deep_inventory_ammo_dictionary_mutation_isolated() -> void:
	# Arrange
	var original: SaveGame = _build_populated_save_game()
	var copy: SaveGame = original.duplicate_deep() as SaveGame

	# Act
	copy.inventory.ammo_magazine[&"silenced_p38"] = 999

	# Assert
	assert_int(original.inventory.ammo_magazine[&"silenced_p38"]).is_equal(7)
	assert_int(copy.inventory.ammo_magazine[&"silenced_p38"]).is_equal(999)


# ---------------------------------------------------------------------------
# AC-4 — Guard alert_state Dictionary[StringName, GuardRecord] isolated
# ---------------------------------------------------------------------------

## The load-bearing test for the production schema's nested-Resource Dictionary
## shape. godot-specialist 2026-04-22 §5 explicitly called this out as needing
## extended-scope verification beyond Sprint 01 G3's stub. If this fails,
## ADR-0003 G3 must re-open.
##
## Verifies BOTH that:
##   (a) the GuardRecord values in the Dictionary are themselves deep-copied
##       (not just the Dictionary container), AND
##   (b) mutations to copy.guard.alert_state do not leak into original.
func test_duplicate_deep_guard_record_in_dictionary_mutation_isolated() -> void:
	# Arrange
	var original: SaveGame = _build_populated_save_game()
	var copy: SaveGame = original.duplicate_deep() as SaveGame

	# Confirm the GuardRecord values are different Resource instances.
	var orig_guard: GuardRecord = original.stealth_ai.guards[&"plaza_guard_01"] as GuardRecord
	var copy_guard: GuardRecord = copy.stealth_ai.guards[&"plaza_guard_01"] as GuardRecord
	assert_object(orig_guard).is_not_null()
	assert_object(copy_guard).is_not_null()
	assert_bool(orig_guard == copy_guard).is_false()  # Different instances.

	# Act
	copy_guard.alert_state = 99

	# Assert — original guard unchanged
	assert_int(orig_guard.alert_state).is_equal(2)
	assert_int(copy_guard.alert_state).is_equal(99)


# ---------------------------------------------------------------------------
# AC-5 — fired_beats Dictionary[StringName, bool] mutation isolated
# ---------------------------------------------------------------------------

## Mutating copy.mission.fired_beats must not propagate to original.
## Confirms ADR-0003 A4 amendment field's deep-copy behaviour matches the
## stub TestSaveGame's analogue from Sprint 01 G3.
func test_duplicate_deep_mission_fired_beats_mutation_isolated() -> void:
	# Arrange
	var original: SaveGame = _build_populated_save_game()
	var copy: SaveGame = original.duplicate_deep() as SaveGame

	# Act
	copy.mission.fired_beats[&"beat_intro"] = false

	# Assert
	assert_bool(original.mission.fired_beats[&"beat_intro"]).is_true()
	assert_bool(copy.mission.fired_beats[&"beat_intro"]).is_false()


# ---------------------------------------------------------------------------
# AC-6 — Documents Array[StringName] mutation isolated
# ---------------------------------------------------------------------------

## Appending to copy.documents.collected must not affect original.documents.collected.
## Verifies typed-Array deep-copy on the production schema.
func test_duplicate_deep_documents_collected_array_mutation_isolated() -> void:
	# Arrange
	var original: SaveGame = _build_populated_save_game()
	var copy: SaveGame = original.duplicate_deep() as SaveGame

	# Act
	copy.documents.collected.append(&"doc_002")

	# Assert
	assert_int(original.documents.collected.size()).is_equal(1)
	assert_str(String(original.documents.collected[0])).is_equal("doc_001")
	assert_bool(original.documents.collected.has(&"doc_002")).is_false()
	assert_int(copy.documents.collected.size()).is_equal(2)
	assert_bool(copy.documents.collected.has(&"doc_002")).is_true()


# ---------------------------------------------------------------------------
# AC-7 — StringName keys remain interned-identical across duplicate_deep
# ---------------------------------------------------------------------------

## StringName is globally interned by Godot. duplicate_deep deep-copies
## values but does NOT need to re-intern keys — both Dictionaries reference
## the same interned StringName entry. This test documents the expected
## engine behaviour so future readers do not assume key-identity drift on
## deep-copy is a bug.
func test_duplicate_deep_preserves_string_name_key_interning() -> void:
	# Arrange
	var original: SaveGame = _build_populated_save_game()
	var copy: SaveGame = original.duplicate_deep() as SaveGame

	# Act
	var orig_key: StringName = original.stealth_ai.guards.keys()[0] as StringName
	var copy_key: StringName = copy.stealth_ai.guards.keys()[0] as StringName

	# Assert — keys equal AND hash to the same value (interning preserved)
	assert_bool(orig_key == copy_key).is_true()
	assert_int(orig_key.hash()).is_equal(copy_key.hash())
	# Both are typed StringName, not String — confirms no coercion happened.
	assert_int(typeof(orig_key)).is_equal(TYPE_STRING_NAME)
	assert_int(typeof(copy_key)).is_equal(TYPE_STRING_NAME)
