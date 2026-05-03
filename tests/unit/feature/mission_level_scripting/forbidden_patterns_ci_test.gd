# tests/unit/feature/mission_level_scripting/forbidden_patterns_ci_test.gd
#
# MlsForbiddenPatternsCiTest — GdUnit4 test suite for Story MLS-002.
#
# PURPOSE
#   Enforces GDD CR-5 (FP-1, FP-2) and ADR-0007 (FP-8) forbidden-pattern fences
#   as CI-blocking assertions. Tests grep src/ for symbols that must never appear
#   in mission system source code.
#
# COVERED ACCEPTANCE CRITERIA (Story MLS-002)
#   AC-MLS-3.1 (FP-1): No waypoint/objective-marker/minimap-pin symbols in src/.
#     Forbidden: waypoint, objective_marker, minimap_pin, compass_marker, map_icon
#   AC-MLS-3.2 (FP-2): No HUD-banner/quest-update symbols in src/.
#     Forbidden: quest_updated, objective_complete_banner, hud_banner, notification_push
#   AC-MLS-3.3 (FP-8): _init() body of mission_level_scripting.gd contains no
#     Events.* references (ADR-0007 rule 4 — cross-autoload reference safety).
#     Absent _init() auto-passes.
#
# TEST FRAMEWORK
#   GdUnit4 — extends GdUnitTestSuite.
#
# DESIGN NOTES — comment stripping
#   All grep checks strip full-line comments (lines beginning with #) and inline
#   comments (everything after the first # on a code line) to avoid false positives
#   from doc comments that legitimately describe forbidden patterns.
#
# DESIGN NOTES — test file exclusion
#   The tests directory itself is excluded from searches. Each test lists the
#   exact set of directories scanned in the _SRC_DIR constant.

class_name MlsForbiddenPatternsCiTest
extends GdUnitTestSuite


# ── Constants ─────────────────────────────────────────────────────────────────

## AC-MLS-3.1 / AC-MLS-3.2 scope: the MLS source directory only.
## "waypoint" is a valid navigation concept in other systems (e.g.
## patrol_controller.gd in the SAI epic uses it for PathFollow3D waypoints).
## The forbidden-pattern fence targets the MLS system, not the entire codebase.
const _SRC_DIR: String = "res://src/gameplay/mission_level_scripting/"
const _MLS_GD_PATH: String = \
	"res://src/gameplay/mission_level_scripting/mission_level_scripting.gd"

## FP-1 symbols (GDD CR-5): waypoint / minimap / objective marker variants.
const _FP1_NEEDLES: Array[String] = [
	"waypoint",
	"objective_marker",
	"minimap_pin",
	"compass_marker",
	"map_icon",
]

## FP-2 symbols (GDD CR-5): HUD banner / quest notification variants.
const _FP2_NEEDLES: Array[String] = [
	"quest_updated",
	"objective_complete_banner",
	"hud_banner",
	"notification_push",
]


# ── Helpers ───────────────────────────────────────────────────────────────────

## Reads a res:// file and returns its contents, or an empty string if missing.
func _read_file(res_path: String) -> String:
	var file: FileAccess = FileAccess.open(res_path, FileAccess.READ)
	if file == null:
		return ""
	var contents: String = file.get_as_text()
	file.close()
	return contents


## Returns true when a single line of GDScript code (after stripping the comment
## portion) contains [param needle]. Comment lines (starting with #) and comment
## tails (after # on a code line) are excluded to prevent doc-comment false positives.
func _code_line_contains(line: String, needle: String) -> bool:
	var stripped: String = line.strip_edges()
	if stripped.begins_with("#"):
		return false
	var hash_idx: int = line.find("#")
	var code_part: String = line if hash_idx < 0 else line.substr(0, hash_idx)
	return code_part.to_lower().contains(needle.to_lower())


## Returns true when any code line in [param contents] contains [param needle].
func _source_contains(contents: String, needle: String) -> bool:
	for line: String in contents.split("\n"):
		if _code_line_contains(line, needle):
			return true
	return false


