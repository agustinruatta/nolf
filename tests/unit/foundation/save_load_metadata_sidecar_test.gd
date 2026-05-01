# tests/unit/foundation/save_load_metadata_sidecar_test.gd
#
# Unit test suite — SaveLoadService metadata sidecar (slot_N_meta.cfg) and
# the slot_metadata() public API.
#
# PURPOSE
#   Validates TR-SAV-009 and ADR-0003 IG 8: every save slot has a paired
#   ConfigFile sidecar; slot_metadata() reads the sidecar without loading the
#   full .res; graceful fallback when the sidecar is absent; empty Dictionary
#   when both files are absent.
#
# WHAT IS TESTED
#   AC-1 : After save_to_slot(), slot_N_meta.cfg exists with all 6 fields.
#   AC-2 : slot_metadata() reads only the sidecar — .res NOT opened during the
#          call when sidecar is present (structural test via _load_resource seam).
#   AC-3 : Sidecar missing, .res present → fallback Dictionary with
#          saved_at_iso8601 extracted from .res; other fields at defaults.
#   AC-4 : Sidecar missing, .res corrupt/null → all-defaults Dictionary; no
#          throw.
#   AC-5 : Both files missing → empty Dictionary {}.
#   AC-6 : Sidecar write is step 6 (after rename, before game_saved emit);
#          partial-success: sidecar write fails but game_saved still emits.
#   AC-7 : saved_at_iso8601 is canonical UTC ISO 8601; section_display_name
#          follows "meta.section.<section_id>" key pattern.
#   AC-8 : Subsequent save overwrites sidecar with new metadata (not stale).
#
# GATE STATUS
#   Story SL-005 — Logic story type → BLOCKING gate.
#
# NAMING CONVENTION (per tests/README.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name SaveLoadMetadataSidecarTest
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Fault-injection subclasses
# ---------------------------------------------------------------------------

## Forces _write_sidecar to return ERR_FILE_CANT_WRITE so the partial-success
## path in save_to_slot (AC-6) can be tested without filesystem tricks.
class _SidecarFailingService extends SaveLoadService:
	func _write_sidecar(_cfg: ConfigFile, _path: String) -> Error:
		return ERR_FILE_CANT_WRITE


## Tracks whether _load_resource was called and on which paths.
## Used by AC-2 to verify that slot_metadata() does NOT read the .res when
## the sidecar is present.
class _LoadResTrackingService extends SaveLoadService:
	var load_resource_paths: Array[String] = []

	func _load_resource(path: String) -> Resource:
		load_resource_paths.append(path)
		return super._load_resource(path)


## Records the call sequence of seam methods + game_saved emit, so AC-6 step
## ordering (rename → write_sidecar → game_saved) can be asserted.
class _SequenceTrackingService extends SaveLoadService:
	var sequence: Array[String] = []

	func _rename_file(from_path: String, to_path: String) -> Error:
		sequence.append("rename")
		return super._rename_file(from_path, to_path)

	func _write_sidecar(cfg: ConfigFile, path: String) -> Error:
		sequence.append("write_sidecar")
		return super._write_sidecar(cfg, path)


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


## Builds a realistic SaveGame with known scalar fields for assertion.
func _build_save_game(p_section_id: StringName, p_timestamp: String, p_elapsed: float) -> SaveGame:
	var sg: SaveGame = SaveGame.new()
	sg.section_id = p_section_id
	sg.saved_at_iso8601 = p_timestamp
	sg.elapsed_seconds = p_elapsed
	sg.player.position = Vector3(1.0, 0.0, 3.0)
	sg.player.health = 80
	return sg


# ---------------------------------------------------------------------------
# AC-1 — Sidecar exists with all 6 fields after successful save
# ---------------------------------------------------------------------------

