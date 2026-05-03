# tests/unit/foundation/post_process_stack/scaling_3d_scale_lint_test.gd
#
# Scaling3DScaleLintTest — GdUnit4 static analysis suite for Story PPS-006 AC-5.
#
# WHAT IS TESTED
#   AC-5: Zero occurrences of a direct `scaling_3d_scale =` property assignment
#         (write) in any GDScript file under src/, except in the explicitly
#         permitted files listed in _PERMITTED_FILES.
#
#         This enforces the GDD anti-pattern guard `direct_viewport_scaling_modification`
#         (GDD AC-21): only PostProcessStack owns the write; all other systems must
#         subscribe to Events.setting_changed ("graphics", "resolution_scale") and
#         let PostProcessStack apply the value.
#
# WHAT IS NOT TESTED HERE
#   - Read access (e.g. `var x = viewport.scaling_3d_scale`) — reads are permitted
#     and not flagged. The lint checks for the assignment operator pattern
#     `scaling_3d_scale =` (not followed by `=`), which captures writes only.
#   - Test files (tests/ directory) — excluded from the scan scope.
#
# PERMITTED FILE EXCEPTIONS
#   _PERMITTED_FILES lists paths that are allowed to write scaling_3d_scale.
#   As of PPS-006, only PostProcessStack is permitted. When Settings & Accessibility
#   ships (post-VS), add its path here.
#
# SCAN LOGIC
#   Detects: lines containing "scaling_3d_scale =" that do NOT also contain
#   "scaling_3d_scale ==" (equality comparison). Comment lines (stripped line
#   starts with "#") are skipped. Empty lines are skipped.
#
# GATE STATUS
#   Story PPS-006 | Logic type → BLOCKING gate (test-evidence requirement).
#   AC-5 lint failure blocks the story from Done.
#
# NAMING CONVENTION (per tests/README.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[system]_[scenario]_[expected_result]
#
# REFERENCES
#   Implements: Story PPS-006 AC-5 (GDD §AC-21 — direct_viewport_scaling_modification)
#   GDD: design/gdd/post-process-stack.md §Core Rule 6, §anti-pattern fences
#   Companion: glow_ban_lint_test.gd (same scan pattern for glow ban)

class_name Scaling3DScaleLintTest
extends GdUnitTestSuite

## Files in src/ that are explicitly permitted to write scaling_3d_scale.
## PostProcessStack is the sole write owner per PPS-006 AC-5 / GDD AC-21.
## When Settings & Accessibility ships, add its path here.
const _PERMITTED_FILES: Array[String] = [
	"res://src/core/rendering/post_process_stack.gd",
	# Settings & Accessibility files — none yet.
	# When SettingsService is implemented, add:
	#   "res://src/core/settings/settings_service.gd",
]


# ---------------------------------------------------------------------------
# AC-5: No direct scaling_3d_scale writes outside permitted files
# ---------------------------------------------------------------------------

## AC-5: Zero occurrences of `scaling_3d_scale =` (write assignment, not
## equality comparison) in any GDScript file under src/, except for the files
## in _PERMITTED_FILES.
##
## This is the CI lint gate for GDD anti-pattern direct_viewport_scaling_modification.
## Any violation means a system is bypassing PostProcessStack and writing the
## viewport scale directly — which breaks the architecture contract that
## PostProcessStack is the sole scaling_3d_scale write site.
func test_no_direct_scaling_3d_scale_writes_outside_permitted_files() -> void:
	# Arrange
	var violations: Array[String] = []
	_scan_directory("res://src", violations)

	# Assert
	assert_int(violations.size()).override_failure_message(
		"AC-5: 'scaling_3d_scale =' must not appear in src/ outside permitted files "
		+ "(PostProcessStack + Settings — see _PERMITTED_FILES). "
		+ "Violations:\n%s" % "\n".join(violations)
	).is_equal(0)


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

## Recursively walks [path], calling _scan_file() for each .gd file found
## that is NOT in _PERMITTED_FILES. Skips hidden directories (names beginning
## with ".").
##
## Uses DirAccess.open() — silently skips absent or inaccessible directories
## to avoid false failures on partial checkouts or empty projects.
func _scan_directory(path: String, violations: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		# Path does not exist or is not accessible — skip silently.
		return

	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		var full_path: String = path + "/" + name
		if dir.current_is_dir():
			# Skip hidden directories (e.g. .git, .godot).
			if not name.begins_with("."):
				_scan_directory(full_path, violations)
		elif name.ends_with(".gd"):
			if not _is_permitted(full_path):
				_scan_file(full_path, violations)
		name = dir.get_next()
	dir.list_dir_end()


## Returns true iff [path] is in the permitted files list.
## Permitted files are allowed to write scaling_3d_scale directly.
func _is_permitted(path: String) -> bool:
	return path in _PERMITTED_FILES


## Reads [file_path] line by line and appends to [violations] any non-comment
## line containing a `scaling_3d_scale =` write assignment (as distinct from
## an equality comparison `scaling_3d_scale ==`).
##
## Skipping logic:
##   • Lines whose stripped content begins with "#" — pure comments; skip.
##   • Empty lines — skip (no violation possible).
##   • Lines containing "scaling_3d_scale ==" — equality comparison, not a
##     write; skip. This prevents false positives on condition checks like
##     `if viewport.scaling_3d_scale == 1.0:`.
##
## Uses FileAccess.open() — silently skips unreadable files (permissions issue,
## not a lint violation).
func _scan_file(path: String, violations: Array[String]) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		# File unreadable — skip. Not a lint violation.
		return

	var line_num: int = 0
	while not file.eof_reached():
		line_num += 1
		var line: String = file.get_line()
		var stripped: String = line.strip_edges()

		# Skip pure comment lines.
		if stripped.begins_with("#"):
			continue

		# Skip empty lines.
		if stripped.is_empty():
			continue

		# Check for the forbidden write pattern, but NOT equality comparisons.
		# "scaling_3d_scale =" is the write; "scaling_3d_scale ==" is a comparison.
		if "scaling_3d_scale =" in stripped and "scaling_3d_scale ==" not in stripped:
			violations.append("%s:%d: %s" % [path, line_num, stripped])

	file.close()
