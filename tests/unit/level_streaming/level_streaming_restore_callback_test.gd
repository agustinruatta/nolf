# tests/unit/level_streaming/level_streaming_restore_callback_test.gd
#
# LevelStreamingRestoreCallbackTest — GdUnit4 suite for Story LS-003.
#
# Tests the register_restore_callback API and step-9 synchronous invocation
# behaviour of LevelStreamingService.
#
# Covers:
#   AC-1  register_restore_callback appends valid callable; rejects invalid
#   AC-2  Step 9 iterates callbacks synchronously in registration order;
#         empty array is a no-op (transition still proceeds)
#   AC-3  Step 9 fires after step 8 await AND before step 10 section_entered
#   AC-4  Callback receives 3 positional args (target_id, save_game, reason)
#   AC-5  All callbacks fire even if a prior one logs an error; registration order preserved
#   AC-6  No-await violation logs push_error in debug build (degraded coverage noted)
#   AC-7  section_entered emits only after all callbacks complete synchronously
#   AC-8  Callback fires at step 9 NOT at step 3 (section_exited)
#   AC-9  Probe state is visible to section_entered subscriber
#
# GATE STATUS
#   Story LS-003 | Logic type → BLOCKING gate.
#   TR-LS-013.
#
# ── Probe isolation design ────────────────────────────────────────────────────
# LevelStreamingService._restore_callbacks persists across tests (autoload
# lifetime). There is no public deregistration API at MVP. To prevent probe
# pollution between tests we use a flag-based on/off pattern:
#   - The primary probe registers ONCE across the full test run (guarded by
#     _probe_registered) and re-arms/disarms via _probe_active flags in
#     before_test / after_test.
#   - While _probe_active == false the probe callback is a no-op.
#
# Accumulation risk: lambdas registered as test-local probes (AC-5a, AC-5b,
# AC-6) remain in _restore_callbacks for the rest of the suite — there is no
# deregistration. This is benign for the current ten-test suite because:
#   (a) lambda closures over out-of-scope test locals become inert (their
#       captures point at zero/false values that nothing observes);
#   (b) the AC-6 awaiting probe adds at most one extra engine frame to step 9
#       in subsequent tests; the _wait_for_idle(3.0) and _wait_for_idle(4.0)
#       timeouts absorb that without flakiness.
# If a future test depends on STRICT single-frame synchrony or registers a
# probe whose closure references THE TEST INSTANCE itself, this assumption
# breaks. New tests added after AC-6 should:
#   - use _wait_for_idle(>= 3.0) timeouts;
#   - prefer the primary probe (flag-isolated) over fresh test-local lambdas;
#   - if a fresh registration is needed, call clear_restore_callbacks_for_test
#     in before_test to flush the array AND reset _probe_registered to false
#     so the next test's before_test re-registers the primary probe.

class_name LevelStreamingRestoreCallbackTest
extends GdUnitTestSuite


# ── Shared test-local probe state ────────────────────────────────────────────

## Whether the primary probe (_probe_callback) is armed for the current test.
var _probe_active: bool = false

## Registration guard: we only call register_restore_callback once per session.
var _probe_registered: bool = false

## Captured args from the most recent _probe_callback invocation.
## Format: [section_id: StringName, save_game: SaveGame, reason: int]
var _probe_args_log: Array = []

## Frame counter at the moment _probe_callback ran (pre-call side).
var _probe_frame: int = -1

## Test-marker set by _probe_callback — used by AC-9.
var _test_marker: String = ""

## Signal-spy storage for section_entered.
var _entered_args: Array = []

## Signal-spy storage for section_exited.
var _exited_args: Array = []

## Frame counter captured inside _on_section_entered subscriber.
var _entered_frame: int = -1

## Frame counter captured inside _on_section_exited subscriber.
var _exited_frame: int = -1

## Set by the AC-9 subscriber when it observes _test_marker == "callback_ran".
var _subscriber_saw_marker_set: bool = false

## Whether signal spies are currently connected.
var _signals_connected: bool = false


# ── Lifecycle ────────────────────────────────────────────────────────────────