## After save_to_slot(N, sg), slot_N_meta.cfg exists and contains a [meta]
## section with all 6 documented fields, values matching the SaveGame.
func test_save_to_slot_creates_sidecar_with_all_six_fields() -> void:
	# Arrange
	_service = auto_free(SaveLoadService.new())
	var sg: SaveGame = _build_save_game(&"restaurant", "2026-04-30T14:30:00", 123.45)

	# Act
	var ok: bool = _service.save_to_slot(0, sg)

	# Assert — save succeeded and sidecar file exists
	assert_bool(ok).is_true()
	assert_bool(FileAccess.file_exists("user://saves/slot_0_meta.cfg")).is_true()

	# Assert — sidecar loads and has all 6 fields with expected values
	var cfg: ConfigFile = ConfigFile.new()
	assert_int(cfg.load("user://saves/slot_0_meta.cfg")).is_equal(OK)
	assert_str(cfg.get_value("meta", "section_id", "__missing__")).is_equal("restaurant")
	assert_str(cfg.get_value("meta", "section_display_name", "__missing__")).is_equal(
		"meta.section.restaurant"
	)
	assert_str(cfg.get_value("meta", "saved_at_iso8601", "__missing__")).is_equal(
		"2026-04-30T14:30:00"
	)
	assert_float(cfg.get_value("meta", "elapsed_seconds", -1.0)).is_equal_approx(123.45, 0.001)
	assert_str(cfg.get_value("meta", "screenshot_path", "__missing__")).is_equal("")
	assert_int(cfg.get_value("meta", "save_format_version", -1)).is_equal(SaveGame.FORMAT_VERSION)


# ---------------------------------------------------------------------------
# AC-2 — slot_metadata() reads sidecar only, NOT the .res
# ---------------------------------------------------------------------------

## When both sidecar and .res exist, slot_metadata() reads the sidecar via
## the fast path and does NOT invoke _load_resource (i.e., does not open .res).
## Instrumented via the _LoadResTrackingService subclass which records every
## _load_resource call.
func test_slot_metadata_with_sidecar_present_does_not_read_res() -> void:
	# Arrange — write a real save (creates both .res and sidecar).
	var bootstrap: SaveLoadService = auto_free(SaveLoadService.new())
	var sg: SaveGame = _build_save_game(&"plaza", "2026-05-01T09:00:00", 60.0)
	assert_bool(bootstrap.save_to_slot(0, sg)).is_true()

	# Switch to tracking service for the slot_metadata call.
	var tracker: _LoadResTrackingService = auto_free(_LoadResTrackingService.new())
	tracker.load_resource_paths.clear()

	# Act
	var meta: Dictionary = tracker.slot_metadata(0)

	# Assert — 6 fields returned
	assert_bool(meta.is_empty()).is_false()
	assert_str(meta["section_id"]).is_equal("plaza")
	assert_str(meta["saved_at_iso8601"]).is_equal("2026-05-01T09:00:00")
	assert_float(meta["elapsed_seconds"]).is_equal_approx(60.0, 0.001)

	# Assert — .res was NOT loaded during this call
	assert_int(tracker.load_resource_paths.size()).is_equal(0)


# ---------------------------------------------------------------------------
# AC-3 — Fallback Dictionary when sidecar missing but .res present
# ---------------------------------------------------------------------------

## GIVEN slot_3.res exists (with a known saved_at_iso8601) but slot_3_meta.cfg
## is absent, WHEN slot_metadata(3) is called, THEN a fallback Dictionary is
## returned with saved_at_iso8601 from the .res and defaults for other fields.
func test_slot_metadata_fallback_when_sidecar_missing_and_res_present() -> void:
	# Arrange — write .res via real save, then delete the sidecar manually.
	var bootstrap: SaveLoadService = auto_free(SaveLoadService.new())
	var sg: SaveGame = _build_save_game(&"plaza", "2026-04-29T10:00:00", 77.5)
	assert_bool(bootstrap.save_to_slot(3, sg)).is_true()
	assert_int(DirAccess.remove_absolute("user://saves/slot_3_meta.cfg")).is_equal(OK)
	assert_bool(FileAccess.file_exists("user://saves/slot_3_meta.cfg")).is_false()

	_service = auto_free(SaveLoadService.new())

	# Act
	var meta: Dictionary = _service.slot_metadata(3)

	# Assert — non-empty, saved_at_iso8601 extracted from .res
	assert_bool(meta.is_empty()).is_false()
	assert_str(meta["saved_at_iso8601"]).is_equal("2026-04-29T10:00:00")

	# Assert — other 5 fields at documented defaults
	assert_str(meta["section_id"]).is_equal("")
	assert_str(meta["section_display_name"]).is_equal("")
	assert_float(meta["elapsed_seconds"]).is_equal_approx(0.0, 0.001)
	assert_str(meta["screenshot_path"]).is_equal("")
	assert_int(meta["save_format_version"]).is_equal(SaveGame.FORMAT_VERSION)


