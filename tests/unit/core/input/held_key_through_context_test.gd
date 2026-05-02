# tests/unit/core/input/held_key_through_context_test.gd
#
# HeldKeyThroughContextTest — Story IN-005 AC-INPUT-5.1.
#
# COVERED ACCEPTANCE CRITERIA (Story IN-005)
#   AC-5.1 (BLOCKING): held-key state persists across InputContext push/pop.
#   `Input.is_action_pressed()` queries the engine input tracker, which is
#   stateless w.r.t. context transitions. An action in the "pressed" state
#   stays pressed until explicitly released.
#
# DESIGN
#   Headless GdUnit4 doesn't synchronously update action state from
#   `Input.parse_input_event()`. Tests use `Input.action_press(name)` and
#   `Input.action_release(name)` — these directly set the action state in
#   the engine input tracker without going through the input event pipeline.
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name HeldKeyThroughContextTest
extends GdUnitTestSuite


func _reset_context() -> void:
	while InputContext.current() != InputContextStack.Context.GAMEPLAY:
		InputContext.pop()  # dismiss-order-ok: test cleanup helper.


func before_test() -> void:
	_reset_context()
	Input.action_release(InputActions.MOVE_FORWARD)


func after_test() -> void:
	Input.action_release(InputActions.MOVE_FORWARD)
	_reset_context()


# ── AC-5.1: held action survives push/pop round-trip ────────────────────────

func test_held_action_persists_through_menu_push_and_pop() -> void:
	# Arrange — press move_forward (held)
	Input.action_press(InputActions.MOVE_FORWARD)

	# Pre-condition
	assert_bool(Input.is_action_pressed(InputActions.MOVE_FORWARD)).override_failure_message(
		"AC-5.1 pre: action_press must register move_forward as pressed."
	).is_true()

	# Act — push MENU then pop
	InputContext.push(InputContextStack.Context.MENU)
	InputContext.pop()  # dismiss-order-ok: test scenario, not modal dismiss.

	# Assert — held state survives the round-trip
	assert_bool(Input.is_action_pressed(InputActions.MOVE_FORWARD)).override_failure_message(
		"AC-5.1: held action must STILL register as pressed after push(MENU)/pop() round-trip. " +
		"Input is stateless w.r.t. InputContext."
	).is_true()


# ── AC-5.1 corollary: release event clears the held state ───────────────────

func test_release_event_clears_held_state() -> void:
	Input.action_press(InputActions.MOVE_FORWARD)
	assert_bool(Input.is_action_pressed(InputActions.MOVE_FORWARD)).is_true()

	Input.action_release(InputActions.MOVE_FORWARD)

	assert_bool(Input.is_action_pressed(InputActions.MOVE_FORWARD)).override_failure_message(
		"AC-5.1 corollary: action_release must clear the held state."
	).is_false()


# ── AC-5.1: InputContext.push does NOT clear held state ─────────────────────

func test_input_context_push_does_not_clear_held_state() -> void:
	Input.action_press(InputActions.MOVE_FORWARD)

	InputContext.push(InputContextStack.Context.MENU)

	assert_bool(Input.is_action_pressed(InputActions.MOVE_FORWARD)).override_failure_message(
		"AC-5.1: push(MENU) must NOT clear held action — Input is stateless w.r.t. context."
	).is_true()


# ── AC-5.1: multiple push/pop cycles do not perturb held state ──────────────

func test_held_action_persists_through_multiple_push_pop_cycles() -> void:
	Input.action_press(InputActions.MOVE_FORWARD)

	for i: int in range(3):
		InputContext.push(InputContextStack.Context.MENU)
		assert_bool(Input.is_action_pressed(InputActions.MOVE_FORWARD)).override_failure_message(
			"AC-5.1 cycle %d push: held action must persist." % i
		).is_true()
		InputContext.pop()  # dismiss-order-ok: test scenario.
		assert_bool(Input.is_action_pressed(InputActions.MOVE_FORWARD)).override_failure_message(
			"AC-5.1 cycle %d pop: held action must persist." % i
		).is_true()