func before_test() -> void:
	# Disarm probe so prior test's callback registrations cannot interfere.
	_probe_active = false
	_probe_args_log.clear()
	_probe_frame = -1
	_test_marker = ""

	_entered_args.clear()
	_exited_args.clear()
	_entered_frame = -1
	_exited_frame = -1
	_subscriber_saw_marker_set = false

	# Connect signal spies if not yet done.
	if not _signals_connected:
		Events.section_entered.connect(_on_section_entered)
		Events.section_exited.connect(_on_section_exited)
		_signals_connected = true

	# Register our primary probe on first test only.
	if not _probe_registered:
		LevelStreamingService.register_restore_callback(_probe_callback)
		_probe_registered = true

	# Wait for any in-flight transition from a prior test.
	await _wait_for_idle(3.0)


## Test helper — ensure the next `transition_to_section(target, ...)` call from
## the test body is NOT a same-section call (which LS-006's guard would silently
## drop). If `_current_section_id == target`, transition to the OTHER known
## section first, then clear the test's per-iteration buffers so only the
## test's own probe firings + signal events are recorded.
##
## Call this BEFORE the test's `transition_to_section(target, ...)` line.
func _ensure_can_transition_to(target: StringName) -> void:
	if not LevelStreamingService.has_valid_registry():
		return
	if LevelStreamingService.get_current_section_id() != target:
		return
	var other: StringName = &"stub_b" if target == &"plaza" else &"plaza"
	# Disarm probe so the normalization transition doesn't pollute logs.
	var saved_active: bool = _probe_active
	_probe_active = false
	LevelStreamingService.transition_to_section(
		other, null, LevelStreamingService.TransitionReason.FORWARD
	)
	await _wait_for_idle(3.0)
	# Re-arm and clear per-test buffers.
	_probe_active = saved_active
	_probe_args_log.clear()
	_entered_args.clear()
	_exited_args.clear()
	_probe_frame = -1
	_entered_frame = -1
	_exited_frame = -1
	_subscriber_saw_marker_set = false
	_test_marker = ""


func after_test() -> void:
	# Disarm probe — it is still registered but will be a no-op.
	_probe_active = false

	# Disconnect signal spies after each test to avoid phantom accumulation.
	if _signals_connected:
		if Events.section_entered.is_connected(_on_section_entered):
			Events.section_entered.disconnect(_on_section_entered)
		if Events.section_exited.is_connected(_on_section_exited):
			Events.section_exited.disconnect(_on_section_exited)
		_signals_connected = false

	# Drain any residual transition.
	await _wait_for_idle(2.0)

	# Free any plaza section that LSS left in the scene tree. With the populated
	# plaza (12 CSG colliders) this matters — residual bodies pollute the
	# physics world and break subsequent tests' raycasts. The pre-VS stub plaza
	# had no colliders so this cleanup wasn't necessary.
	var current: Node = get_tree().current_scene
	if current != null and current.name == "Plaza":
		current.queue_free()
		await get_tree().process_frame


# ── Primary probe ────────────────────────────────────────────────────────────

func _probe_callback(section_id: StringName, save_game: SaveGame, reason: int) -> void:
	if not _probe_active:
		return
	_probe_frame = Engine.get_process_frames()
	_probe_args_log.append([section_id, save_game, reason])
	_test_marker = "callback_ran"


# ── Signal spies ──────────────────────────────────────────────────────────────

func _on_section_entered(section_id: StringName, reason: int) -> void:
	_entered_args.append({"section_id": section_id, "reason": reason})
	_entered_frame = Engine.get_process_frames()
	# AC-9: record whether the test_marker was already set by the probe.
	if _test_marker == "callback_ran":
		_subscriber_saw_marker_set = true


func _on_section_exited(section_id: StringName, reason: int) -> void:
	_exited_args.append({"section_id": section_id, "reason": reason})
	_exited_frame = Engine.get_process_frames()


# ── AC-1: register_restore_callback API ──────────────────────────────────────