# ---------------------------------------------------------------------------
# AC-4 — Corrupt/null .res with missing sidecar → all-defaults Dictionary
# ---------------------------------------------------------------------------

## GIVEN sidecar is absent AND .res contains corrupt bytes (ResourceLoader
## returns null), WHEN slot_metadata(3) is called, THEN a Dictionary with
## all empty/default values is returned; no throw.
func test_slot_metadata_corrupt_res_and_missing_sidecar_returns_all_defaults() -> void:
	# Arrange — write garbage bytes to slot_3.res; no sidecar.
	DirAccess.make_dir_recursive_absolute(SaveLoadService.SAVE_DIR)
	var f: FileAccess = FileAccess.open("user://saves/slot_3.res", FileAccess.WRITE)
	assert_object(f).is_not_null()
	f.store_buffer(PackedByteArray([0xDE, 0xAD, 0xBE, 0xEF, 0x00]))
	f.close()
	assert_bool(FileAccess.file_exists("user://saves/slot_3_meta.cfg")).is_false()

	_service = auto_free(SaveLoadService.new())

	# Act
	var meta: Dictionary = _service.slot_metadata(3)

	# Assert — non-empty but all defaults; no exception
	assert_bool(meta.is_empty()).is_false()
	assert_str(meta["saved_at_iso8601"]).is_equal("")
	assert_str(meta["section_id"]).is_equal("")
	assert_str(meta["section_display_name"]).is_equal("")
	assert_float(meta["elapsed_seconds"]).is_equal_approx(0.0, 0.001)
	assert_str(meta["screenshot_path"]).is_equal("")
	assert_int(meta["save_format_version"]).is_equal(SaveGame.FORMAT_VERSION)


# ---------------------------------------------------------------------------
# AC-5 — Both files missing → empty Dictionary
# ---------------------------------------------------------------------------

## GIVEN neither slot_5.res nor slot_5_meta.cfg exist, WHEN slot_metadata(5)
## is called, THEN an empty Dictionary is returned and is_empty() is true.
func test_slot_metadata_both_files_missing_returns_empty_dict() -> void:
	# Arrange — clean dir is set up in before_test; slot 5 has nothing.
	_service = auto_free(SaveLoadService.new())
	assert_bool(FileAccess.file_exists("user://saves/slot_5.res")).is_false()
	assert_bool(FileAccess.file_exists("user://saves/slot_5_meta.cfg")).is_false()

	# Act
	var meta: Dictionary = _service.slot_metadata(5)

	# Assert
	assert_bool(meta.is_empty()).is_true()


# ---------------------------------------------------------------------------
# AC-6 — Sidecar is step 6 (after rename, before emit); partial-success path
# ---------------------------------------------------------------------------

## GIVEN a service where _write_sidecar always fails, WHEN save_to_slot() runs,
## THEN: (a) the .res was committed (slot_N.res exists), (b) game_saved still
## emits (partial-success), (c) no save_failed emit, (d) slot_metadata()
## returns the AC-3 fallback (sidecar absent, .res present).
func test_save_to_slot_sidecar_write_failure_is_partial_success() -> void:
	# Arrange
	_service = auto_free(_SidecarFailingService.new())
	var sg: SaveGame = _build_save_game(&"plaza", "2026-05-01T12:00:00", 30.0)

	# Act
	var ok: bool = _service.save_to_slot(0, sg)

	# Assert — save_to_slot returns true (partial-success; .res committed)
	assert_bool(ok).is_true()

	# Assert — .res committed; sidecar absent (write was forced to fail)
	assert_bool(FileAccess.file_exists("user://saves/slot_0.res")).is_true()
	assert_bool(FileAccess.file_exists("user://saves/slot_0_meta.cfg")).is_false()

	# Assert — game_saved emitted exactly once; no save_failed
	assert_int(_game_saved_calls.size()).is_equal(1)
	assert_int(_save_failed_reasons.size()).is_equal(0)

	# Assert — slot_metadata() returns fallback (AC-3 path) because sidecar is absent
	var meta: Dictionary = _service.slot_metadata(0)
	assert_bool(meta.is_empty()).is_false()
	assert_str(meta["saved_at_iso8601"]).is_equal("2026-05-01T12:00:00")
	assert_str(meta["section_id"]).is_equal("")


