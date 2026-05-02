# tests/integration/core/input/loading_context_gate_test.gd
#
# LoadingContextGateTest — Story IN-007 AC-INPUT-8.1.
#
# COVERED ACCEPTANCE CRITERIA (Story IN-007)
#   AC-8.1 (BLOCKING): During InputContext.LOADING, all gameplay input is
#   swallowed by the is_active(GAMEPLAY) gate. fire_primary and quicksave
#   handlers do NOT execute. After pop returns to GAMEPLAY, handlers fire
#   normally.
#   LOADING enum present (BLOCKING): InputContext.Context.LOADING resolves
#   without parse error.
#
# DESIGN
#   Three fixtures: LevelStreamingFixture (pushes/pops LOADING), CombatFixture
#   (fire_primary handler), SaveLoadFixture (quicksave handler). Both gameplay
#   handlers gate on is_active(GAMEPLAY). Direct _unhandled_input invocation
#   verifies the gate logic without depending on the headless input pipeline.
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name LoadingContextGateTest
extends GdUnitTestSuite


# ── Inline fixtures ──────────────────────────────────────────────────────────

## Stand-in for LevelStreamingService — pushes / pops LOADING context.
class LevelStreamingFixture extends Node:
	func enter_loading() -> void:
		InputContext.push(InputContextStack.Context.LOADING)

	func exit_loading() -> void:
		InputContext.pop()  # dismiss-order-ok: state-machine pop, not modal dismiss.


## Stand-in for Combat fire_primary handler.
class CombatFixture extends Node:
	signal shot_fired

	func _unhandled_input(event: InputEvent) -> void:
		if not InputContext.is_active(InputContextStack.Context.GAMEPLAY):
			return
		if event.is_action_pressed(InputActions.FIRE_PRIMARY):
			get_viewport().set_input_as_handled()
			shot_fired.emit()


## Stand-in for Save/Load quicksave handler.
class SaveLoadFixture extends Node:
	signal save_triggered

	func _unhandled_input(event: InputEvent) -> void:
		if not InputContext.is_active(InputContextStack.Context.GAMEPLAY):
			return
		if event.is_action_pressed(InputActions.QUICKSAVE):
			get_viewport().set_input_as_handled()
			save_triggered.emit()


# ── Helpers ───────────────────────────────────────────────────────────────────

func _reset_context() -> void:
	while InputContext.current() != InputContextStack.Context.GAMEPLAY:
		InputContext.pop()  # dismiss-order-ok: test cleanup helper.


func _make_action_event(physical_keycode: Key) -> InputEventKey:
	var ev: InputEventKey = InputEventKey.new()
	ev.physical_keycode = physical_keycode
	ev.pressed = true
	return ev


func before_test() -> void:
	_reset_context()


func after_test() -> void:
	_reset_context()


# ── LOADING enum presence ────────────────────────────────────────────────────

func test_loading_enum_value_resolves_without_error() -> void:
	# If this assertion runs at all, LOADING resolves at parse time.
	assert_int(InputContextStack.Context.LOADING).override_failure_message(
		"BLOCKING: InputContextStack.Context.LOADING must be present in the enum (ADR-0004 Amendment A6)."
	).is_greater_equal(0)


func test_push_loading_executes_without_crash() -> void:
	InputContext.push(InputContextStack.Context.LOADING)
	assert_int(int(InputContext.current())).override_failure_message(
		"BLOCKING: push(LOADING) must succeed and update current() to LOADING."
	).is_equal(InputContextStack.Context.LOADING)


# ── AC-8.1: LOADING gates fire_primary ──────────────────────────────────────

