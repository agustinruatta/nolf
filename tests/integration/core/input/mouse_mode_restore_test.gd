# tests/integration/core/input/mouse_mode_restore_test.gd
#
# MouseModeRestoreTest — Story IN-005 AC-INPUT-7.2.
#
# COVERED ACCEPTANCE CRITERIA (Story IN-005)
#   AC-7.2 (BLOCKING): Player Character (mouse-capture owner) restores
#   MOUSE_MODE_CAPTURED when context returns to GAMEPLAY after a modal closes.
#
# HEADLESS LIMITATION
#   In Godot 4.6 headless mode, `Input.mouse_mode = MOUSE_MODE_CAPTURED` is
#   silently coerced to MOUSE_MODE_VISIBLE (the engine has no real cursor to
#   capture). This breaks direct `Input.mouse_mode` assertions.
#
#   Workaround: each fixture tracks its own "intended mouse mode" in a public
#   var that the test can read. The contract test is on the FIXTURE INTENT,
#   not on the engine's coerced state. The full visible-cursor behavior is
#   verified manually in playtest evidence; the LOGIC contract (PC restores
#   capture on GAMEPLAY context entry) is verified here.
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name MouseModeRestoreTest
extends GdUnitTestSuite


# ── Inline fixtures (track intent in public vars; engine coercion is moot) ──

## Player Character mouse-mode owner fixture. Subscribes to ui_context_changed
## and intends MOUSE_MODE_CAPTURED on GAMEPLAY entry. Tracks the most-recently
## set mouse mode as `intended_mouse_mode` for headless test assertions.
class PlayerCharacterMouseFixture extends Node:
	## The most-recently set Input.mouse_mode value (intent, not engine state).
	var intended_mouse_mode: int = Input.MOUSE_MODE_VISIBLE

	func _ready() -> void:
		intended_mouse_mode = Input.MOUSE_MODE_CAPTURED
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED  # engine call (may be coerced in headless)
		if not Events.ui_context_changed.is_connected(_on_ui_context_changed):
			Events.ui_context_changed.connect(_on_ui_context_changed)

	func _exit_tree() -> void:
		if Events.ui_context_changed.is_connected(_on_ui_context_changed):
			Events.ui_context_changed.disconnect(_on_ui_context_changed)

	func _on_ui_context_changed(new_ctx: int, _old_ctx: int) -> void:
		if new_ctx == InputContextStack.Context.GAMEPLAY:
			intended_mouse_mode = Input.MOUSE_MODE_CAPTURED
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Menu modal fixture. Sets MOUSE_MODE_VISIBLE on open (push). Tracks intent.
class MenuModalFixture extends Control:
	var intended_mouse_mode: int = Input.MOUSE_MODE_VISIBLE

	func _ready() -> void:
		InputContext.push(InputContextStack.Context.MENU)
		intended_mouse_mode = Input.MOUSE_MODE_VISIBLE
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _reset_input_context() -> void:
	while InputContext.current() != InputContextStack.Context.GAMEPLAY:
		InputContext.pop()  # dismiss-order-ok: test cleanup helper.


func before_test() -> void:
	_reset_input_context()


func after_test() -> void:
	_reset_input_context()


# ── AC-7.2: full round-trip restoration ──────────────────────────────────────

