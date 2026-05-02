# tests/unit/core/input/input_rebind_runtime_test.gd
#
# InputRebindRuntimeTest — Story IN-006 AC-INPUT-4.1.
#
# COVERED ACCEPTANCE CRITERIA (Story IN-006)
#   AC-4.1 (BLOCKING): InputMap.action_erase_events + action_add_event called
#   in sequence (no await) replaces the binding. Old key no longer triggers
#   the action; new key does.
#
# DESIGN
#   Tests use `Input.action_press(action_name)` / `Input.action_release` to
#   directly verify action state, since `Input.parse_input_event` doesn't
#   reliably flush in headless GdUnit4. The rebind itself uses real InputMap
#   API calls — that part is engine-level and works synchronously.
#
# TEARDOWN
#   Each test restores `move_forward → W` (physical_keycode 87) to avoid
#   polluting downstream tests that depend on the project.godot binding.
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name InputRebindRuntimeTest
extends GdUnitTestSuite

const _ACTION: StringName = &"move_forward"
const _DEFAULT_KEYCODE: Key = KEY_W
const _NEW_KEYCODE: Key = KEY_T


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_key_event(keycode: Key, pressed: bool = true) -> InputEventKey:
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = keycode
	ev.pressed = pressed
	return ev


## Original move_forward events captured at first run; preserved across tests
## so we restore the EXACT project.godot baseline (key + joypad_motion), not
## just a single key event.
static var _saved_events: Array[InputEvent] = []


func _capture_default_binding() -> void:
	if _saved_events.is_empty() and InputMap.has_action(_ACTION):
		_saved_events = InputMap.action_get_events(_ACTION).duplicate() as Array[InputEvent]


## Restores move_forward to its full baseline binding (key + joypad_motion).
func _restore_default_binding() -> void:
	if InputMap.has_action(_ACTION):
		InputMap.action_erase_events(_ACTION)
		for ev: InputEvent in _saved_events:
			InputMap.action_add_event(_ACTION, ev)


func before_test() -> void:
	_capture_default_binding()
	Input.action_release(_ACTION)


func after_test() -> void:
	Input.action_release(_ACTION)
	_restore_default_binding()


# ── AC-4.1: rebind replaces old binding ──────────────────────────────────────

## AC-4.1: After erase+add, the new key triggers the action and the old key
## does not. Verified via `event_is_action` per-event check.
func test_rebind_replaces_old_binding() -> void:
	# Pre-condition: the default W key triggers move_forward
	assert_bool(InputMap.event_is_action(_make_key_event(_DEFAULT_KEYCODE), _ACTION)).override_failure_message(
		"AC-4.1 pre: default W binding must trigger move_forward."
	).is_true()

	# Act — atomic rebind: erase then add (no await between calls)
	InputMap.action_erase_events(_ACTION)
	if InputMap.has_action(_ACTION):  # Core Rule 6 has_action guard
		InputMap.action_add_event(_ACTION, _make_key_event(_NEW_KEYCODE, false))

	# Assert — new key triggers the action
	assert_bool(InputMap.event_is_action(_make_key_event(_NEW_KEYCODE), _ACTION)).override_failure_message(
		"AC-4.1: T key must trigger move_forward after rebind."
	).is_true()
	# Old key no longer triggers
	assert_bool(InputMap.event_is_action(_make_key_event(_DEFAULT_KEYCODE), _ACTION)).override_failure_message(
		"AC-4.1: W key must NOT trigger move_forward after rebind to T."
	).is_false()


# ── AC-4.1: erase alone leaves action unbound ────────────────────────────────

func test_erase_alone_leaves_action_unbound() -> void:
	InputMap.action_erase_events(_ACTION)

	# Neither key triggers the action when no events are bound
	assert_bool(InputMap.event_is_action(_make_key_event(_DEFAULT_KEYCODE), _ACTION)).override_failure_message(
		"AC-4.1: after erase_events, no key triggers the action."
	).is_false()
	assert_bool(InputMap.event_is_action(_make_key_event(_NEW_KEYCODE), _ACTION)).is_false()
	# Action ITSELF still exists (just no events)
	assert_bool(InputMap.has_action(_ACTION)).override_failure_message(
		"AC-4.1: erase_events must NOT delete the action itself, only its events."
	).is_true()


# ── AC-4.1: events list reflects the rebind ─────────────────────────────────

func test_action_get_events_reflects_rebind() -> void:
	InputMap.action_erase_events(_ACTION)
	if InputMap.has_action(_ACTION):
		InputMap.action_add_event(_ACTION, _make_key_event(_NEW_KEYCODE, false))

	var events: Array[InputEvent] = InputMap.action_get_events(_ACTION)
	assert_int(events.size()).override_failure_message(
		"AC-4.1: action should have exactly 1 event after rebind. Got %d." % events.size()
	).is_equal(1)
	# The single event matches the new keycode
	var first: InputEventKey = events[0] as InputEventKey
	assert_int(first.physical_keycode).is_equal(int(_NEW_KEYCODE))
