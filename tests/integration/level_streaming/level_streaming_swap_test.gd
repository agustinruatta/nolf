# tests/integration/level_streaming/level_streaming_swap_test.gd
#
# LevelStreamingSwapTest — GdUnit4 integration suite for Story LS-002.
#
# Covers:
#   AC-1, AC-2 (sync push + state machine entry)
#   AC-3, AC-4, AC-5 (state machine progression FADING_OUT → SWAPPING → FADING_IN → IDLE)
#   AC-6, AC-7 (section_exited emit at step 3 with valid scene; section_entered at step 10)
#   AC-8, AC-9, AC-10 (full plaza → stub_b round trip + signal payloads + clean state)
#
# GATE STATUS
#   Story LS-002 | Logic + Integration → BLOCKING gate.
#   TR-LS-005, TR-LS-007, TR-LS-009, TR-LS-011.

class_name LevelStreamingSwapTest
extends GdUnitTestSuite

var _exited_args: Array = []
var _entered_args: Array = []


func before_test() -> void:
	# Reset LSS state if a prior test left it transitioning.
	if LevelStreamingService.is_transitioning():
		# Wait up to 2 s for any in-flight transition to complete.
		var elapsed: float = 0.0
		while LevelStreamingService.is_transitioning() and elapsed < 2.0:
			await get_tree().process_frame
			elapsed += get_process_delta_time()

	_exited_args = []
	_entered_args = []
	if not Events.section_exited.is_connected(_on_section_exited):
		Events.section_exited.connect(_on_section_exited)
	if not Events.section_entered.is_connected(_on_section_entered):
		Events.section_entered.connect(_on_section_entered)


func after_test() -> void:
	if Events.section_exited.is_connected(_on_section_exited):
		Events.section_exited.disconnect(_on_section_exited)
	if Events.section_entered.is_connected(_on_section_entered):
		Events.section_entered.disconnect(_on_section_entered)


func _on_section_exited(section_id: StringName, reason: int) -> void:
	_exited_args.append({"section_id": section_id, "reason": reason})


func _on_section_entered(section_id: StringName, reason: int) -> void:
	_entered_args.append({"section_id": section_id, "reason": reason})


# ── AC-1 + AC-2: sync push + FADING_OUT entry on the same call frame ────────

func test_transition_to_section_pushes_loading_and_enters_fading_out_synchronously() -> void:
	if not LevelStreamingService.has_valid_registry():
		return  # cannot test without registry

	# Pre-condition: not transitioning, no LOADING context.
	assert_bool(LevelStreamingService.is_transitioning()).is_false()
	assert_bool(InputContext.is_active(InputContext.Context.LOADING)).is_false()

	LevelStreamingService.transition_to_section(
		&"plaza", null, LevelStreamingService.TransitionReason.NEW_GAME
	)

	# Post: same call frame, BEFORE any await.
	assert_bool(LevelStreamingService.is_transitioning()).override_failure_message(
		"_transitioning must be true on the SAME frame as transition_to_section."
	).is_true()
	assert_bool(InputContext.is_active(InputContext.Context.LOADING)).override_failure_message(
		"InputContext.LOADING must be on stack on the SAME frame as transition_to_section."
	).is_true()
	assert_int(LevelStreamingService.get_state()).override_failure_message(
		"State must be FADING_OUT on the same call frame."
	).is_equal(LevelStreamingService.State.FADING_OUT)

	# Wait for transition to complete so other tests start clean.
	await _wait_for_idle(2.0)


# ── AC-3, AC-4, AC-5: full state-machine progression ────────────────────────

func test_full_state_machine_progression_idle_to_idle() -> void:
	if not LevelStreamingService.has_valid_registry():
		return
	LevelStreamingService.transition_to_section(
		&"plaza", null, LevelStreamingService.TransitionReason.NEW_GAME
	)

	# Wait until SWAPPING.
	var saw_swapping: bool = await _wait_for_state(LevelStreamingService.State.SWAPPING, 2.0)
	assert_bool(saw_swapping).override_failure_message(
		"State must reach SWAPPING within 2 s. Current: %d" % LevelStreamingService.get_state()
	).is_true()

	# Wait until FADING_IN.
	var saw_fading_in: bool = await _wait_for_state(LevelStreamingService.State.FADING_IN, 2.0)
	assert_bool(saw_fading_in).override_failure_message(
		"State must reach FADING_IN within 2 s."
	).is_true()

	# Wait until IDLE.
	await _wait_for_idle(2.0)

	assert_int(LevelStreamingService.get_state()).is_equal(LevelStreamingService.State.IDLE)
	assert_bool(LevelStreamingService.is_transitioning()).is_false()
	assert_bool(InputContext.is_active(InputContext.Context.LOADING)).override_failure_message(
		"InputContext.LOADING must be popped after transition completes."
	).is_false()
	# Fade overlay alpha back to 0.
	var rect: ColorRect = LevelStreamingService.get_fade_overlay().get_node("FadeRect") as ColorRect
	assert_float(rect.color.a).override_failure_message(
		"Fade rect alpha must return to 0.0 after FADING_IN. Got: %f" % rect.color.a
	).is_equal_approx(0.0, 0.001)


