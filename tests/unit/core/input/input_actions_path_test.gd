# tests/unit/core/input/input_actions_path_test.gd
#
# AC-INPUT-9.1 — File path existence, class_name registration, no preload literals.
#
# PURPOSE
#   Proves that:
#   1. res://src/core/input/input_actions.gd exists and loads without error.
#   2. The script's class_name is registered as "InputActions".
#   3. No .gd file in src/ imports InputActions via a preload() literal path.
#      All consumers must use the class_name global instead.
#
# WHAT IS TESTED
#   1. load("res://src/core/input/input_actions.gd") returns a non-null Script.
#   2. script.get_global_name() == &"InputActions".
#   3. Zero .gd files in src/ contain preload("res://src/core/input/input_actions.gd")
#      or any preload(...input_actions...) pattern.
#
# WHAT IS NOT TESTED HERE
#   - Constant count/types (see input_actions_constants_test.gd).
#   - Binding catalog (see input_action_catalog_test.gd).
#   - The CI grep check (tools/ci/check_debug_action_gating.sh) for debug actions.
#
# GATE STATUS
#   Story IN-001 | AC-INPUT-9.1 [Config] BLOCKING.
#
# NAMING CONVENTION (per tests/README.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name InputActionsPathTest
extends GdUnitTestSuite


const INPUT_ACTIONS_PATH: String = "res://src/core/input/input_actions.gd"
const SRC_ROOT: String = "res://src"
const PRELOAD_PATTERN: String = "input_actions"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Recursively collect all .gd file paths under the given directory (res:// path).
func _collect_gd_files(dir_path: String, results: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var full_path: String = dir_path.path_join(entry)
		if dir.current_is_dir():
			_collect_gd_files(full_path, results)
		elif entry.ends_with(".gd"):
			results.append(full_path)
		entry = dir.get_next()
	dir.list_dir_end()


## Read file as string from res:// path. Returns empty string on failure.
func _read_file(path: String) -> String:
	# Convert res:// path to absolute path for FileAccess
	var absolute: String = ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute):
		return ""
	var content: String = FileAccess.get_file_as_string(absolute)
	return content


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

## The input_actions.gd file must load successfully as a Script resource.
func test_input_actions_file_loads_via_resource_path() -> void:
	# Arrange + Act
	var script: Script = load(INPUT_ACTIONS_PATH) as Script

	# Assert
	assert_object(script).is_not_null()


## The loaded script's class_name must be "InputActions".
func test_input_actions_class_name_registered() -> void:
	# Arrange
	var script: Script = load(INPUT_ACTIONS_PATH) as Script
	if script == null:
		assert_bool(false).override_failure_message("Script failed to load from: " + INPUT_ACTIONS_PATH).is_true()
		return

	# Act
	var global_name: StringName = script.get_global_name()

	# Assert
	assert_str(String(global_name)).is_equal("InputActions")


## No .gd file in src/ may import InputActions via a preload() literal path.
## All consumers must use the class_name global (InputActions.CONSTANT).
func test_input_actions_no_preload_literal_in_src() -> void:
	# Arrange — collect all .gd files under src/
	var gd_files: Array[String] = []
	_collect_gd_files(SRC_ROOT, gd_files)

	var violations: Array[String] = []

	# Act — scan each file for preload(...input_actions...) patterns
	for file_path: String in gd_files:
		var content: String = _read_file(file_path)
		if content.is_empty():
			continue

		# Check for any preload() call referencing input_actions
		var lines: PackedStringArray = content.split("\n")
		for i: int in range(lines.size()):
			var line: String = lines[i]
			# Match: preload( + any chars + "input_actions" + any chars + )
			if "preload(" in line and PRELOAD_PATTERN in line:
				violations.append("%s:%d: %s" % [file_path, i + 1, line.strip_edges()])

	# Assert
	if violations.size() > 0:
		assert_bool(false).override_failure_message(
			"preload() of input_actions found in src/ — use class_name global instead:\n  " +
			"\n  ".join(violations)
		).is_true()
	else:
		assert_bool(true).is_true()