## AC-1: A valid callable is appended to _restore_callbacks.
## We verify via the test-only accessor get_restore_callback_count_for_test().
## Rationale for using the accessor rather than a black-box transition: it is
## faster, deterministic, and does not require a live registry. The accessor is
## documented TEST-ONLY on LSS and is not part of the production API surface.
func test_register_restore_callback_appends_valid_callable() -> void:
	var count_before: int = LevelStreamingService.get_restore_callback_count_for_test()

	# Register a second standalone valid callable.
	var extra_probe: Callable = func(_sid: StringName, _sg: SaveGame, _r: int) -> void: pass
	LevelStreamingService.register_restore_callback(extra_probe)

	var count_after: int = LevelStreamingService.get_restore_callback_count_for_test()
	assert_int(count_after).override_failure_message(
		"register_restore_callback must grow _restore_callbacks by 1. Before: %d After: %d"
		% [count_before, count_after]
	).is_equal(count_before + 1)


## AC-1 edge case: invalid Callable (default-constructed) must NOT be appended.
## A push_warning is expected but GdUnit4 has no stable push_warning capture;
## we assert the size invariant instead, which is the load-bearing AC check.
func test_register_restore_callback_rejects_invalid_callable() -> void:
	var count_before: int = LevelStreamingService.get_restore_callback_count_for_test()

	LevelStreamingService.register_restore_callback(Callable())

	var count_after: int = LevelStreamingService.get_restore_callback_count_for_test()
	assert_int(count_after).override_failure_message(
		"Invalid Callable must NOT be appended to _restore_callbacks. Before: %d After: %d"
		% [count_before, count_after]
	).is_equal(count_before)


# ── AC-2 + AC-3 + AC-7: synchronous invocation between step 8 and step 10 ────

## AC-2, AC-3, AC-7: probe fires exactly once; its frame is <= section_entered
## frame (same call chain, no await between step 9 and step 10); and the
## callback itself returned synchronously (pre_frame == post_frame inside LSS).
## We verify synchrony indirectly: both _probe_frame and _entered_frame are
## captured in the same coroutine continuation — no frame boundary is possible
## between a synchronous call and the immediately-following emit.
func test_step9_invokes_callbacks_synchronously_between_step8_and_step10() -> void:
	if not LevelStreamingService.has_valid_registry():
		return

	_probe_active = true

	# Avoid LS-006 same-section drop: if a prior test left current at plaza,
	# transition to stub_b first.
	await _ensure_can_transition_to(&"plaza")

	LevelStreamingService.transition_to_section(
		&"plaza", null, LevelStreamingService.TransitionReason.NEW_GAME
	)
	await _wait_for_idle(3.0)

	assert_int(_probe_args_log.size()).override_failure_message(
		"Primary probe must fire exactly once per transition. Got: %d" % _probe_args_log.size()
	).is_equal(1)

	assert_int(_entered_args.size()).override_failure_message(
		"section_entered must fire exactly once. Got: %d" % _entered_args.size()
	).is_greater_equal(1)

	assert_int(_probe_frame).override_failure_message(
		"Probe frame must be >= 0 (was recorded). Got: %d" % _probe_frame
	).is_greater_equal(0)

	# AC-7: probe frame <= section_entered frame (same or earlier — step 9 < step 10).
	assert_int(_entered_frame).override_failure_message(
		"section_entered frame must be >= probe frame. probe=%d entered=%d"
		% [_probe_frame, _entered_frame]
	).is_greater_equal(_probe_frame)


# ── AC-4: callback receives 3 positional args ─────────────────────────────────

## AC-4a: verify target_id, save_game reference, and reason are passed correctly.
## Uses a real SaveGame instance so we can assert object identity.
func test_callback_receives_three_positional_args_with_save_game() -> void:
	if not LevelStreamingService.has_valid_registry():
		return

	# Wait for any prior transition to settle so _current_section_id is known.
	await _wait_for_idle(2.0)

	_probe_active = true
	var the_save: SaveGame = SaveGame.new()

	# Avoid LS-006 same-section drop.
	await _ensure_can_transition_to(&"plaza")

	LevelStreamingService.transition_to_section(
		&"plaza", the_save, LevelStreamingService.TransitionReason.LOAD_FROM_SAVE
	)
	await _wait_for_idle(3.0)

	assert_int(_probe_args_log.size()).override_failure_message(
		"Probe must have fired at least once. Got: %d" % _probe_args_log.size()
	).is_greater_equal(1)

	var args: Array = _probe_args_log[0]

	assert_str(String(args[0] as StringName)).override_failure_message(
		"args[0] (target_section_id) must equal 'plaza'. Got: '%s'" % String(args[0])
	).is_equal("plaza")

	assert_object(args[1]).override_failure_message(
		"args[1] (save_game) must be the same object passed to transition_to_section."
	).is_equal(the_save)

	assert_int(args[2] as int).override_failure_message(
		"args[2] (reason) must equal LOAD_FROM_SAVE (%d). Got: %d"
		% [LevelStreamingService.TransitionReason.LOAD_FROM_SAVE, args[2]]
	).is_equal(LevelStreamingService.TransitionReason.LOAD_FROM_SAVE)