# ── AC-6 + AC-7: signal emission + AC-8 + AC-9: full plaza → stub_b round trip ─

func test_full_round_trip_plaza_to_stub_b_emits_both_signals() -> void:
	if not LevelStreamingService.has_valid_registry():
		return

	# Step 1: load plaza first (NEW_GAME from boot).
	LevelStreamingService.transition_to_section(
		&"plaza", null, LevelStreamingService.TransitionReason.NEW_GAME
	)
	await _wait_for_idle(2.0)

	# Reset signal recorders.
	_exited_args = []
	_entered_args = []

	# Step 2: now transition plaza → stub_b.
	LevelStreamingService.transition_to_section(
		&"stub_b", null, LevelStreamingService.TransitionReason.NEW_GAME
	)
	await _wait_for_idle(3.0)

	# AC-9: section_exited fired with (plaza, NEW_GAME).
	assert_int(_exited_args.size()).override_failure_message(
		"section_exited must fire exactly once. Got: %d" % _exited_args.size()
	).is_equal(1)
	assert_str(String(_exited_args[0]["section_id"])).is_equal("plaza")
	assert_int(_exited_args[0]["reason"]).is_equal(LevelStreamingService.TransitionReason.NEW_GAME)

	# AC-9: section_entered fired with (stub_b, NEW_GAME).
	assert_int(_entered_args.size()).override_failure_message(
		"section_entered must fire exactly once. Got: %d" % _entered_args.size()
	).is_equal(1)
	assert_str(String(_entered_args[0]["section_id"])).is_equal("stub_b")
	assert_int(_entered_args[0]["reason"]).is_equal(LevelStreamingService.TransitionReason.NEW_GAME)

	# AC-8: current_section_id is now stub_b.
	assert_str(String(LevelStreamingService.get_current_section_id())).override_failure_message(
		"current_section_id must be 'stub_b' after the swap."
	).is_equal("stub_b")

	# AC-10: clean state.
	assert_bool(LevelStreamingService.is_transitioning()).is_false()
	assert_bool(InputContext.is_active(InputContext.Context.LOADING)).is_false()


# ── Failure path: invalid section_id ─────────────────────────────────────────

func test_transition_to_unknown_section_aborts_cleanly() -> void:
	if not LevelStreamingService.has_valid_registry():
		return

	# Wait for any prior test's transition to settle.
	await _wait_for_idle(2.0)

	LevelStreamingService.transition_to_section(
		&"section_that_does_not_exist", null, LevelStreamingService.TransitionReason.NEW_GAME
	)

	# Wait for the abort to settle.
	var elapsed: float = 0.0
	while (LevelStreamingService.is_transitioning() or LevelStreamingService.get_state() != LevelStreamingService.State.IDLE) and elapsed < 2.0:
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	assert_int(LevelStreamingService.get_state()).override_failure_message(
		"Unknown section must abort and return to IDLE. Got state: %d" % LevelStreamingService.get_state()
	).is_equal(LevelStreamingService.State.IDLE)
	assert_bool(LevelStreamingService.is_transitioning()).is_false()
	assert_bool(InputContext.is_active(InputContext.Context.LOADING)).override_failure_message(
		"After abort, LOADING context must NOT be on the stack."
	).is_false()


# ── Helpers ──────────────────────────────────────────────────────────────────

## Polls the SceneTree until LSS reaches IDLE (or timeout).
func _wait_for_idle(timeout_sec: float) -> void:
	var elapsed: float = 0.0
	while LevelStreamingService.is_transitioning() and elapsed < timeout_sec:
		await get_tree().process_frame
		elapsed += get_process_delta_time()


## Polls the SceneTree until LSS state matches `target`. Returns true if seen.
func _wait_for_state(target: LevelStreamingService.State, timeout_sec: float) -> bool:
	var elapsed: float = 0.0
	while LevelStreamingService.get_state() != target and elapsed < timeout_sec:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		# If we passed through the target without seeing it (state moved on),
		# return false.
		if LevelStreamingService.get_state() != target and not LevelStreamingService.is_transitioning():
			return false
	return LevelStreamingService.get_state() == target