# ---------------------------------------------------------------------------
# AC-7 — Field format: ISO 8601 and localization key pattern
# ---------------------------------------------------------------------------

## saved_at_iso8601 in the sidecar matches the canonical ISO 8601 pattern
## YYYY-MM-DDTHH:MM:SS; section_display_name follows "meta.section.<id>" prefix.
func test_save_to_slot_sidecar_field_formats_are_canonical() -> void:
	# Arrange — use a known timestamp string (populated by caller in production;
	# here we inject a known value for deterministic assertion).
	_service = auto_free(SaveLoadService.new())
	var sg: SaveGame = _build_save_game(&"restaurant", "2026-04-30T14:30:00", 99.0)

	# Act
	assert_bool(_service.save_to_slot(0, sg)).is_true()
	var meta: Dictionary = _service.slot_metadata(0)

	# Assert — ISO 8601 pattern: 19-char string matching YYYY-MM-DDTHH:MM:SS
	var ts: String = meta["saved_at_iso8601"]
	assert_int(ts.length()).is_equal(19)
	assert_str(ts.substr(4, 1)).is_equal("-")  # YYYY-
	assert_str(ts.substr(7, 1)).is_equal("-")  # MM-
	assert_str(ts.substr(10, 1)).is_equal("T") # DDT
	assert_str(ts.substr(13, 1)).is_equal(":") # HH:
	assert_str(ts.substr(16, 1)).is_equal(":") # MM:

	# Assert — localization key starts with "meta.section." prefix
	var display_name: String = meta["section_display_name"]
	assert_bool(display_name.begins_with("meta.section.")).is_true()
	assert_str(display_name).is_equal("meta.section.restaurant")

	# Assert — empty section_id produces valid (non-crashing) key suffix
	var sg_empty: SaveGame = _build_save_game(&"", "2026-04-30T00:00:00", 0.0)
	assert_bool(_service.save_to_slot(1, sg_empty)).is_true()
	var meta_empty: Dictionary = _service.slot_metadata(1)
	assert_str(meta_empty["section_display_name"]).is_equal("meta.section.")


# ---------------------------------------------------------------------------
# AC-8 — Subsequent save overwrites sidecar with new metadata
# ---------------------------------------------------------------------------

## GIVEN slot_3 was saved with section_id "plaza", WHEN save_to_slot(3, sg2)
## is called with section_id "restaurant", THEN slot_3_meta.cfg reflects sg2
## (NOT sg1). Sidecar is overwritten in lockstep with the .res.
func test_save_to_slot_subsequent_save_overwrites_sidecar() -> void:
	_service = auto_free(SaveLoadService.new())

	# Arrange — first save (sg1: plaza)
	var sg1: SaveGame = _build_save_game(&"plaza", "2026-04-30T10:00:00", 50.0)
	assert_bool(_service.save_to_slot(3, sg1)).is_true()
	var meta1: Dictionary = _service.slot_metadata(3)
	assert_str(meta1["section_id"]).is_equal("plaza")

	_game_saved_calls.clear()

	# Act — second save (sg2: restaurant)
	var sg2: SaveGame = _build_save_game(&"restaurant", "2026-04-30T12:00:00", 75.0)
	var ok: bool = _service.save_to_slot(3, sg2)

	# Assert — save succeeded
	assert_bool(ok).is_true()

	# Assert — sidecar now reflects sg2
	var meta2: Dictionary = _service.slot_metadata(3)
	assert_str(meta2["section_id"]).is_equal("restaurant")
	assert_str(meta2["section_display_name"]).is_equal("meta.section.restaurant")
	assert_str(meta2["saved_at_iso8601"]).is_equal("2026-04-30T12:00:00")
	assert_float(meta2["elapsed_seconds"]).is_equal_approx(75.0, 0.001)

	# Assert — game_saved emitted twice: once for slot 3, once for the CR-4 mirror
	# to slot 0. Both carry section_id "restaurant" (Story SL-006 CR-4 behavior).
	assert_int(_game_saved_calls.size()).is_equal(2)
	assert_str(String(_game_saved_calls[0]["section_id"])).is_equal("restaurant")
	assert_int(int(_game_saved_calls[0]["slot"])).is_equal(3)
	assert_str(String(_game_saved_calls[1]["section_id"])).is_equal("restaurant")
	assert_int(int(_game_saved_calls[1]["slot"])).is_equal(0)