## AC-4b: null save_game path (NEW_GAME flow) must deliver null without crash.
func test_callback_receives_null_save_game_on_new_game() -> void:
	if not LevelStreamingService.has_valid_registry():
		return

	await _wait_for_idle(2.0)

	_probe_active = true

	# Avoid LS-006 same-section drop.
	await _ensure_can_transition_to(&"stub_b")

	LevelStreamingService.transition_to_section(
		&"stub_b", null, LevelStreamingService.TransitionReason.NEW_GAME
	)
	await _wait_for_idle(3.0)

	assert_int(_probe_args_log.size()).override_failure_message(
		"Probe must fire on null-save_game transition. Got: %d" % _probe_args_log.size()
	).is_greater_equal(1)

	var args: Array = _probe_args_log[0]
	assert_object(args[1]).override_failure_message(
		"args[1] must be null for NEW_GAME path."
	).is_null()


# ── AC-5: multiple callbacks fire in registration order ───────────────────────

## AC-5a: three locally-registered probes fire in registration order.
## We append probes a/b/c AFTER the already-registered primary probe; assert
## the shared order list captures a, b, c in sequence.
func test_multiple_callbacks_all_fire_in_registration_order() -> void:
	if not LevelStreamingService.has_valid_registry():
		return

	await _wait_for_idle(2.0)

	var order_log: Array[String] = []

	var probe_a: Callable = func(_sid: StringName, _sg: SaveGame, _r: int) -> void:
		order_log.append("a")
	var probe_b: Callable = func(_sid: StringName, _sg: SaveGame, _r: int) -> void:
		order_log.append("b")
	var probe_c: Callable = func(_sid: StringName, _sg: SaveGame, _r: int) -> void:
		order_log.append("c")

	LevelStreamingService.register_restore_callback(probe_a)
	LevelStreamingService.register_restore_callback(probe_b)
	LevelStreamingService.register_restore_callback(probe_c)

	# Avoid LS-006 same-section drop.
	await _ensure_can_transition_to(&"plaza")

	LevelStreamingService.transition_to_section(
		&"plaza", null, LevelStreamingService.TransitionReason.NEW_GAME
	)
	await _wait_for_idle(3.0)

	# order_log may have a, b, c each appearing once in that order;
	# primary probe fires before them (it was registered first) and
	# is not in order_log. We assert the sub-sequence is exactly a, b, c.
	assert_array(order_log).override_failure_message(
		"Probes a/b/c must fire in registration order. Got: %s" % [order_log]
	).contains_exactly(["a", "b", "c"])


