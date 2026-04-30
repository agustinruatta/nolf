# prototypes/verification-spike/save_format_check.gd
#
# ADR-0003 Save Format Contract — verification script.
#
# Closes ADR-0003 verification gates:
#   G1: ResourceSaver.save(save, path, ResourceSaver.FLAG_COMPRESS) on a
#       binary .res returns OK in Godot 4.6 editor.
#   G2: DirAccess.rename(tmp, final) is the correct atomic-rename API in 4.6.
#   G3: Resource.duplicate_deep() (Godot 4.5+) on a nested typed-Resource
#       SaveGame produces a fully isolated copy.
#
# HOW TO RUN
#   From project root:
#     godot --headless --script res://prototypes/verification-spike/save_format_check.gd
#
#   Or from the Godot editor: open File → Run, navigate to this file.
#   (Headless CLI is preferred — no editor noise, clean stdout.)
#
# OUTPUT
#   Prints per-gate PASS/FAIL plus a summary line. Exits with code 0 on full
#   PASS, code 1 on any gate failure. Cleans up temp files in user://saves/
#   regardless of outcome.
#
# NOTES
#   - Runs as `extends SceneTree` so it does not require a main scene and
#     does not boot the project's autoload chain (intentional — gate is
#     about file I/O API correctness, not autoload behavior).
#   - User-side directory `user://` resolves to:
#       Linux:    ~/.local/share/godot/app_userdata/The Paris Affair/
#       Windows:  %APPDATA%/Godot/app_userdata/The Paris Affair/
#     The script creates and cleans up `user://saves/spike_test_*` files.

extends SceneTree

const SAVE_DIR: String = "user://saves/"
# Tmp path MUST end in `.res` — ResourceSaver picks format from the extension,
# and `.res.tmp` returns ERR_FILE_UNRECOGNIZED. Suffix the basename with `.tmp`
# to keep tmp files distinguishable. This is a finding — ADR-0003's §Architecture
# diagram shows `slot_N.res.tmp` which is wrong; ADR needs amendment.
const TMP_PATH: String  = "user://saves/spike_test.tmp.res"
const FINAL_PATH: String = "user://saves/spike_test.res"

var _all_passed: bool = true


func _initialize() -> void:
	print()
	print("=== ADR-0003 Save Format Contract — Verification ===")
	print("Engine version (runtime): %s" % Engine.get_version_info().string)
	print("Date: %s" % Time.get_datetime_string_from_system())
	print()

	_ensure_save_dir()
	_cleanup()  # in case a prior failed run left artifacts

	_run_gate_1()
	_run_gate_2()
	_run_gate_3()

	_cleanup()

	print()
	if _all_passed:
		print("=== Result: PASS — all 3 gates closed ===")
		quit(0)
	else:
		print("=== Result: FAIL — see gate-level output above ===")
		quit(1)


# ─── Gate 1 ────────────────────────────────────────────────────────────
# ResourceSaver.save(save, path, ResourceSaver.FLAG_COMPRESS) returns OK.
func _run_gate_1() -> void:
	print("[Gate 1] ResourceSaver.save(... FLAG_COMPRESS)")

	var save := _build_test_save()
	var err := ResourceSaver.save(save, TMP_PATH, ResourceSaver.FLAG_COMPRESS)

	if err != OK:
		_fail("Gate 1", "ResourceSaver.save returned %d (expected OK = 0)" % err)
		return

	if not FileAccess.file_exists(TMP_PATH):
		_fail("Gate 1", "Save returned OK but file does not exist at %s" % TMP_PATH)
		return

	# Round-trip: load it back and confirm fields survived.
	var loaded := ResourceLoader.load(TMP_PATH) as TestSaveGame
	if loaded == null:
		_fail("Gate 1", "ResourceLoader.load returned null for %s" % TMP_PATH)
		return

	if loaded.save_format_version != save.save_format_version:
		_fail("Gate 1", "Round-trip mismatch: save_format_version was %d, loaded %d" % [save.save_format_version, loaded.save_format_version])
		return

	if loaded.section_id != save.section_id:
		_fail("Gate 1", "Round-trip mismatch: section_id was %s, loaded %s" % [save.section_id, loaded.section_id])
		return

	if loaded.sub_state == null:
		_fail("Gate 1", "Round-trip mismatch: sub_state nested Resource is null after load")
		return

	if loaded.sub_state.ammo_magazine.get(&"silenced_pistol", -1) != 7:
		_fail("Gate 1", "Round-trip mismatch: nested Dictionary[StringName, int] entry missing or wrong (expected 7, got %s)" % str(loaded.sub_state.ammo_magazine.get(&"silenced_pistol", -1)))
		return

	if loaded.sub_state.fired_beats.get(&"intro_beat_1", false) != true:
		_fail("Gate 1", "Round-trip mismatch: nested Dictionary[StringName, bool] entry missing or wrong")
		return

	print("  PASS — file written + round-trip data integrity confirmed")


