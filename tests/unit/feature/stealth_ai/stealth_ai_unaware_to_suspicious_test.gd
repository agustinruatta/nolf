# tests/unit/feature/stealth_ai/stealth_ai_unaware_to_suspicious_test.gd
#
# StealthAIUnawareToSuspiciousTest — Story SAI-005 AC-1 + AC-5 coverage.
#
# COVERED ACCEPTANCE CRITERIA (Story SAI-005)
#   AC-1 (AC-SAI-1.1): UNAWARE → SUSPICIOUS transition fires both signals in order.
#   AC-5: AlertCause tie-break rule (sight >= sound → SAW_PLAYER; sound > sight → HEARD_NOISE).
#
# APPROACH
#   Tests instantiate Guard.tscn (which now has Perception.gd on the Perception child).
#   Signal emission is verified by connecting named callables to Events.* before
#   calling _evaluate_transitions(), and disconnecting the specific callable after.
#   This avoids disconnect_all() which would remove ALL subscribers globally.
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name StealthAIUnawareToSuspiciousTest
extends GdUnitTestSuite

const _GUARD_SCENE_PATH: String = "res://src/gameplay/stealth/Guard.tscn"


# ── Fixture helper ────────────────────────────────────────────────────────────

## Instantiates Guard.tscn and adds it to the scene tree (fires _ready).
func _make_guard() -> Guard:
	var scene: PackedScene = load(_GUARD_SCENE_PATH) as PackedScene
	var guard: Guard = scene.instantiate() as Guard
	add_child(guard)
	auto_free(guard)
	return guard


# ── AC-1: UNAWARE → SUSPICIOUS transition ────────────────────────────────────

## AC-1: GIVEN a guard in UNAWARE with sight_accumulator = 0.35 (> T_SUSPICIOUS 0.3),
## WHEN _evaluate_transitions() is called,
## THEN current_alert_state == SUSPICIOUS AND alert_state_changed emitted once
## with (guard, UNAWARE, SUSPICIOUS, MINOR) AND actor_became_alerted emitted once.
func test_unaware_to_suspicious_fires_both_signals_in_order() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 0.35
	guard._perception.sound_accumulator = 0.0

	var alert_changed_calls: Array[Dictionary] = []
	var became_alerted_calls: Array[Dictionary] = []

	# Store callables so we can disconnect the specific ones (not disconnect_all)
	var on_changed: Callable = func(actor, old_s, new_s, sev):
		alert_changed_calls.append({"actor": actor, "old": old_s, "new": new_s, "sev": sev})
	var on_alerted: Callable = func(actor, cause, pos, sev):
		became_alerted_calls.append({"actor": actor, "cause": cause, "sev": sev})

	# Connect BEFORE the call (AC-8 synchronicity requirement)
	Events.alert_state_changed.connect(on_changed)
	Events.actor_became_alerted.connect(on_alerted)

	# Act
	guard._evaluate_transitions()

	# Disconnect the specific callables
	Events.alert_state_changed.disconnect(on_changed)
	Events.actor_became_alerted.disconnect(on_alerted)

	# Assert — final state
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"AC-1: current_alert_state must be SUSPICIOUS after sight=0.35 > T_SUSPICIOUS=0.3."
	).is_equal(StealthAI.AlertState.SUSPICIOUS)

	# Assert — alert_state_changed emitted exactly once
	assert_int(alert_changed_calls.size()).override_failure_message(
		"AC-1: alert_state_changed must emit exactly once."
	).is_equal(1)
	assert_int(int(alert_changed_calls[0]["old"])).override_failure_message(
		"AC-1: old_state must be UNAWARE."
	).is_equal(StealthAI.AlertState.UNAWARE)
	assert_int(int(alert_changed_calls[0]["new"])).override_failure_message(
		"AC-1: new_state must be SUSPICIOUS."
	).is_equal(StealthAI.AlertState.SUSPICIOUS)
	assert_int(int(alert_changed_calls[0]["sev"])).override_failure_message(
		"AC-1: severity must be MINOR (UNAWARE → SUSPICIOUS)."
	).is_equal(StealthAI.Severity.MINOR)

	# Assert — actor_became_alerted emitted exactly once
	assert_int(became_alerted_calls.size()).override_failure_message(
		"AC-1: actor_became_alerted must emit exactly once."
	).is_equal(1)
	assert_int(int(became_alerted_calls[0]["sev"])).override_failure_message(
		"AC-1: actor_became_alerted severity must be MINOR."
	).is_equal(StealthAI.Severity.MINOR)


## AC-1 edge case: sight_accumulator = 0.29 (< T_SUSPICIOUS 0.3) → no transition.
func test_unaware_no_transition_below_suspicious_threshold() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 0.29
	guard._perception.sound_accumulator = 0.0

	var signal_count: int = 0
	var on_changed: Callable = func(_a, _o, _n, _s): signal_count += 1
	Events.alert_state_changed.connect(on_changed)

	# Act
	guard._evaluate_transitions()

	Events.alert_state_changed.disconnect(on_changed)

	# Assert
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"AC-1 edge: sight=0.29 < T_SUSPICIOUS=0.3 → must remain UNAWARE."
	).is_equal(StealthAI.AlertState.UNAWARE)
	assert_int(signal_count).override_failure_message(
		"AC-1 edge: no signals emitted when no threshold crossed."
	).is_equal(0)


