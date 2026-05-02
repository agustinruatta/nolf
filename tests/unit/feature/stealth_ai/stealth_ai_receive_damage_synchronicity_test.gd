# tests/unit/feature/stealth_ai/stealth_ai_receive_damage_synchronicity_test.gd
#
# StealthAIReceiveDamageSynchronicityTest — Story SAI-005 AC-8 coverage.
#
# COVERED ACCEPTANCE CRITERIA (Story SAI-005)
#   AC-8 (AC-SAI-1.11): current_alert_state is mutated synchronously BEFORE any
#   signal fires. Pre-connected lambda observes post-mutation state at handler
#   invocation time.
#
# NOTE ON NAME
#   Named "receive_damage_synchronicity" per the story's test evidence path, but
#   damage routing is post-VS. This file tests the synchronicity guarantee for the
#   state-escalation path (the same contract that damage routing will rely on).
#
# CONNECTION PATTERN
#   Each test stores its lambda Callables in local vars before connecting, so it
#   can call Events.signal.disconnect(callable) explicitly. Signal.disconnect_all()
#   does NOT exist in Godot 4.6 — and would be unsafe even if it did, since it
#   would also disconnect subscribers from other tests / production wiring.
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name StealthAIReceiveDamageSynchronicityTest
extends GdUnitTestSuite

const _GUARD_SCENE_PATH: String = "res://src/gameplay/stealth/Guard.tscn"


# ── Fixture helper ────────────────────────────────────────────────────────────

func _make_guard() -> Guard:
	var scene: PackedScene = load(_GUARD_SCENE_PATH) as PackedScene
	var guard: Guard = scene.instantiate() as Guard
	add_child(guard)
	auto_free(guard)
	return guard


# ── AC-8: Synchronicity via _evaluate_transitions ────────────────────────────

## AC-8: Pre-connected lambda to alert_state_changed captures guard.current_alert_state
## at handler invocation time; asserts it equals SUSPICIOUS (post-mutation).
## Lambda connected BEFORE the escalation call.
func test_synchronicity_alert_state_mutated_before_alert_state_changed_signal() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 0.35
	guard._perception.sound_accumulator = 0.0

	var observed_state_at_signal: Array[int] = [-1]  # boxed for closure capture

	var on_changed: Callable = func(_actor, _old, _new, _sev):
		observed_state_at_signal[0] = int(guard.current_alert_state)

	# Connect BEFORE the call (the key invariant)
	Events.alert_state_changed.connect(on_changed)

	# Pre-call state sanity check
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"AC-8 pre: guard must be in UNAWARE before escalation call."
	).is_equal(StealthAI.AlertState.UNAWARE)

	# Act
	guard._evaluate_transitions()

	# Disconnect specific callable
	Events.alert_state_changed.disconnect(on_changed)

	# Assert — lambda observed post-mutation state (SUSPICIOUS), NOT pre-mutation (UNAWARE)
	assert_int(observed_state_at_signal[0]).override_failure_message(
		"AC-8: lambda connected BEFORE _evaluate_transitions must observe "
		+ "guard.current_alert_state == SUSPICIOUS (post-mutation) at signal-handler time."
	).is_equal(StealthAI.AlertState.SUSPICIOUS)


## AC-8: Same guarantee holds for actor_became_alerted (second signal in the pair).
func test_synchronicity_alert_state_mutated_before_actor_became_alerted_signal() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 0.35
	guard._perception.sound_accumulator = 0.0

	var observed_state_at_alerted: Array[int] = [-1]

	var on_alerted: Callable = func(_actor, _cause, _pos, _sev):
		observed_state_at_alerted[0] = int(guard.current_alert_state)

	# Connect BEFORE the call
	Events.actor_became_alerted.connect(on_alerted)

	# Act
	guard._evaluate_transitions()

	Events.actor_became_alerted.disconnect(on_alerted)

	# Assert — actor_became_alerted also fires after mutation
	assert_int(observed_state_at_alerted[0]).override_failure_message(
		"AC-8: lambda on actor_became_alerted must observe guard.current_alert_state "
		+ "== SUSPICIOUS at handler time."
	).is_equal(StealthAI.AlertState.SUSPICIOUS)