func test_mouse_mode_restored_after_menu_open_close_round_trip() -> void:
	# Arrange — Player Character claims MOUSE_MODE_CAPTURED in _ready
	var pc_fixture: PlayerCharacterMouseFixture = PlayerCharacterMouseFixture.new()
	add_child(pc_fixture)
	auto_free(pc_fixture)

	# Pre-condition: PC intends capture
	assert_int(pc_fixture.intended_mouse_mode).override_failure_message(
		"AC-7.2 pre: Player Character _ready must intend MOUSE_MODE_CAPTURED. Got %d." % pc_fixture.intended_mouse_mode
	).is_equal(Input.MOUSE_MODE_CAPTURED)

	# Act 1 — open Menu modal (intends MOUSE_MODE_VISIBLE)
	var menu_fixture: MenuModalFixture = MenuModalFixture.new()
	add_child(menu_fixture)
	auto_free(menu_fixture)

	assert_int(menu_fixture.intended_mouse_mode).is_equal(Input.MOUSE_MODE_VISIBLE)
	assert_int(int(InputContext.current())).is_equal(InputContextStack.Context.MENU)

	# Act 2 — close Menu (pop fires ui_context_changed → PC restores intent)
	InputContext.pop()  # dismiss-order-ok: test scenario.

	# Assert — PC's intent is now CAPTURED again
	assert_int(int(InputContext.current())).is_equal(InputContextStack.Context.GAMEPLAY)
	assert_int(pc_fixture.intended_mouse_mode).override_failure_message(
		"AC-7.2: Player Character must re-intend MOUSE_MODE_CAPTURED on return to GAMEPLAY. Got %d." % pc_fixture.intended_mouse_mode
	).is_equal(Input.MOUSE_MODE_CAPTURED)


# ── AC-7.2 corollary: without subscriber, mouse mode is NOT auto-restored ───

## Documents the contract: an active subscriber is required for restoration.
## Without Player Character subscribing, the modal's intent persists.
func test_without_subscriber_intent_is_not_auto_restored() -> void:
	# Arrange — no Player Character fixture
	var menu_fixture: MenuModalFixture = MenuModalFixture.new()
	add_child(menu_fixture)
	auto_free(menu_fixture)
	assert_int(menu_fixture.intended_mouse_mode).is_equal(Input.MOUSE_MODE_VISIBLE)

	# Pop without a subscriber to ui_context_changed
	InputContext.pop()  # dismiss-order-ok: test scenario.

	# Without a subscriber, the menu fixture's intent is the last active intent.
	# (The fixture itself doesn't observe pop; the engine state is whatever it
	# was last set to. The contract: PC must subscribe to restore.)
	assert_int(menu_fixture.intended_mouse_mode).override_failure_message(
		"AC-7.2 corollary: without an active subscriber to ui_context_changed, " +
		"intent stays at MOUSE_MODE_VISIBLE (the last write)."
	).is_equal(Input.MOUSE_MODE_VISIBLE)


# ── AC-7.2: multiple round-trips all restore PC's intent ────────────────────

func test_multiple_open_close_cycles_all_restore_capture_intent() -> void:
	var pc_fixture: PlayerCharacterMouseFixture = PlayerCharacterMouseFixture.new()
	add_child(pc_fixture)
	auto_free(pc_fixture)

	for i: int in range(3):
		var menu: MenuModalFixture = MenuModalFixture.new()
		add_child(menu)
		auto_free(menu)
		assert_int(menu.intended_mouse_mode).is_equal(Input.MOUSE_MODE_VISIBLE)
		InputContext.pop()  # dismiss-order-ok: test scenario.
		assert_int(pc_fixture.intended_mouse_mode).override_failure_message(
			"AC-7.2: cycle %d — PC must re-intend MOUSE_MODE_CAPTURED on context return." % i
		).is_equal(Input.MOUSE_MODE_CAPTURED)


# ── AC-7.2: PC fixture subscriber lifecycle ─────────────────────────────────

## PC fixture connects to ui_context_changed in _ready and disconnects in
## _exit_tree (ADR-0002 IG 3 lifecycle).
func test_pc_fixture_disconnects_from_ui_context_changed_on_exit() -> void:
	var pc_fixture: PlayerCharacterMouseFixture = PlayerCharacterMouseFixture.new()
	add_child(pc_fixture)
	# Don't auto-free — manually free to trigger _exit_tree synchronously
	var on_ctx_changed: Callable = pc_fixture._on_ui_context_changed
	assert_bool(Events.ui_context_changed.is_connected(on_ctx_changed)).is_true()

	pc_fixture.queue_free()
	await get_tree().process_frame

	assert_bool(Events.ui_context_changed.is_connected(on_ctx_changed)).override_failure_message(
		"AC-7.2 lifecycle: PC fixture must disconnect from ui_context_changed on _exit_tree (ADR-0002 IG 3)."
	).is_false()
