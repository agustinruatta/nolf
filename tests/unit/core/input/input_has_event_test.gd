# tests/unit/core/input/input_has_event_test.gd
#
# InputHasEventTest — Story IN-006 AC-INPUT-4.2(a).
#
# COVERED ACCEPTANCE CRITERIA (Story IN-006)
#   AC-4.2(a) (BLOCKING): conflict-detection primitive — given an event,
#   determine whether it's already bound to ANY action in the InputMap.
#
# API NOTE
#   Godot 4.6 does NOT expose a top-level `InputMap.has_event(event)` method.
#   The conflict-detection primitive iterates `InputMap.get_actions()` and
#   uses `InputMap.event_is_action(event, action_name)` per action. This
#   helper is the building block; Settings GDD's conflict-resolution UI will
#   wrap it to surface the conflicting action name to the user.
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name InputHasEventTest
extends GdUnitTestSuite


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_key_event(keycode: Key) -> InputEventKey:
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = keycode
	return ev


## Returns the StringName of the first action that has `event` bound,
## or empty StringName if no action has it.
func _find_action_for_event(event: InputEvent) -> StringName:
	for action: StringName in InputMap.get_actions():
		if InputMap.event_is_action(event, action):
			return action
	return &""


## Returns true if any action in the InputMap has `event` bound.
func _has_event(event: InputEvent) -> bool:
	return _find_action_for_event(event) != &""


# ── AC-4.2(a): conflict-detection — bound key returns true ───────────────────

## AC-4.2(a): KEY_W is bound to move_forward (project.godot baseline) →
## conflict-detection primitive returns true.
func test_has_event_returns_true_for_bound_key() -> void:
	var ev: InputEventKey = _make_key_event(KEY_W)
	assert_bool(_has_event(ev)).override_failure_message(
		"AC-4.2(a): KEY_W is bound to move_forward; primitive must return true."
	).is_true()


# ── AC-4.2(a): unbound key returns false ────────────────────────────────────

## AC-4.2(a): KEY_F11 is not bound to any action → primitive returns false.
func test_has_event_returns_false_for_unbound_key() -> void:
	var ev: InputEventKey = _make_key_event(KEY_F11)
	assert_bool(_has_event(ev)).override_failure_message(
		"AC-4.2(a): KEY_F11 is unbound; primitive must return false."
	).is_false()


# ── AC-4.2(a): primitive identifies which action holds the conflict ─────────

## AC-4.2(a) — conflict surfacing: the helper returns the action name so the
## Settings UI can tell the user "T is already bound to <action>".
func test_find_action_for_bound_event_returns_correct_action_name() -> void:
	var ev: InputEventKey = _make_key_event(KEY_W)
	var action: StringName = _find_action_for_event(ev)
	# Must be move_forward (the project.godot binding)
	assert_str(String(action)).override_failure_message(
		"AC-4.2(a) surfacing: KEY_W must surface as bound to 'move_forward'. Got '%s'." % String(action)
	).is_equal("move_forward")


## AC-4.2(a) — unbound event returns empty StringName (sentinel for "no conflict").
func test_find_action_for_unbound_event_returns_empty() -> void:
	var ev: InputEventKey = _make_key_event(KEY_F11)
	var action: StringName = _find_action_for_event(ev)
	assert_str(String(action)).override_failure_message(
		"AC-4.2(a): unbound event must return empty StringName as 'no conflict' sentinel."
	).is_equal("")


# ── AC-4.2(a): event_is_action() per-action API stable ──────────────────────

## AC-4.2(a) API verification: InputMap.event_is_action exists and works as
## expected for the per-action conflict check.
func test_event_is_action_works_for_known_binding() -> void:
	var ev: InputEventKey = _make_key_event(KEY_W)
	assert_bool(InputMap.event_is_action(ev, &"move_forward")).is_true()
	assert_bool(InputMap.event_is_action(ev, &"move_backward")).is_false()