## AC-8: Same guarantee holds for force_alert_state path.
func test_synchronicity_holds_for_force_alert_state() -> void:
	# Arrange
	var guard: Guard = _make_guard()

	var observed_state: Array[int] = [-1]
	var on_changed: Callable = func(_a, _o, _n, _s):
		observed_state[0] = int(guard.current_alert_state)

	Events.alert_state_changed.connect(on_changed)

	# Act — use force_alert_state (different code path, same synchronicity contract)
	var _ok: bool = guard.force_alert_state(
		StealthAI.AlertState.SEARCHING, StealthAI.AlertCause.SAW_PLAYER
	)

	Events.alert_state_changed.disconnect(on_changed)

	# Assert
	assert_int(observed_state[0]).override_failure_message(
		"AC-8 force: lambda on alert_state_changed via force_alert_state must "
		+ "observe SEARCHING at handler time."
	).is_equal(StealthAI.AlertState.SEARCHING)


## AC-8: State mutation is never deferred — guard.current_alert_state is SUSPICIOUS
## IMMEDIATELY after _evaluate_transitions() returns (same call stack).
func test_synchronicity_state_mutation_is_immediate_not_deferred() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 0.35
	guard._perception.sound_accumulator = 0.0

	# Act
	guard._evaluate_transitions()

	# Assert — state is already mutated synchronously (no await needed)
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"AC-8 deferred: current_alert_state must be SUSPICIOUS IMMEDIATELY after "
		+ "_evaluate_transitions() returns (no call_deferred; no await)."
	).is_equal(StealthAI.AlertState.SUSPICIOUS)


## AC-8: Signal payload (new_state arg) matches the post-mutation current_alert_state.
## The signal carries the same new_state that was just written to current_alert_state.
func test_synchronicity_signal_new_state_matches_mutated_state() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 0.35
	guard._perception.sound_accumulator = 0.0

	var signal_new_state: Array[int] = [-1]
	var state_at_signal_time: Array[int] = [-1]

	var on_changed: Callable = func(_a, _o, new_s, _v):
		signal_new_state[0] = int(new_s)
		state_at_signal_time[0] = int(guard.current_alert_state)

	Events.alert_state_changed.connect(on_changed)

	# Act
	guard._evaluate_transitions()

	Events.alert_state_changed.disconnect(on_changed)

	# Assert — both agree
	assert_int(signal_new_state[0]).override_failure_message(
		"AC-8: signal new_state arg must be SUSPICIOUS."
	).is_equal(StealthAI.AlertState.SUSPICIOUS)
	assert_int(state_at_signal_time[0]).override_failure_message(
		"AC-8: guard.current_alert_state at signal time must match signal new_state arg."
	).is_equal(signal_new_state[0])


## AC-8: Multiple pre-connected subscribers all see the post-mutation state.
## Two lambdas connected before the call; both observe SUSPICIOUS.
func test_synchronicity_multiple_subscribers_all_observe_post_mutation_state() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 0.35
	guard._perception.sound_accumulator = 0.0

	var observed_1: Array[int] = [-1]
	var observed_2: Array[int] = [-1]

	var on_first: Callable = func(_a, _o, _n, _s):
		observed_1[0] = int(guard.current_alert_state)
	var on_second: Callable = func(_a, _o, _n, _s):
		observed_2[0] = int(guard.current_alert_state)

	Events.alert_state_changed.connect(on_first)
	Events.alert_state_changed.connect(on_second)

	# Act
	guard._evaluate_transitions()

	Events.alert_state_changed.disconnect(on_first)
	Events.alert_state_changed.disconnect(on_second)

	# Assert — both subscribers see SUSPICIOUS
	assert_int(observed_1[0]).override_failure_message(
		"AC-8 multi: first subscriber must observe SUSPICIOUS."
	).is_equal(StealthAI.AlertState.SUSPICIOUS)
	assert_int(observed_2[0]).override_failure_message(
		"AC-8 multi: second subscriber must observe SUSPICIOUS."
	).is_equal(StealthAI.AlertState.SUSPICIOUS)
