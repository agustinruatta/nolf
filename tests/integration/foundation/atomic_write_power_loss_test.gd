# tests/integration/foundation/atomic_write_power_loss_test.gd
#
# Integration test suite — atomic-write power-loss simulation + autoload
# registration verification.
#
# PURPOSE
#   Validates two ADR-0003 / ADR-0007 invariants that need integration-level
#   coverage:
#     (a) project.godot [autoload] block has SaveLoad at line 3 with the exact
#         path required by ADR-0007 §Key Interfaces;
#     (b) a power-loss scenario (orphan tmp file at user://saves/slot_N.tmp.res)
#         does not destroy the previously-good slot_N.res, and a subsequent
#         save_to_slot cleanly overwrites the orphan tmp during its own atomic
#         write sequence.
#
# WHAT IS TESTED
#   AC-2: project.godot [autoload] block — line-3 SaveLoad entry verified
#         against ADR-0007 §Key Interfaces; ADR-0007 IG 2 (`*res://` prefix)
#         verified for all entries.
#   AC-8: Power-loss simulation — previous good save survives an orphan tmp;
#         subsequent save replaces orphan tmp without affecting unrelated slots.
#
# WHAT IS NOT TESTED HERE
#   - Atomic-write happy path / failure paths — see save_load_service_save_test.gd.
#   - Boot-time orphan tmp scanning (NOT in this story's scope).
#
# GATE STATUS
#   Story SL-002 — Logic story type → BLOCKING gate (this file covers the
#   integration-level ACs).
#
# NAMING CONVENTION (per tests/README.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name AtomicWritePowerLossTest
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------

func before_test() -> void:
	_clean_save_dir()


func after_test() -> void:
	_clean_save_dir()


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
	sg.section_id = section_id
	sg.elapsed_seconds = 1.0
	sg.player.position = Vector3(1.0, 2.0, 3.0)
	sg.player.health = 50
	return sg


# ---------------------------------------------------------------------------
# AC-2 — Autoload registration verified at line 3
# ---------------------------------------------------------------------------

## project.godot [autoload] block declares SaveLoad at line 3 with the exact
## ADR-0007 path. Lines 1, 2, 4 match Events, EventLogger, InputContext.
## Every entry uses the `*res://` scene-mode prefix (ADR-0007 IG 2).
func test_project_godot_autoload_line_3_is_save_load() -> void:
	# Arrange — read project.godot, extract [autoload] block lines in order
	var src: String = FileAccess.get_file_as_string("res://project.godot")
	assert_str(src).is_not_empty()

	var autoload_entries: Array[String] = _extract_autoload_entries(src)
	assert_int(autoload_entries.size()).is_greater_equal(4)

	# Assert — lines 1, 2, 3, 4 match the ADR-0007 canonical order
	assert_str(autoload_entries[0]).is_equal('Events="*res://src/core/signal_bus/events.gd"')
	assert_str(autoload_entries[1]).is_equal('EventLogger="*res://src/core/signal_bus/event_logger.gd"')
	assert_str(autoload_entries[2]).is_equal('SaveLoad="*res://src/core/save_load/save_load_service.gd"')
	assert_str(autoload_entries[3]).is_equal('InputContext="*res://src/core/ui/input_context.gd"')

	# Assert — every autoload entry has the `*res://` prefix (scene-mode)
	for entry: String in autoload_entries:
		assert_int(entry.find('"*res://')).is_greater_equal(0)


## Returns the [autoload] entries from a project.godot source string in
## declaration order, with surrounding whitespace and blank lines trimmed.
func _extract_autoload_entries(src: String) -> Array[String]:
	var out: Array[String] = []
	var section_start: int = src.find("[autoload]")
	if section_start == -1:
		return out
	var section_body_start: int = src.find("\n", section_start) + 1
	# Section ends at the next [section] header or end-of-file.
	var next_section: int = src.find("\n[", section_body_start)
	var section_end: int = next_section if next_section != -1 else len(src)
	var body: String = src.substr(section_body_start, section_end - section_body_start)
	for line: String in body.split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.is_empty():
			continue
		out.append(trimmed)
	return out


# ---------------------------------------------------------------------------
# AC-8 — Power-loss simulation: orphan tmp + previous good save intact
# ---------------------------------------------------------------------------

## Power-loss scenario: a previous good slot_3.res was written successfully;
## an orphan slot_3.tmp.res is left over from a process that died after
## ResourceSaver.save() but before DirAccess.rename(). The next save MUST:
##   (a) leave the previous good slot_3.res reloadable BEFORE the new save,
##   (b) cleanly produce a new slot_3.res reflecting the new payload AFTER
##       the new save,
##   (c) leave no orphan slot_3.tmp.res after the new save.
func test_atomic_write_power_loss_previous_save_survives_and_new_save_clears_orphan() -> void:
	# Arrange — write good save A to slot 3.
	var service: SaveLoadService = auto_free(SaveLoadService.new())
	var sg_a: SaveGame = _build_populated_save_game(&"section_a")
	assert_bool(service.save_to_slot(3, sg_a)).is_true()
	assert_bool(FileAccess.file_exists("user://saves/slot_3.res")).is_true()

	# Manually create an orphan tmp at slot_3.tmp.res — simulates a process
	# kill mid-write before rename. Contents are arbitrary; the file just has
	# to exist as a residual artefact on disk.
	var orphan: FileAccess = FileAccess.open(
		"user://saves/slot_3.tmp.res", FileAccess.WRITE
	)
	assert_object(orphan).is_not_null()
	orphan.store_buffer(PackedByteArray([0x00, 0x01, 0x02, 0x03]))
	orphan.close()
	assert_bool(FileAccess.file_exists("user://saves/slot_3.tmp.res")).is_true()

	# Act 1 — verify previous good save still loads while the orphan is present.
	var loaded_a: SaveGame = ResourceLoader.load(
		"user://saves/slot_3.res", "", ResourceLoader.CACHE_MODE_IGNORE
	) as SaveGame

	# Assert 1
	assert_object(loaded_a).is_not_null()
	assert_str(String(loaded_a.section_id)).is_equal("section_a")

	# Act 2 — run a new save with a different payload. The atomic-write
	# protocol writes to slot_3.tmp.res (overwriting the orphan), then
	# renames to slot_3.res.
	var sg_b: SaveGame = _build_populated_save_game(&"section_b")
	assert_bool(service.save_to_slot(3, sg_b)).is_true()

	# Assert 2 — new payload reflected; no orphan tmp remains
	var loaded_b: SaveGame = ResourceLoader.load(
		"user://saves/slot_3.res", "", ResourceLoader.CACHE_MODE_IGNORE
	) as SaveGame
	assert_object(loaded_b).is_not_null()
	assert_str(String(loaded_b.section_id)).is_equal("section_b")
	assert_bool(FileAccess.file_exists("user://saves/slot_3.tmp.res")).is_false()