# ─── Gate 2 ────────────────────────────────────────────────────────────
# DirAccess.rename(tmp, final) is the correct atomic-rename API.
func _run_gate_2() -> void:
	print("[Gate 2] DirAccess.rename(tmp, final)")

	if not FileAccess.file_exists(TMP_PATH):
		_fail("Gate 2", "Pre-condition failed: tmp file from Gate 1 does not exist")
		return

	var dir := DirAccess.open(SAVE_DIR)
	if dir == null:
		_fail("Gate 2", "DirAccess.open(%s) returned null (err %d)" % [SAVE_DIR, DirAccess.get_open_error()])
		return

	# DirAccess.rename takes paths (relative to the dir's base, but absolute
	# globalised paths work too in 4.x). Use absolute user:// paths for clarity.
	var err := dir.rename(TMP_PATH, FINAL_PATH)
	if err != OK:
		_fail("Gate 2", "DirAccess.rename returned %d (expected OK = 0)" % err)
		return

	if FileAccess.file_exists(TMP_PATH):
		_fail("Gate 2", "After rename, source file still exists at %s — rename was not atomic move" % TMP_PATH)
		return

	if not FileAccess.file_exists(FINAL_PATH):
		_fail("Gate 2", "After rename, destination file does not exist at %s" % FINAL_PATH)
		return

	# Confirm the renamed file is still loadable (atomic move preserved bytes).
	var loaded := ResourceLoader.load(FINAL_PATH) as TestSaveGame
	if loaded == null:
		_fail("Gate 2", "Renamed file no longer loads as TestSaveGame")
		return

	print("  PASS — rename moved tmp → final, source removed, destination loadable")


# ─── Gate 3 ────────────────────────────────────────────────────────────
# Resource.duplicate_deep() on a nested SaveGame produces an isolated copy.
func _run_gate_3() -> void:
	print("[Gate 3] Resource.duplicate_deep() isolation")

	var original := _build_test_save()

	# duplicate_deep is the 4.5+ API for full nested Resource isolation.
	# duplicate(true) (the 4.x predecessor) duplicates Resource sub-fields
	# but leaves Dictionary/Array contents shared — this is exactly the
	# trap ADR-0003 needs to verify is closed.
	var copy: TestSaveGame = null
	if not original.has_method("duplicate_deep"):
		_fail("Gate 3", "Resource.duplicate_deep() not available on this engine build (expected Godot 4.5+)")
		return

	copy = original.duplicate_deep() as TestSaveGame
	if copy == null:
		_fail("Gate 3", "duplicate_deep() returned null or wrong type")
		return

	# Mutate the copy's nested Dictionary entry; original must not change.
	copy.sub_state.ammo_magazine[&"silenced_pistol"] = 999
	copy.sub_state.fired_beats[&"intro_beat_1"] = false

	if original.sub_state.ammo_magazine.get(&"silenced_pistol", -1) != 7:
		_fail("Gate 3", "Mutating copy's nested Dictionary leaked into original (got %s, expected 7) — duplicate_deep did NOT deep-copy" % str(original.sub_state.ammo_magazine.get(&"silenced_pistol", -1)))
		return

	if original.sub_state.fired_beats.get(&"intro_beat_1", false) != true:
		_fail("Gate 3", "Mutating copy's nested fired_beats leaked into original — duplicate_deep did NOT deep-copy")
		return

	# Verify the sub_state Resource itself is a separate instance.
	if copy.sub_state == original.sub_state:
		_fail("Gate 3", "copy.sub_state is the same instance as original.sub_state — duplicate_deep did NOT deep-copy nested Resource")
		return

	print("  PASS — nested Dictionary mutations on copy do not leak to original")


# ─── Helpers ───────────────────────────────────────────────────────────

func _build_test_save() -> TestSaveGame:
	var save := TestSaveGame.new()
	save.save_format_version = 2
	save.saved_at_iso8601 = Time.get_datetime_string_from_system()
	save.section_id = &"spike_section_test"
	save.elapsed_seconds = 123.456

	var sub := TestSubState.new()
	sub.actor_id = &"eve_sterling"
	sub.ammo_magazine = {&"silenced_pistol": 7, &"dart_gun": 4}
	sub.fired_beats = {&"intro_beat_1": true, &"intro_beat_2": false}
	save.sub_state = sub

	return save


func _ensure_save_dir() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		# user:// is created by the engine on first access — should never be null,
		# but guard anyway.
		push_warning("DirAccess.open('user://') returned null at startup")
		return
	if not dir.dir_exists("saves"):
		var err := dir.make_dir_recursive("saves")
		if err != OK:
			push_warning("Could not create user://saves/ (err %d)" % err)


func _cleanup() -> void:
	for path in [TMP_PATH, FINAL_PATH]:
		if FileAccess.file_exists(path):
			var err := DirAccess.remove_absolute(path)
			if err != OK:
				push_warning("Cleanup: could not remove %s (err %d)" % [path, err])


func _fail(gate: String, msg: String) -> void:
	_all_passed = false
	print("  FAIL — %s" % msg)