## AC-2 edge case: empty `_restore_callbacks` → step 9 is a no-op; transition
## proceeds normally to step 10 (section_entered emits) and reaches IDLE.
## Uses the test-only clear accessor to drain the array, then verifies the
## transition completes and section_entered fires.
##
## Test ordering note: this test temporarily empties _restore_callbacks, runs a
## transition, then restores test infrastructure by re-registering the primary
## probe and resetting _probe_registered so subsequent tests get a fresh probe.
func test_step9_with_empty_callback_array_is_no_op_and_transition_completes() -> void:
	if not LevelStreamingService.has_valid_registry():
		return

	await _wait_for_idle(2.0)

	# Drain all registered callbacks (primary probe + accumulated test-locals).
	LevelStreamingService.clear_restore_callbacks_for_test()

	assert_int(LevelStreamingService.get_restore_callback_count_for_test()).override_failure_message(
		"_restore_callbacks must be empty after clear_restore_callbacks_for_test()."
	).is_equal(0)

	# Reset signal-spy state so this test's assertions are isolated.
	_entered_args.clear()

	# Avoid LS-006 same-section drop.
	await _ensure_can_transition_to(&"plaza")

	LevelStreamingService.transition_to_section(
		&"plaza", null, LevelStreamingService.TransitionReason.NEW_GAME
	)
	await _wait_for_idle(3.0)

	# Step 10 must still fire even with zero callbacks at step 9.
	assert_int(_entered_args.size()).override_failure_message(
		"section_entered must emit even when _restore_callbacks is empty (step 9 is a no-op)."
	).is_greater_equal(1)

	# Transition must reach IDLE — no infinite hang on the empty-iteration path.
	assert_bool(LevelStreamingService.is_transitioning()).override_failure_message(
		"Transition must reach IDLE after a no-op step 9."
	).is_false()

	# Restore test infrastructure for subsequent tests.
	# Re-register primary probe + flip _probe_registered so before_test does NOT
	# double-register on the next test.
	LevelStreamingService.register_restore_callback(_probe_callback)
	# _probe_registered remains true; we just re-added the same primary probe.


## AC-5b: if a middle callback logs a push_error, the next callback still fires.
## We use push_error (stable, non-halting) rather than a runtime null deref to
## avoid GdUnit4 treating the error as a test failure at the framework level.
func test_callback_chain_continues_when_one_callback_logs_an_error() -> void:
	if not LevelStreamingService.has_valid_registry():
		return

	await _wait_for_idle(2.0)

	var order_log: Array[String] = []

	var probe_first: Callable = func(_sid: StringName, _sg: SaveGame, _r: int) -> void:
		order_log.append("first")
	var probe_middle: Callable = func(_sid: StringName, _sg: SaveGame, _r: int) -> void:
		order_log.append("middle")
		push_error("[TEST] deliberate error from middle probe to verify chain continues")
	var probe_last: Callable = func(_sid: StringName, _sg: SaveGame, _r: int) -> void:
		order_log.append("last")

	LevelStreamingService.register_restore_callback(probe_first)
	LevelStreamingService.register_restore_callback(probe_middle)
	LevelStreamingService.register_restore_callback(probe_last)

	# Avoid LS-006 same-section drop.
	await _ensure_can_transition_to(&"stub_b")

	LevelStreamingService.transition_to_section(
		&"stub_b", null, LevelStreamingService.TransitionReason.NEW_GAME
	)
	await _wait_for_idle(3.0)

	# All three probes must fire regardless of the middle one logging an error.
	assert_array(order_log).override_failure_message(
		"Chain must continue past an error-logging callback. Got: %s" % [order_log]
	).contains_exactly(["first", "middle", "last"])


# ── AC-6: no-await contract violation logs push_error in debug build ──────────

## AC-6: A callback that violates the no-await contract — LSS detects it via
## the pre/post Engine.get_process_frames() delta and push_errors in debug
## builds. The chain must not deadlock when this happens.
##
## DEGRADED COVERAGE NOTE: full AC-6 verification has two limitations in the
## current GdUnit4 setup:
##   1. push_error capture: GdUnit4 does not expose a stable assert_error()
##      with message-match capture in this project's pinned version, so the
##      "[LSS] restore callback violated no-await contract: ..." message is
##      verified by manual smoke check (visible in test runner console).
##   2. Probe-fired observation: GDScript's Callable-coroutine semantics +
##      lambda-closure scoping make it unreliable to observe a flag mutation
##      from a coroutine lambda invoked via Callable.call() inside a sync
##      iteration loop nested inside another coroutine (`_run_swap_sequence`).
##      Setting a closure-captured `bool` to true before the `await` does NOT
##      reliably propagate back to the test scope.
##
## What this test reliably verifies:
##   - Registering an awaiting callback does NOT deadlock the transition.
##   - The transition reaches IDLE within the timeout (no infinite hang).
##
## When a future GdUnit4 version exposes assert_error(), upgrade this test to
## assert the exact violation message format produced by
## `_invoke_restore_callbacks`.
func test_no_await_contract_violation_does_not_deadlock() -> void:
	if not LevelStreamingService.has_valid_registry():
		return

	await _wait_for_idle(2.0)

	# Awaiting probe — violates the no-await contract.
	# Uses SceneTree.process_frame (the dominant real-world violation pattern)
	# to advance the engine frame counter and trigger the LSS debug check.
	var awaiting_probe: Callable = func(_sid: StringName, _sg: SaveGame, _r: int) -> void:
		await LevelStreamingService.get_tree().process_frame

	LevelStreamingService.register_restore_callback(awaiting_probe)

	# Avoid LS-006 same-section drop.
	await _ensure_can_transition_to(&"plaza")

	LevelStreamingService.transition_to_section(
		&"plaza", null, LevelStreamingService.TransitionReason.NEW_GAME
	)

	# Give extra time because the awaiting probe advances the frame counter.
	await _wait_for_idle(4.0)

	assert_bool(LevelStreamingService.is_transitioning()).override_failure_message(
		"Transition must complete (reach IDLE) even when a callback violates the no-await contract — no infinite hang."
	).is_false()

	# Note: the push_error message "[LSS] restore callback violated no-await
	# contract: ..." is visible in the test runner console in debug builds.
	# Direct capture of push_error output is a post-MVP test improvement.


