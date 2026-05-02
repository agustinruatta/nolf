# tests/integration/core/input/dual_focus_dismiss_test.gd
#
# DualFocusDismissTest — Story IN-003 AC-INPUT-3.1.
#
# COVERED ACCEPTANCE CRITERIA (Story IN-003)
#   AC-3.1 [Integration] BLOCKING — parametrized over input modality:
#     Document Overlay open; dismiss handler fires for keyboard Esc, gamepad B,
#     and correctly ignores unrelated mouse click.
#
# DUAL-FOCUS NOTE (Godot 4.6)
#   ADR-0004 IG 3 modal-dismiss pattern (`_unhandled_input` + `ui_cancel` action)
#   sidesteps Godot's mouse/keyboard focus split entirely. Test verifies that
#   the handler fires from each input modality (keyboard/gamepad) regardless of
#   which Control holds focus.
#
# DELIVERY MODEL
#   Tests construct InputEvent instances and invoke `_unhandled_input(event)`
#   directly on the fixture. This is the headless equivalent of the input
#   pipeline; `Input.parse_input_event()` does not reliably flush through
#   `_unhandled_input` in a single GdUnit4 test frame.
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name DualFocusDismissTest
extends GdUnitTestSuite


# ── Inline fixture ────────────────────────────────────────────────────────────

class DismissHandlerFixture extends Control:
	signal dismiss_triggered

	func _ready() -> void:
		InputContext.push(InputContextStack.Context.DOCUMENT_OVERLAY)

	func _unhandled_input(event: InputEvent) -> void:
		if not InputContext.is_active(InputContextStack.Context.DOCUMENT_OVERLAY):
			return
		if event.is_action_pressed(InputActions.UI_CANCEL):
			get_viewport().set_input_as_handled()
			InputContext.pop()
			dismiss_triggered.emit()


func _reset_input_context() -> void:
	while InputContext.current() != InputContextStack.Context.GAMEPLAY:
		InputContext.pop()  # dismiss-order-ok: test cleanup helper, not an input-event-driven dismiss.


# ── AC-3.1 sub-case 1: keyboard Esc dismisses ────────────────────────────────

func test_dismiss_via_keyboard_esc() -> void:
	_reset_input_context()
	var fixture: DismissHandlerFixture = DismissHandlerFixture.new()
	add_child(fixture)
	auto_free(fixture)

	var dismiss_count: Array[int] = [0]
	var on_dismiss: Callable = func(): dismiss_count[0] += 1
	fixture.dismiss_triggered.connect(on_dismiss)

	assert_int(int(InputContext.current())).is_equal(InputContextStack.Context.DOCUMENT_OVERLAY)

	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	fixture._unhandled_input(ev)

	fixture.dismiss_triggered.disconnect(on_dismiss)

	assert_int(dismiss_count[0]).override_failure_message(
		"AC-3.1 sub-case 1: keyboard Esc must dismiss overlay. Got %d." % dismiss_count[0]
	).is_equal(1)
	assert_int(int(InputContext.current())).is_equal(InputContextStack.Context.GAMEPLAY)


# ── AC-3.1 sub-case 2: gamepad B button dismisses ────────────────────────────

func test_dismiss_via_gamepad_b_button() -> void:
	_reset_input_context()
	var fixture: DismissHandlerFixture = DismissHandlerFixture.new()
	add_child(fixture)
	auto_free(fixture)

	var dismiss_count: Array[int] = [0]
	var on_dismiss: Callable = func(): dismiss_count[0] += 1
	fixture.dismiss_triggered.connect(on_dismiss)

	var ev: InputEventJoypadButton = InputEventJoypadButton.new()
	ev.button_index = JOY_BUTTON_B  # Godot 4.6: bound to ui_cancel via ADR-0004
	ev.pressed = true
	fixture._unhandled_input(ev)

	fixture.dismiss_triggered.disconnect(on_dismiss)

	assert_int(dismiss_count[0]).override_failure_message(
		"AC-3.1 sub-case 2: gamepad B must dismiss overlay (ui_cancel binding). Got %d." % dismiss_count[0]
	).is_equal(1)
	assert_int(int(InputContext.current())).is_equal(InputContextStack.Context.GAMEPLAY)


# ── AC-3.1 sub-case 3: mouse click does NOT dismiss (no click-outside) ──────

func test_unrelated_mouse_click_does_not_dismiss() -> void:
	_reset_input_context()
	var fixture: DismissHandlerFixture = DismissHandlerFixture.new()
	add_child(fixture)
	auto_free(fixture)

	var dismiss_count: Array[int] = [0]
	var on_dismiss: Callable = func(): dismiss_count[0] += 1
	fixture.dismiss_triggered.connect(on_dismiss)

	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(100, 100)
	fixture._unhandled_input(ev)

	fixture.dismiss_triggered.disconnect(on_dismiss)

	assert_int(dismiss_count[0]).override_failure_message(
		"AC-3.1 sub-case 3: unrelated mouse click must NOT dismiss overlay. Got %d." % dismiss_count[0]
	).is_equal(0)
	# Post-condition: still in DOCUMENT_OVERLAY (no pop occurred)
	assert_int(int(InputContext.current())).is_equal(InputContextStack.Context.DOCUMENT_OVERLAY)

	# Cleanup: pop the context manually since no dismiss fired
	_reset_input_context()


# ── AC-3.1: dismiss handler gates on InputContext ────────────────────────────

## Belt-and-braces: even if the handler is invoked while context is GAMEPLAY,
## the is_active(DOCUMENT_OVERLAY) gate rejects.
func test_dismiss_handler_gate_rejects_in_gameplay_context() -> void:
	_reset_input_context()
	var fixture: DismissHandlerFixture = DismissHandlerFixture.new()
	add_child(fixture)
	auto_free(fixture)
	# Pop the overlay so context is GAMEPLAY despite the fixture being active
	_reset_input_context()
	assert_int(int(InputContext.current())).is_equal(InputContextStack.Context.GAMEPLAY)

	var dismiss_count: Array[int] = [0]
	var on_dismiss: Callable = func(): dismiss_count[0] += 1
	fixture.dismiss_triggered.connect(on_dismiss)

	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = KEY_ESCAPE
	ev.pressed = true
	fixture._unhandled_input(ev)

	fixture.dismiss_triggered.disconnect(on_dismiss)

	assert_int(dismiss_count[0]).override_failure_message(
		"AC-3.1 gate: dismiss must reject when InputContext != DOCUMENT_OVERLAY. Got %d." % dismiss_count[0]
	).is_equal(0)
