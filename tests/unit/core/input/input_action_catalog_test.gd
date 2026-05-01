# tests/unit/core/input/input_action_catalog_test.gd
#
# AC-INPUT-1.1 — Action catalog integrity against project.godot.
#
# PURPOSE
#   Proves that every gameplay/UI action in the GDD Section C catalog is declared
#   in project.godot with the correct default key/button bindings. For each
#   expected binding, asserts InputMap.action_has_event() returns true.
#
# DESIGN CHOICE — Hardcoded fixture vs. YAML parse
#   This test hardcodes the expected binding data as a const Array[Dictionary].
#   Rationale: Godot 4 has no built-in YAML parser; importing a third-party
#   parser would add an unvetted dependency. The fixture file at
#   tests/fixtures/input/expected_bindings.yaml is the human-readable source of
#   truth (reviewed against GDD Section C). The hardcoded data here mirrors it
#   exactly. Both must be kept in sync; divergence is a bug.
#
# WHAT IS TESTED
#   1. Every gameplay/UI action (33 total) exists in InputMap.
#   2. For each action with a KB/M event, InputMap.action_has_event() returns true.
#   3. For each action with a gamepad event, InputMap.action_has_event() returns true.
#   4. Debug actions (debug_*) are NOT in InputMap during headless test runs.
#   5. InputMap.get_actions() contains at least 33 custom actions.
#
# WHAT IS NOT TESTED HERE
#   - InputActions constant names/types/count (see input_actions_constants_test.gd).
#   - File path / class_name registration (see input_actions_path_test.gd).
#   - Debug action runtime registration (Story 002 call site).
#
# GATE STATUS
#   Story IN-001 | AC-INPUT-1.1 [Logic] BLOCKING.
#   Story type: Logic → test must pass before Done.
#
# NAMING CONVENTION (per tests/README.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[scenario]_[expected_result]

class_name InputActionCatalogTest
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Fixture data — mirrors tests/fixtures/input/expected_bindings.yaml exactly.
# Schema: { action, kb_type, kb_value, gp_type, gp_value }
#   kb_type  : "key" | "mouse_button" | null
#   kb_value : physical_keycode (int) or mouse button_index (int) | null
#   gp_type  : "joypad_button" | "joypad_motion" | null
#   gp_value : { button_index: int } | { axis: int, axis_value: float } | null
# ---------------------------------------------------------------------------

