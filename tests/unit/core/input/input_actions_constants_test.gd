# tests/unit/core/input/input_actions_constants_test.gd
#
# AC-INPUT-1.3 — InputActions constant count, types, uniqueness, and InputMap presence.
#
# PURPOSE
#   Proves the InputActions static class declares exactly 36 StringName constants
#   (33 gameplay/UI + 3 debug), all values are StringName type, all values are
#   unique, and all 33 gameplay/UI values satisfy InputMap.has_action().
#
# WHAT IS TESTED
#   1. Script declares exactly 36 constants.
#   2. Every constant value is TYPE_STRING_NAME.
#   3. No two constants share the same StringName value.
#   4. Every gameplay/UI constant (non-debug) satisfies InputMap.has_action().
#   5. Debug constants do NOT satisfy InputMap.has_action() in non-debug builds.
#
# WHAT IS NOT TESTED HERE
#   - Catalog binding integrity (see input_action_catalog_test.gd).
#   - File path / class_name registration (see input_actions_path_test.gd).
#
# GATE STATUS
#   Story IN-001 | AC-INPUT-1.3 [Logic] BLOCKING.
#
# NAMING CONVENTION (per tests/README.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name InputActionsConstantsTest
extends GdUnitTestSuite


const EXPECTED_CONSTANT_COUNT: int = 36
const EXPECTED_GAMEPLAY_UI_COUNT: int = 33

# Known debug constant names — used to skip InputMap check in non-debug builds.
const DEBUG_CONSTANT_NAMES: Array[String] = [
	"DEBUG_TOGGLE_AI",
	"DEBUG_NOCLIP",
	"DEBUG_SPAWN_ALERT",
]


# ---------------------------------------------------------------------------
# Helper — load the InputActions script and reflect its constant map.
# ---------------------------------------------------------------------------

func _get_constant_map() -> Dictionary:
	# Use class_name global — no preload literal path (AC-INPUT-9.1 enforcement).
	var instance: InputActions = InputActions.new()
	var script: Script = instance.get_script() as Script
	assert_object(script).is_not_null()
	return script.get_script_constant_map()


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

## InputActions declares exactly 36 constants (33 gameplay/UI + 3 debug).
func test_input_actions_declares_36_constants() -> void:
	# Arrange
	var consts: Dictionary = _get_constant_map()

	# Act
	var count: int = consts.size()

	# Assert
	if count != EXPECTED_CONSTANT_COUNT:
		var names: Array[String] = []
		for key: String in consts.keys():
			names.append(key)
		names.sort()
		assert_bool(false).override_failure_message(
			"Expected %d constants, found %d.\nActual constants:\n  %s" % [
				EXPECTED_CONSTANT_COUNT, count, "\n  ".join(names)
			]
		).is_true()
	else:
		assert_int(count).is_equal(EXPECTED_CONSTANT_COUNT)


## Every constant value in InputActions must be TYPE_STRING_NAME.
func test_input_actions_constants_are_all_string_name() -> void:
	# Arrange
	var consts: Dictionary = _get_constant_map()
	var wrong_type: Array[String] = []

	# Act
	for key: String in consts.keys():
		var value: Variant = consts[key]
		if typeof(value) != TYPE_STRING_NAME:
			wrong_type.append("%s (type=%d)" % [key, typeof(value)])

	# Assert
	if wrong_type.size() > 0:
		assert_bool(false).override_failure_message(
			"Constants not TYPE_STRING_NAME:\n  " + "\n  ".join(wrong_type)
		).is_true()
	else:
		assert_bool(true).is_true()


## No two constants may share the same StringName value (no duplicate action names).
func test_input_actions_constants_have_no_duplicate_values() -> void:
	# Arrange
	var consts: Dictionary = _get_constant_map()
	var seen: Dictionary = {}
	var duplicates: Array[String] = []

	# Act
	for key: String in consts.keys():
		var value: StringName = consts[key] as StringName
		if seen.has(value):
			duplicates.append("%s duplicates %s (value='%s')" % [key, seen[value], String(value)])
		else:
			seen[value] = key

	# Assert
	if duplicates.size() > 0:
		assert_bool(false).override_failure_message("Duplicate StringName values found:\n  " + "\n  ".join(duplicates)).is_true()
	else:
		assert_bool(true).is_true()


## Every gameplay/UI constant (excluding debug constants) satisfies InputMap.has_action().
## Debug constants are checked separately and must NOT be in InputMap in non-debug builds.
func test_input_actions_gameplay_constants_satisfy_inputmap_has_action() -> void:
	# Arrange
	var consts: Dictionary = _get_constant_map()
	var missing_gameplay: Array[String] = []
	var unexpected_debug: Array[String] = []

	# Act
	for key: String in consts.keys():
		var value: StringName = consts[key] as StringName
		var is_debug: bool = key in DEBUG_CONSTANT_NAMES

		if is_debug:
			# Debug constants: only registered at runtime in debug builds.
			if not OS.is_debug_build():
				# Non-debug / headless CI: debug actions must NOT be in InputMap.
				if InputMap.has_action(value):
					unexpected_debug.append("%s ('%s') found in InputMap unexpectedly" % [key, String(value)])
			# In debug build: skip — may or may not be registered depending on
			# whether InputContext._ready() has fired (call site is Story 002).
		else:
			# Gameplay/UI constant: must always be in InputMap (declared in project.godot).
			if not InputMap.has_action(value):
				missing_gameplay.append("%s ('%s')" % [key, String(value)])

	# Assert — report all failures together
	var all_failures: Array[String] = []
	if missing_gameplay.size() > 0:
		all_failures.append(
			"Gameplay/UI constants not in InputMap:\n    " + "\n    ".join(missing_gameplay)
		)
	if unexpected_debug.size() > 0:
		all_failures.append(
			"Debug constants unexpectedly in InputMap:\n    " + "\n    ".join(unexpected_debug)
		)

	if all_failures.size() > 0:
		assert_bool(false).override_failure_message("\n".join(all_failures)).is_true()
	else:
		assert_bool(true).is_true()