# ---------------------------------------------------------------------------
# AC-6 (regression guard) — Step ordering: rename → write_sidecar → game_saved
# ---------------------------------------------------------------------------

## Closes qa-tester Gap 1 (advisory). AC-6 requires that the sidecar write
## happens AFTER the atomic rename and BEFORE the game_saved emit. A future
## refactor could re-order these without any other test failing — this test
## guards that contract explicitly.
func test_save_to_slot_emits_game_saved_after_sidecar_write_in_correct_order() -> void:
	# Arrange — sequence-tracking service records each seam call in order.
	var tracker: _SequenceTrackingService = auto_free(_SequenceTrackingService.new())
	# Local recorder for game_saved emit timing — records into the same sequence
	# so we observe rename / write_sidecar / game_saved as an ordered triple.
	var on_saved: Callable = func(_slot: int, _section_id: StringName) -> void:
		tracker.sequence.append("game_saved")
	Events.game_saved.connect(on_saved)
	var sg: SaveGame = _build_save_game(&"plaza", "2026-05-01T13:00:00", 12.5)

	# Act
	var ok: bool = tracker.save_to_slot(0, sg)

	# Cleanup the local listener regardless of pass/fail
	if Events.game_saved.is_connected(on_saved):
		Events.game_saved.disconnect(on_saved)

	# Assert — save succeeded and the three steps fired in the contracted order
	assert_bool(ok).is_true()
	assert_array(tracker.sequence).is_equal(["rename", "write_sidecar", "game_saved"])


# ---------------------------------------------------------------------------
# AC-1/AC-3 (regression guard) — Sidecar with no [meta] section returns defaults
# ---------------------------------------------------------------------------

## Closes qa-tester Gap 2 (advisory) in adjusted form. The original gap
## hypothesised "corrupt sidecar parse error → fall through to .res", but
## Godot 4.6's ConfigFile parser is highly permissive (accepts garbage bytes
## silently and returns OK with an empty config). The actual defensive layer
## is _meta_dict_from_cfg(): when the [meta] section is absent (or any key
## is missing), get_value() returns the typed default, so callers always see
## a 6-field shape. This test guards that contract — a non-`[meta]` sidecar
## must produce all-defaults rather than crashing or returning a half-shape.
func test_slot_metadata_with_sidecar_missing_meta_section_returns_defaults() -> void:
	# Arrange — write a syntactically-valid sidecar that lacks the [meta]
	# section. The fast path will load this successfully but get_value() must
	# fall back to defaults for each of the 6 fields.
	DirAccess.make_dir_recursive_absolute(SaveLoadService.SAVE_DIR)
	var meta_path: String = "user://saves/slot_2_meta.cfg"
	var bogus: ConfigFile = ConfigFile.new()
	bogus.set_value("other_section", "stray_key", "stray_value")
	assert_int(bogus.save(meta_path)).is_equal(OK)
	# Sanity — the file is loadable (fast path will be entered), it just has
	# no [meta] section.
	var probe: ConfigFile = ConfigFile.new()
	assert_int(probe.load(meta_path)).is_equal(OK)
	assert_bool(probe.has_section("meta")).is_false()

	_service = auto_free(SaveLoadService.new())

	# Act
	var meta: Dictionary = _service.slot_metadata(2)

	# Assert — non-empty 6-field Dictionary, all defaults applied
	assert_bool(meta.is_empty()).is_false()
	assert_str(meta["section_id"]).is_equal("")
	assert_str(meta["section_display_name"]).is_equal("")
	assert_str(meta["saved_at_iso8601"]).is_equal("")
	assert_float(meta["elapsed_seconds"]).is_equal_approx(0.0, 0.001)
	assert_str(meta["screenshot_path"]).is_equal("")
	assert_int(meta["save_format_version"]).is_equal(SaveGame.FORMAT_VERSION)