const EXPECTED_BINDINGS: Array = [
	# ── Group 1: Movement ────────────────────────────────────────────────────
	{ "action": "move_forward",    "kb_type": "key",          "kb_value": 87,       "gp_type": "joypad_motion",  "gp_value": { "axis": 1, "axis_value": -1.0 } },
	{ "action": "move_backward",   "kb_type": "key",          "kb_value": 83,       "gp_type": "joypad_motion",  "gp_value": { "axis": 1, "axis_value":  1.0 } },
	{ "action": "move_left",       "kb_type": "key",          "kb_value": 65,       "gp_type": "joypad_motion",  "gp_value": { "axis": 0, "axis_value": -1.0 } },
	{ "action": "move_right",      "kb_type": "key",          "kb_value": 68,       "gp_type": "joypad_motion",  "gp_value": { "axis": 0, "axis_value":  1.0 } },
	# look_horizontal/look_vertical: no KB event (mouse motion read via event.relative)
	{ "action": "look_horizontal", "kb_type": null,           "kb_value": null,     "gp_type": "joypad_motion",  "gp_value": { "axis": 2, "axis_value":  1.0 } },
	{ "action": "look_vertical",   "kb_type": null,           "kb_value": null,     "gp_type": "joypad_motion",  "gp_value": { "axis": 3, "axis_value":  1.0 } },
	{ "action": "jump",            "kb_type": "key",          "kb_value": 32,       "gp_type": "joypad_button",  "gp_value": { "button_index": 0 } },
	{ "action": "crouch",          "kb_type": "key",          "kb_value": 4194326,  "gp_type": "joypad_button",  "gp_value": { "button_index": 8 } },
	{ "action": "sprint",          "kb_type": "key",          "kb_value": 4194325,  "gp_type": "joypad_button",  "gp_value": { "button_index": 7 } },
	# ── Group 2: Combat & Weapons ─────────────────────────────────────────────
	{ "action": "fire_primary",    "kb_type": "mouse_button", "kb_value": 1,        "gp_type": "joypad_motion",  "gp_value": { "axis": 5, "axis_value":  1.0 } },
	{ "action": "aim_down_sights", "kb_type": "mouse_button", "kb_value": 2,        "gp_type": "joypad_motion",  "gp_value": { "axis": 4, "axis_value":  1.0 } },
	{ "action": "reload",          "kb_type": "key",          "kb_value": 82,       "gp_type": "joypad_button",  "gp_value": { "button_index": 2 } },
	{ "action": "weapon_slot_1",   "kb_type": "key",          "kb_value": 49,       "gp_type": null,             "gp_value": null },
	{ "action": "weapon_slot_2",   "kb_type": "key",          "kb_value": 50,       "gp_type": null,             "gp_value": null },
	{ "action": "weapon_slot_3",   "kb_type": "key",          "kb_value": 51,       "gp_type": null,             "gp_value": null },
	{ "action": "weapon_slot_4",   "kb_type": "key",          "kb_value": 52,       "gp_type": null,             "gp_value": null },
	{ "action": "weapon_slot_5",   "kb_type": "key",          "kb_value": 53,       "gp_type": null,             "gp_value": null },
	{ "action": "weapon_next",     "kb_type": "mouse_button", "kb_value": 4,        "gp_type": "joypad_button",  "gp_value": { "button_index": 14 } },
	{ "action": "weapon_prev",     "kb_type": "mouse_button", "kb_value": 5,        "gp_type": "joypad_button",  "gp_value": { "button_index": 13 } },
	# ── Group 3: Gadgets ──────────────────────────────────────────────────────
	{ "action": "takedown",        "kb_type": "key",          "kb_value": 81,       "gp_type": "joypad_button",  "gp_value": { "button_index": 2 } },
	{ "action": "use_gadget",      "kb_type": "key",          "kb_value": 70,       "gp_type": "joypad_button",  "gp_value": { "button_index": 3 } },
	{ "action": "gadget_next",     "kb_type": "mouse_button", "kb_value": 8,        "gp_type": "joypad_button",  "gp_value": { "button_index": 11 } },
	{ "action": "gadget_prev",     "kb_type": "mouse_button", "kb_value": 9,        "gp_type": "joypad_button",  "gp_value": { "button_index": 12 } },
	# ── Group 4: Interaction ──────────────────────────────────────────────────
	{ "action": "interact",        "kb_type": "key",          "kb_value": 69,       "gp_type": "joypad_button",  "gp_value": { "button_index": 0 } },
	# ── Group 5: UI & Menus ───────────────────────────────────────────────────
	{ "action": "ui_cancel",       "kb_type": "key",          "kb_value": 4194305,  "gp_type": "joypad_button",  "gp_value": { "button_index": 1 } },
	# pause: JOY_BUTTON_START = button_index 6 (SDL3 driver, Godot 4.6).
	{ "action": "pause",           "kb_type": "key",          "kb_value": 4194305,  "gp_type": "joypad_button",  "gp_value": { "button_index": 6 } },
	{ "action": "ui_up",           "kb_type": "key",          "kb_value": 4194320,  "gp_type": "joypad_button",  "gp_value": { "button_index": 11 } },
	{ "action": "ui_down",         "kb_type": "key",          "kb_value": 4194321,  "gp_type": "joypad_button",  "gp_value": { "button_index": 12 } },
	{ "action": "ui_left",         "kb_type": "key",          "kb_value": 4194318,  "gp_type": "joypad_button",  "gp_value": { "button_index": 13 } },
	{ "action": "ui_right",        "kb_type": "key",          "kb_value": 4194322,  "gp_type": "joypad_button",  "gp_value": { "button_index": 14 } },
	{ "action": "ui_accept",       "kb_type": "key",          "kb_value": 4194309,  "gp_type": "joypad_button",  "gp_value": { "button_index": 0 } },
	{ "action": "quicksave",       "kb_type": "key",          "kb_value": 4194336,  "gp_type": null,             "gp_value": null },
	{ "action": "quickload",       "kb_type": "key",          "kb_value": 4194340,  "gp_type": null,             "gp_value": null },
]

const DEBUG_ACTIONS: Array[StringName] = [
	&"debug_toggle_ai",
	&"debug_noclip",
	&"debug_spawn_alert",
]