func test_fire_primary_does_not_fire_during_loading() -> void:
	# Arrange — fixtures in scene
	var lvl: LevelStreamingFixture = LevelStreamingFixture.new()
	add_child(lvl)
	auto_free(lvl)
	var combat: CombatFixture = CombatFixture.new()
	add_child(combat)
	auto_free(combat)

	var shot_count: Array[int] = [0]
	var on_shot: Callable = func(): shot_count[0] += 1
	combat.shot_fired.connect(on_shot)

	# Act — push LOADING, attempt fire_primary
	lvl.enter_loading()
	assert_int(int(InputContext.current())).is_equal(InputContextStack.Context.LOADING)

	# Build a fire_primary event (action mapping resolves it via is_action_pressed)
	# Use mouse-button left which is fire_primary's KB binding per project.godot.
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	combat._unhandled_input(ev)

	combat.shot_fired.disconnect(on_shot)

	# Assert — handler did not fire (is_active(GAMEPLAY) gate rejected)
	assert_int(shot_count[0]).override_failure_message(
		"AC-8.1: fire_primary must NOT execute during LOADING. Got %d." % shot_count[0]
	).is_equal(0)


# ── AC-8.1: LOADING gates quicksave ─────────────────────────────────────────

func test_quicksave_does_not_fire_during_loading() -> void:
	var lvl: LevelStreamingFixture = LevelStreamingFixture.new()
	add_child(lvl)
	auto_free(lvl)
	var save_load: SaveLoadFixture = SaveLoadFixture.new()
	add_child(save_load)
	auto_free(save_load)

	var save_count: Array[int] = [0]
	var on_save: Callable = func(): save_count[0] += 1
	save_load.save_triggered.connect(on_save)

	lvl.enter_loading()

	# F5 keypress (project.godot binds F5 to quicksave)
	save_load._unhandled_input(_make_action_event(KEY_F5))

	save_load.save_triggered.disconnect(on_save)

	assert_int(save_count[0]).override_failure_message(
		"AC-8.1: quicksave must NOT execute during LOADING. Got %d." % save_count[0]
	).is_equal(0)


# ── AC-8.1: handlers fire normally after LOADING is popped ──────────────────

func test_handlers_fire_normally_after_loading_pop() -> void:
	var lvl: LevelStreamingFixture = LevelStreamingFixture.new()
	add_child(lvl)
	auto_free(lvl)
	var combat: CombatFixture = CombatFixture.new()
	add_child(combat)
	auto_free(combat)

	var shot_count: Array[int] = [0]
	var on_shot: Callable = func(): shot_count[0] += 1
	combat.shot_fired.connect(on_shot)

	# Push then pop LOADING
	lvl.enter_loading()
	lvl.exit_loading()
	assert_int(int(InputContext.current())).override_failure_message(
		"AC-8.1: pop must return to GAMEPLAY after exit_loading."
	).is_equal(InputContextStack.Context.GAMEPLAY)

	# Now fire_primary should work
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	combat._unhandled_input(ev)

	combat.shot_fired.disconnect(on_shot)

	assert_int(shot_count[0]).override_failure_message(
		"AC-8.1: fire_primary must execute after LOADING is popped. Got %d." % shot_count[0]
	).is_equal(1)


# ── AC-8.1: ui_context_changed signal fires on LOADING push/pop ─────────────

func test_ui_context_changed_emits_on_loading_push_and_pop() -> void:
	var lvl: LevelStreamingFixture = LevelStreamingFixture.new()
	add_child(lvl)
	auto_free(lvl)

	var transitions: Array[Vector2i] = []
	var on_changed: Callable = func(new_ctx: int, old_ctx: int):
		transitions.append(Vector2i(old_ctx, new_ctx))
	Events.ui_context_changed.connect(on_changed)

	lvl.enter_loading()
	lvl.exit_loading()

	Events.ui_context_changed.disconnect(on_changed)

	# Expect 2 transitions: GAMEPLAY → LOADING and LOADING → GAMEPLAY
	assert_int(transitions.size()).is_equal(2)
	assert_bool(transitions[0] == Vector2i(InputContextStack.Context.GAMEPLAY, InputContextStack.Context.LOADING)).override_failure_message(
		"AC-8.1: first transition must be GAMEPLAY → LOADING."
	).is_true()
	assert_bool(transitions[1] == Vector2i(InputContextStack.Context.LOADING, InputContextStack.Context.GAMEPLAY)).override_failure_message(
		"AC-8.1: second transition must be LOADING → GAMEPLAY."
	).is_true()
