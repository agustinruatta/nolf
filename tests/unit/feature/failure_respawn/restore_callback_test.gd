# tests/unit/feature/failure_respawn/restore_callback_test.gd
#
# RestoreCallbackTest — GdUnit4 tests for Story FR-005.
# Verifies LS step-9 restore callback body: position application,
# reset_for_respawn invocation, InputContext pop, RESTORING → IDLE.

class_name RestoreCallbackTest
extends GdUnitTestSuite


# ── Inner doubles ─────────────────────────────────────────────────────────────

## Stub PlayerCharacter — Node3D with reset_for_respawn method.
class _PCDouble extends Node3D:
	var reset_call_count: int = 0
	var last_position_at_reset: Vector3 = Vector3.ZERO

	func reset_for_respawn() -> void:
		reset_call_count += 1
		last_position_at_reset = global_position


# ── Setup / teardown ──────────────────────────────────────────────────────────

func after_test() -> void:
	while InputContext.current() != InputContextStack.Context.GAMEPLAY:
		InputContext.pop() # dismiss-order-ok: test fixture cleanup, no real input event


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_service_with_pc_and_checkpoint(
	respawn_pos: Vector3
) -> Array:
	var svc: FailureRespawnService = FailureRespawnService.new()
	auto_free(svc)
	var pc: _PCDouble = _PCDouble.new()
	auto_free(pc)
	add_child(pc)
	svc._inject_player_character(pc)
	var cp: Checkpoint = Checkpoint.new()
	cp.respawn_position = respawn_pos
	cp.section_id = &"plaza"
	svc._current_checkpoint = cp
	svc._flow_state = FailureRespawnService.FlowState.RESTORING
	return [svc, pc]


# ── Tests ──────────────────────────────────────────────────────────────────────

## AC-1: PlayerCharacter teleported to checkpoint position before reset.
func test_restore_callback_applies_checkpoint_position() -> void:
	var bundle: Array = _make_service_with_pc_and_checkpoint(Vector3(10.0, 0.5, -5.0))
	var svc: FailureRespawnService = bundle[0]
	var pc: _PCDouble = bundle[1]

	svc._on_ls_restore(&"plaza", null, LevelStreamingService.TransitionReason.RESPAWN)

	var dist: float = pc.global_position.distance_to(Vector3(10.0, 0.5, -5.0))
	assert_float(dist).is_less(0.01)


## AC-2: reset_for_respawn called exactly once on the PlayerCharacter.
func test_restore_callback_calls_reset_for_respawn() -> void:
	var bundle: Array = _make_service_with_pc_and_checkpoint(Vector3.ZERO)
	var svc: FailureRespawnService = bundle[0]
	var pc: _PCDouble = bundle[1]

	svc._on_ls_restore(&"plaza", null, LevelStreamingService.TransitionReason.RESPAWN)

	assert_int(pc.reset_call_count).is_equal(1)


## AC-3: position applied BEFORE reset_for_respawn (so reset sees the new pos).
func test_restore_callback_applies_position_before_reset() -> void:
	var bundle: Array = _make_service_with_pc_and_checkpoint(Vector3(7.0, 0.0, 0.0))
	var svc: FailureRespawnService = bundle[0]
	var pc: _PCDouble = bundle[1]

	svc._on_ls_restore(&"plaza", null, LevelStreamingService.TransitionReason.RESPAWN)

	# last_position_at_reset captured pc.global_position at the moment reset_for_respawn ran.
	var dist: float = pc.last_position_at_reset.distance_to(Vector3(7.0, 0.0, 0.0))
	assert_float(dist).is_less(0.01)


## AC-4: InputContext.LOADING popped after restore.
func test_restore_callback_pops_loading_input_context() -> void:
	var bundle: Array = _make_service_with_pc_and_checkpoint(Vector3.ZERO)
	var svc: FailureRespawnService = bundle[0]

	# Simulate FR-002's push.
	InputContext.push(InputContextStack.Context.LOADING)
	assert_int(InputContext.current()).is_equal(InputContextStack.Context.LOADING)

	svc._on_ls_restore(&"plaza", null, LevelStreamingService.TransitionReason.RESPAWN)

	# Should be back to GAMEPLAY (the base of the stack).
	assert_int(InputContext.current()).is_equal(InputContextStack.Context.GAMEPLAY)


## AC-5: _flow_state transitions RESTORING → IDLE.
func test_restore_callback_transitions_to_idle() -> void:
	var bundle: Array = _make_service_with_pc_and_checkpoint(Vector3.ZERO)
	var svc: FailureRespawnService = bundle[0]

	svc._on_ls_restore(&"plaza", null, LevelStreamingService.TransitionReason.RESPAWN)

	assert_int(svc._flow_state).is_equal(FailureRespawnService.FlowState.IDLE)


## AC-6: Non-RESPAWN reasons are dropped (FORWARD/NEW_GAME/LOAD_FROM_SAVE handled by FR-004).
func test_restore_callback_drops_non_respawn_reason() -> void:
	var bundle: Array = _make_service_with_pc_and_checkpoint(Vector3(10.0, 0.0, 0.0))
	var svc: FailureRespawnService = bundle[0]
	var pc: _PCDouble = bundle[1]

	svc._on_ls_restore(&"plaza", null, LevelStreamingService.TransitionReason.FORWARD)

	# State unchanged; reset NOT called.
	assert_int(svc._flow_state).is_equal(FailureRespawnService.FlowState.RESTORING)
	assert_int(pc.reset_call_count).is_equal(0)


## AC-7: E.27 — spurious RESPAWN callback while IDLE is dropped silently.
func test_restore_callback_drops_spurious_callback_while_idle() -> void:
	var svc: FailureRespawnService = FailureRespawnService.new()
	auto_free(svc)
	# _flow_state defaults to IDLE.

	# Should not crash, should not transition.
	svc._on_ls_restore(&"plaza", null, LevelStreamingService.TransitionReason.RESPAWN)

	assert_int(svc._flow_state).is_equal(FailureRespawnService.FlowState.IDLE)


## AC-8: E.9 — null checkpoint handled gracefully (no crash, no position write).
func test_restore_callback_null_checkpoint_does_not_crash() -> void:
	var svc: FailureRespawnService = FailureRespawnService.new()
	auto_free(svc)
	var pc: _PCDouble = _PCDouble.new()
	auto_free(pc)
	add_child(pc)
	pc.global_position = Vector3(99.0, 99.0, 99.0)
	svc._inject_player_character(pc)
	# _current_checkpoint stays null.
	svc._flow_state = FailureRespawnService.FlowState.RESTORING

	svc._on_ls_restore(&"plaza", null, LevelStreamingService.TransitionReason.RESPAWN)

	# pc position unchanged (LS would have already positioned the player at section's entry point).
	assert_float(pc.global_position.distance_to(Vector3(99.0, 99.0, 99.0))).is_less(0.01)
	# reset_for_respawn still called.
	assert_int(pc.reset_call_count).is_equal(1)
	# Flow completes.
	assert_int(svc._flow_state).is_equal(FailureRespawnService.FlowState.IDLE)