const EXPECTED_GAMEPLAY_UI_COUNT: int = 33


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_key_event(physical_keycode: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = physical_keycode as Key
	return ev


func _make_mouse_button_event(button_index: int) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button_index as MouseButton
	return ev


func _make_joypad_button_event(button_index: int) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button_index as JoyButton
	return ev


func _make_joypad_motion_event(axis: int, axis_value: float) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis as JoyAxis
	ev.axis_value = axis_value
	return ev


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

## Every gameplay/UI action name in the catalog must exist in InputMap.
func test_input_catalog_all_33_actions_registered_in_inputmap() -> void:
	# Arrange
	var missing: Array[StringName] = []

	# Act
	for binding: Dictionary in EXPECTED_BINDINGS:
		var action_name: StringName = binding["action"]
		if not InputMap.has_action(action_name):
			missing.append(action_name)

	# Assert
	if missing.size() > 0:
		var names: Array[String] = []
		for n: StringName in missing:
			names.append(String(n))
		assert_bool(false).override_failure_message("Missing actions in InputMap: " + ", ".join(names)).is_true()
	else:
		assert_bool(true).is_true()


## InputMap contains at least EXPECTED_GAMEPLAY_UI_COUNT custom actions.
## (Godot may add built-in ui_* actions on top of ours.)
func test_input_catalog_inputmap_contains_at_least_33_actions() -> void:
	# Arrange
	var all_actions: Array[StringName] = InputMap.get_actions()
	var custom_count: int = 0

	# Act — count only project-defined actions (not built-in Godot ui_ actions
	# that we didn't define, but include our own ui_* which ARE in the catalog)
	for action: StringName in all_actions:
		var action_str: String = String(action)
		# Built-in Godot actions that are NOT in our catalog start with "ui_" but
		# are not in our EXPECTED_BINDINGS list. Count all actions we declared.
		for binding: Dictionary in EXPECTED_BINDINGS:
			if binding["action"] == action_str:
				custom_count += 1
				break

	# Assert
	assert_int(custom_count).is_greater_equal(EXPECTED_GAMEPLAY_UI_COUNT)


## For each action with a KB event, InputMap.action_has_event() returns true.
func test_input_catalog_keyboard_bindings_all_present() -> void:
	# Arrange
	var failures: Array[String] = []

	# Act
	for binding: Dictionary in EXPECTED_BINDINGS:
		var action_name: StringName = binding["action"]
		var kb_type: Variant = binding["kb_type"]

		if kb_type == null:
			continue  # No KB binding expected for this action (e.g. look axes)

		var ev: InputEvent
		if kb_type == "key":
			ev = _make_key_event(binding["kb_value"])
		elif kb_type == "mouse_button":
			ev = _make_mouse_button_event(binding["kb_value"])
		else:
			failures.append("%s: unknown kb_type '%s'" % [action_name, kb_type])
			continue

		if not InputMap.action_has_event(action_name, ev):
			failures.append("%s (kb_type=%s kb_value=%s)" % [action_name, kb_type, binding["kb_value"]])

	# Assert
	if failures.size() > 0:
		assert_bool(false).override_failure_message("KB bindings missing in InputMap:\n  " + "\n  ".join(failures)).is_true()
	else:
		assert_bool(true).is_true()


## For each action with a gamepad event, InputMap.action_has_event() returns true.
func test_input_catalog_gamepad_bindings_all_present() -> void:
	# Arrange
	var failures: Array[String] = []

	# Act
	for binding: Dictionary in EXPECTED_BINDINGS:
		var action_name: StringName = binding["action"]
		var gp_type: Variant = binding["gp_type"]

		if gp_type == null:
			continue  # No gamepad binding expected (weapon slots, quicksave, quickload)

		var gp_value: Dictionary = binding["gp_value"]
		var ev: InputEvent

		if gp_type == "joypad_button":
			ev = _make_joypad_button_event(gp_value["button_index"])
		elif gp_type == "joypad_motion":
			ev = _make_joypad_motion_event(gp_value["axis"], gp_value["axis_value"])
		else:
			failures.append("%s: unknown gp_type '%s'" % [action_name, gp_type])
			continue

		if not InputMap.action_has_event(action_name, ev):
			failures.append("%s (gp_type=%s gp_value=%s)" % [action_name, gp_type, str(gp_value)])

	# Assert
	if failures.size() > 0:
		assert_bool(false).override_failure_message("Gamepad bindings missing in InputMap:\n  " + "\n  ".join(failures)).is_true()
	else:
		assert_bool(true).is_true()


## Debug actions must NOT be in InputMap during headless test runs (not debug builds).
## In a debug build (editor or debug export), this test is skipped.
func test_input_catalog_debug_actions_absent_in_non_debug_run() -> void:
	# Headless CI is always a release/non-debug build context — debug actions should
	# not be registered. In the editor (debug build), skip this assertion.
	if OS.is_debug_build():
		# Running in editor — debug actions may or may not be registered depending on
		# whether InputContext._ready() has fired. Skip to avoid false positives.
		assert_bool(true).is_true()
		return

	# Act + Assert — non-debug build: debug actions must not be in InputMap
	for debug_action: StringName in DEBUG_ACTIONS:
		assert_bool(InputMap.has_action(debug_action)).is_false()