## AC-1 AT threshold: sight_accumulator = 0.30 exactly (= T_SUSPICIOUS) → transitions
## (threshold comparison is >=).
func test_unaware_transitions_at_suspicious_threshold_exactly() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 0.30
	guard._perception.sound_accumulator = 0.0

	# Act
	guard._evaluate_transitions()

	# Assert
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"AC-1 AT threshold: sight=0.30 == T_SUSPICIOUS=0.3 → must transition to SUSPICIOUS (>= check)."
	).is_equal(StealthAI.AlertState.SUSPICIOUS)


## AC-1: UNAWARE → SEARCHING when combined score >= T_SEARCHING (skips SUSPICIOUS).
func test_unaware_jumps_to_searching_at_searching_threshold() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 0.6  # = T_SEARCHING default
	guard._perception.sound_accumulator = 0.0

	# Act
	guard._evaluate_transitions()

	# Assert
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"AC-1: sight=0.6 >= T_SEARCHING=0.6 → must jump directly to SEARCHING."
	).is_equal(StealthAI.AlertState.SEARCHING)


## AC-1: UNAWARE → COMBAT when combined score >= T_COMBAT.
func test_unaware_jumps_to_combat_at_combat_threshold() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 0.95  # = T_COMBAT default
	guard._perception.sound_accumulator = 0.0

	# Act
	guard._evaluate_transitions()

	# Assert
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"AC-1: sight=0.95 >= T_COMBAT=0.95 → must jump directly to COMBAT."
	).is_equal(StealthAI.AlertState.COMBAT)


# ── AC-5: AlertCause tie-break rule ──────────────────────────────────────────

## AC-5: sight >= sound → cause is SAW_PLAYER.
## Set sight=0.4, sound=0.2; transition must use SAW_PLAYER.
func test_cause_is_saw_player_when_sight_dominates() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 0.4
	guard._perception.sound_accumulator = 0.2  # sight > sound

	var received_cause: Array[int] = [-1]
	var on_alerted: Callable = func(_a, cause, _p, _s): received_cause[0] = cause
	Events.actor_became_alerted.connect(on_alerted)

	# Act
	guard._evaluate_transitions()

	Events.actor_became_alerted.disconnect(on_alerted)

	# Assert
	assert_int(received_cause[0]).override_failure_message(
		"AC-5: sight=0.4 > sound=0.2 → cause must be SAW_PLAYER."
	).is_equal(StealthAI.AlertCause.SAW_PLAYER)


## AC-5: sound > sight → cause is HEARD_NOISE.
## Set sight=0.2, sound=0.4; transition must use HEARD_NOISE.
func test_cause_is_heard_noise_when_sound_dominates() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 0.2
	guard._perception.sound_accumulator = 0.4  # sound > sight

	var received_cause: Array[int] = [-1]
	var on_alerted: Callable = func(_a, cause, _p, _s): received_cause[0] = cause
	Events.actor_became_alerted.connect(on_alerted)

	# Act
	guard._evaluate_transitions()

	Events.actor_became_alerted.disconnect(on_alerted)

	# Assert
	assert_int(received_cause[0]).override_failure_message(
		"AC-5: sound=0.4 > sight=0.2 → cause must be HEARD_NOISE."
	).is_equal(StealthAI.AlertCause.HEARD_NOISE)


## AC-5 tie-break: sight == sound → SAW_PLAYER wins.
## Both = 0.35 (above T_SUSPICIOUS); tie-break to SAW_PLAYER.
func test_cause_tie_breaks_to_saw_player_when_equal() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 0.35
	guard._perception.sound_accumulator = 0.35  # exact tie

	var received_cause: Array[int] = [-1]
	var on_alerted: Callable = func(_a, cause, _p, _s): received_cause[0] = cause
	Events.actor_became_alerted.connect(on_alerted)

	# Act
	guard._evaluate_transitions()

	Events.actor_became_alerted.disconnect(on_alerted)

	# Assert
	assert_int(received_cause[0]).override_failure_message(
		"AC-5 tie-break: sight=0.35 == sound=0.35 → cause must be SAW_PLAYER (sight wins ties)."
	).is_equal(StealthAI.AlertCause.SAW_PLAYER)


## AC-1: Already SUSPICIOUS — re-calling evaluate at same level does not re-emit.
func test_evaluate_transitions_idempotent_no_retransition_same_state() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 0.35
	guard._perception.sound_accumulator = 0.0
	guard._evaluate_transitions()  # first call → SUSPICIOUS

	var count_after: int = 0
	var on_changed: Callable = func(_a, _o, _n, _s): count_after += 1
	Events.alert_state_changed.connect(on_changed)

	# Act — second call with same accumulators (still above T_SUSPICIOUS but below T_SEARCHING)
	guard._evaluate_transitions()

	Events.alert_state_changed.disconnect(on_changed)

	# Assert — no additional signal from a no-op same-state re-evaluation
	assert_int(count_after).override_failure_message(
		"AC-1 idempotent: re-evaluating in SUSPICIOUS with same score must not re-emit."
	).is_equal(0)
