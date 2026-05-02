# tests/unit/core/input/joy_disconnect_test.gd
#
# JoyDisconnectTest — Story IN-005 AC-INPUT-5.2.
#
# COVERED ACCEPTANCE CRITERIA (Story IN-005)
#   AC-5.2 (BLOCKING): gamepad disconnect does NOT auto-pause the game.
#   Held KB action state continues to register; Input does NOT auto-emit
#   any pause action. Pause-on-disconnect is Menu System's concern (per GDD
#   §Edge Cases), not Input's.
#
# DESIGN
#   Uses Input.action_press / action_release (synchronous engine state
#   updates) rather than parse_input_event (unreliable in headless GdUnit4).
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name JoyDisconnectTest
extends GdUnitTestSuite


func before_test() -> void:
	Input.action_release(InputActions.MOVE_FORWARD)
	Input.action_release(InputActions.PAUSE)


func after_test() -> void:
	Input.action_release(InputActions.MOVE_FORWARD)
	Input.action_release(InputActions.PAUSE)


# ── AC-5.2: gamepad disconnect does NOT clear held action state ─────────────

func test_gamepad_disconnect_does_not_clear_held_action_state() -> void:
	Input.action_press(InputActions.MOVE_FORWARD)
	assert_bool(Input.is_action_pressed(InputActions.MOVE_FORWARD)).is_true()

	# Simulate gamepad 0 disconnect
	Input.joy_connection_changed.emit(0, false)

	assert_bool(Input.is_action_pressed(InputActions.MOVE_FORWARD)).override_failure_message(
		"AC-5.2: gamepad disconnect must NOT clear held action state. move_forward must still register."
	).is_true()


# ── AC-5.2: Input does NOT auto-emit pause on gamepad disconnect ────────────

func test_gamepad_disconnect_does_not_trigger_pause_action() -> void:
	# Pre-condition: pause is not pressed
	assert_bool(Input.is_action_pressed(InputActions.PAUSE)).override_failure_message(
		"AC-5.2 pre: pause action must not be pressed before disconnect."
	).is_false()

	# Act
	Input.joy_connection_changed.emit(0, false)

	# Assert — pause is still NOT pressed (Input did not auto-trigger it)
	assert_bool(Input.is_action_pressed(InputActions.PAUSE)).override_failure_message(
		"AC-5.2: gamepad disconnect must NOT trigger pause action via Input. " +
		"Pause-on-disconnect is Menu System's concern (GDD §Edge Cases)."
	).is_false()


# ── AC-5.2: connect/reconnect cycle does NOT perturb action state ──────────

func test_gamepad_reconnect_does_not_perturb_held_action_state() -> void:
	Input.action_press(InputActions.MOVE_FORWARD)
	assert_bool(Input.is_action_pressed(InputActions.MOVE_FORWARD)).is_true()

	# Disconnect then reconnect
	Input.joy_connection_changed.emit(0, false)
	Input.joy_connection_changed.emit(0, true)

	assert_bool(Input.is_action_pressed(InputActions.MOVE_FORWARD)).override_failure_message(
		"AC-5.2: gamepad reconnect must NOT clear held action state."
	).is_true()