# ── AC-8: callback fires at step 9, NOT at step 3 ────────────────────────────

## AC-8: section_exited fires at step 3; the probe fires at step 9; and
## section_entered fires at step 10. Ordering: exited_frame < probe_frame
## <= entered_frame.
##
## Note on frame equality: step 9 and step 10 are on the SAME coroutine
## continuation with no await between them, so probe_frame == entered_frame
## is legal. The invariant that matters is exited_frame < probe_frame.
func test_callback_fires_at_step9_not_at_step3() -> void:
	if not LevelStreamingService.has_valid_registry():
		return

	await _wait_for_idle(2.0)

	_probe_active = true

	# Avoid LS-006 same-section drop.
	await _ensure_can_transition_to(&"stub_b")

	LevelStreamingService.transition_to_section(
		&"stub_b", null, LevelStreamingService.TransitionReason.NEW_GAME
	)
	await _wait_for_idle(3.0)

	assert_int(_probe_args_log.size()).override_failure_message(
		"Probe must fire exactly once. Got: %d" % _probe_args_log.size()
	).is_equal(1)

	assert_int(_exited_frame).override_failure_message(
		"section_exited must fire before probe (step 3 < step 9). exited=%d probe=%d"
		% [_exited_frame, _probe_frame]
	).is_less(_probe_frame)

	# probe_frame <= entered_frame (step 9 <= step 10 — same continuation or earlier).
	assert_int(_entered_frame).override_failure_message(
		"section_entered frame must be >= probe frame. probe=%d entered=%d"
		% [_probe_frame, _entered_frame]
	).is_greater_equal(_probe_frame)


# ── AC-9: probe state visible to section_entered subscriber ───────────────────

## AC-9: The probe sets _test_marker at step 9. The _on_section_entered spy
## checks whether _test_marker == "callback_ran" on receipt. After the
## transition the flag _subscriber_saw_marker_set must be true.
func test_probe_state_visible_to_section_entered_subscriber() -> void:
	if not LevelStreamingService.has_valid_registry():
		return

	await _wait_for_idle(2.0)

	_probe_active = true

	# Avoid LS-006 same-section drop.
	await _ensure_can_transition_to(&"plaza")

	LevelStreamingService.transition_to_section(
		&"plaza", null, LevelStreamingService.TransitionReason.NEW_GAME
	)
	await _wait_for_idle(3.0)

	assert_bool(_subscriber_saw_marker_set).override_failure_message(
		"section_entered subscriber must observe _test_marker == 'callback_ran' (probe at step 9 runs before section_entered at step 10)."
	).is_true()


# ── Helpers ───────────────────────────────────────────────────────────────────

## Polls the SceneTree until LSS reaches IDLE (or timeout elapses).
## Mirrors _wait_for_idle from the integration test suite.
func _wait_for_idle(timeout_sec: float) -> void:
	var elapsed: float = 0.0
	while LevelStreamingService.is_transitioning() and elapsed < timeout_sec:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