## Lists all .gd files recursively under [param res_dir].
## Returns an Array[String] of res:// paths.
func _list_gd_files_in(res_dir: String) -> Array[String]:
	var results: Array[String] = []
	var dir: DirAccess = DirAccess.open(res_dir)
	if dir == null:
		return results
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if entry != "." and entry != "..":
				results.append_array(_list_gd_files_in(res_dir.path_join(entry)))
		elif entry.ends_with(".gd"):
			results.append(res_dir.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	return results


## Scans all .gd files in [param base_dir] for any of [param needles].
## Returns a Dictionary mapping offending file paths to the matched needle.
func _grep_for_needles(base_dir: String, needles: Array[String]) -> Dictionary:
	var offenders: Dictionary = {}
	for path: String in _list_gd_files_in(base_dir):
		var contents: String = _read_file(path)
		if contents.is_empty():
			continue
		for needle: String in needles:
			if _source_contains(contents, needle):
				offenders[path] = needle
				break  # Report first match per file only.
	return offenders


# ── Tests ─────────────────────────────────────────────────────────────────────

## AC-MLS-3.1 (FP-1): src/ must contain zero references to waypoint,
## objective_marker, minimap_pin, compass_marker, or map_icon in code lines.
## These symbols violate GDD CR-5 (diegetic navigation pillar — no HUD markers).
func test_forbidden_patterns_no_waypoint_or_minimap_in_src() -> void:
	# Arrange + Act — grep src/ for all FP-1 needles.
	var offenders: Dictionary = _grep_for_needles(_SRC_DIR, _FP1_NEEDLES)

	# Assert — no offenders.
	assert_int(offenders.size()).override_failure_message(
		"AC-MLS-3.1 (FP-1): src/ must not contain waypoint/minimap/marker symbols in code. "
		+ "Offending files: %s" % str(offenders)
	).is_equal(0)


## AC-MLS-3.2 (FP-2): src/ must contain zero references to quest_updated,
## objective_complete_banner, hud_banner, or notification_push in code lines.
## These symbols violate GDD CR-5 (no quest-style HUD banners per period-authenticity pillar).
func test_forbidden_patterns_no_quest_banner_in_src() -> void:
	# Arrange + Act — grep src/ for all FP-2 needles.
	var offenders: Dictionary = _grep_for_needles(_SRC_DIR, _FP2_NEEDLES)

	# Assert — no offenders.
	assert_int(offenders.size()).override_failure_message(
		"AC-MLS-3.2 (FP-2): src/ must not contain HUD-banner/quest-notification symbols in code. "
		+ "Offending files: %s" % str(offenders)
	).is_equal(0)


## AC-MLS-3.3 (FP-8): The _init() function body of mission_level_scripting.gd
## must contain zero references to Events.* (ADR-0007 rule 4 — cross-autoload
## reference safety: _init() fires before sibling autoloads are guaranteed present).
## If _init() is absent from the file, this test auto-passes.
func test_forbidden_patterns_no_events_ref_in_mls_init_body() -> void:
	# Arrange — read source as text for static analysis.
	var source: String = _read_file(_MLS_GD_PATH)

	assert_str(source).override_failure_message(
		"AC-MLS-3.3 pre-condition: could not read mission_level_scripting.gd source."
	).is_not_empty()

	# Locate _init() function body (if present).
	var init_start: int = source.find("func _init(")
	if init_start == -1:
		# _init() absent — auto-pass: no cross-autoload references possible.
		assert_bool(true).override_failure_message(
			"AC-MLS-3.3: _init() is absent — compliant by omission (ADR-0007 IG 3)."
		).is_true()
		return

	# Scope to _init() body: from "func _init(" up to the next "func " or end of file.
	var next_func: int = source.find("\nfunc ", init_start + 1)
	var init_body: String = source.substr(
		init_start,
		(next_func - init_start) if next_func != -1 else source.length()
	)

	# Assert — no Events.* in _init() body code lines.
	var events_in_init: bool = false
	for line: String in init_body.split("\n"):
		if _code_line_contains(line, "Events."):
			events_in_init = true
			break

	assert_bool(events_in_init).override_failure_message(
		"AC-MLS-3.3 (FP-8): _init() must not reference Events.* — ADR-0007 rule 4 violation."
	).is_false()
