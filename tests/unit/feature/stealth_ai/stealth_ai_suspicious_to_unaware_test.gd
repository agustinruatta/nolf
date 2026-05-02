# tests/unit/feature/stealth_ai/stealth_ai_suspicious_to_unaware_test.gd
#
# StealthAISuspiciousToUnawareTest — Story SAI-005 AC-2 coverage.
#
# COVERED ACCEPTANCE CRITERIA (Story SAI-005)
#   AC-2 (AC-SAI-1.2): SUSPICIOUS → UNAWARE de-escalation via _de_escalate_to().
#
# APPROACH
#   The timer-based trigger (combined < T_DECAY_UNAWARE for SUSPICION_TIMEOUT_SEC)
#   is Story 007 scope. SAI-005 tests the de-escalation path directly by calling
#   _de_escalate_to(UNAWARE) after force-setting the guard to SUSPICIOUS.
#   This exercises the signal-emission code path that Story 007's timer will invoke.
#
# TIMER MECHANIC NOTE (for Story 007 implementer)
#   Story 007 will call guard._de_escalate_to(StealthAI.AlertState.UNAWARE) when
#   the suspicion timer expires. These tests verify the de-escalation path is
#   correct; the timer source is deferred.
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name StealthAISuspiciousToUnawareTest
extends GdUnitTestSuite

const _GUARD_SCENE_PATH: String = "res://src/gameplay/stealth/Guard.tscn"


# ── Fixture helper ────────────────────────────────────────────────────────────

func _make_guard_in_suspicious() -> Guard:
	var scene: PackedScene = load(_GUARD_SCENE_PATH) as PackedScene
	var guard: Guard = scene.instantiate() as Guard
	add_child(guard)
	auto_free(guard)
	# Put guard in SUSPICIOUS via force_alert_state (escalation path)
	guard.force_alert_state(StealthAI.AlertState.SUSPICIOUS, StealthAI.AlertCause.SAW_PLAYER)
	assert_int(int(guard.current_alert_state)).is_equal(StealthAI.AlertState.SUSPICIOUS)
	return guard


# ── AC-2: SUSPICIOUS → UNAWARE de-escalation ─────────────────────────────────

## AC-2: GIVEN a guard in SUSPICIOUS,
## WHEN _de_escalate_to(UNAWARE) is called (Story 007 timer source deferred),
## THEN guard transitions to UNAWARE AND emits alert_state_changed(guard, SUSPICIOUS, UNAWARE, MINOR)
## AND emits actor_lost_target(guard, MINOR).
func test_suspicious_to_unaware_fires_correct_signals() -> void:
	# Arrange
	var guard: Guard = _make_guard_in_suspicious()

	var alert_changed_calls: Array[Dictionary] = []
	var lost_target_calls: Array[Dictionary] = []

	var on_changed: Callable = func(actor, old_s, new_s, sev):
		alert_changed_calls.append({"old": old_s, "new": new_s, "sev": sev})
	var on_lost: Callable = func(actor, sev):
		lost_target_calls.append({"actor": actor, "sev": sev})

	Events.alert_state_changed.connect(on_changed)
	Events.actor_lost_target.connect(on_lost)

	# Act — de-escalation (timer-triggered in Story 007; called directly here)
	guard._de_escalate_to(StealthAI.AlertState.UNAWARE)

	Events.alert_state_changed.disconnect(on_changed)
	Events.actor_lost_target.disconnect(on_lost)

	# Assert — state
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"AC-2: guard must be in UNAWARE after de-escalation."
	).is_equal(StealthAI.AlertState.UNAWARE)

	# Assert — alert_state_changed: exactly once, correct params
	assert_int(alert_changed_calls.size()).override_failure_message(
		"AC-2: alert_state_changed must emit exactly once."
	).is_equal(1)
	assert_int(int(alert_changed_calls[0]["old"])).override_failure_message(
		"AC-2: old_state must be SUSPICIOUS."
	).is_equal(StealthAI.AlertState.SUSPICIOUS)
	assert_int(int(alert_changed_calls[0]["new"])).override_failure_message(
		"AC-2: new_state must be UNAWARE."
	).is_equal(StealthAI.AlertState.UNAWARE)
	assert_int(int(alert_changed_calls[0]["sev"])).override_failure_message(
		"AC-2: severity must be MINOR (SUSPICIOUS → UNAWARE de-escalation)."
	).is_equal(StealthAI.Severity.MINOR)

	# Assert — actor_lost_target: exactly once, MINOR severity
	assert_int(lost_target_calls.size()).override_failure_message(
		"AC-2: actor_lost_target must emit exactly once."
	).is_equal(1)
	assert_int(int(lost_target_calls[0]["sev"])).override_failure_message(
		"AC-2: actor_lost_target severity must be MINOR for SUSPICIOUS → UNAWARE."
	).is_equal(StealthAI.Severity.MINOR)


## AC-2: State mutation happens BEFORE signal fires (synchronicity contract).
## Pre-connected lambda captures guard.current_alert_state; must observe UNAWARE.
func test_suspicious_to_unaware_state_mutated_before_signal() -> void:
	# Arrange
	var guard: Guard = _make_guard_in_suspicious()

	var observed_state_at_signal: Array[int] = [-1]
	var on_changed: Callable = func(_a, _o, _n, _s):
		observed_state_at_signal[0] = int(guard.current_alert_state)
	Events.alert_state_changed.connect(on_changed)

	# Act
	guard._de_escalate_to(StealthAI.AlertState.UNAWARE)

	Events.alert_state_changed.disconnect(on_changed)

	# Assert — lambda observed post-mutation state
	assert_int(observed_state_at_signal[0]).override_failure_message(
		"AC-2 sync: lambda connected before _de_escalate_to must observe UNAWARE "
		+ "at signal-handler time (state mutated before emit)."
	).is_equal(StealthAI.AlertState.UNAWARE)


## AC-2: _de_escalate_to is idempotent — calling UNAWARE → UNAWARE does nothing.
func test_de_escalate_to_same_state_is_idempotent() -> void:
	# Arrange
	var scene: PackedScene = load(_GUARD_SCENE_PATH) as PackedScene
	var guard: Guard = scene.instantiate() as Guard
	add_child(guard)
	auto_free(guard)
	# Guard starts UNAWARE

	var signal_count: Array[int] = [0]
	var on_changed: Callable = func(_a, _o, _n, _s): signal_count[0] += 1
	Events.alert_state_changed.connect(on_changed)

	# Act — de-escalate to UNAWARE when already UNAWARE
	guard._de_escalate_to(StealthAI.AlertState.UNAWARE)

	Events.alert_state_changed.disconnect(on_changed)

	# Assert — no signal emitted (idempotent)
	assert_int(signal_count[0]).override_failure_message(
		"AC-2 idempotent: _de_escalate_to to same state must not emit any signal."
	).is_equal(0)


## SEARCHING → SUSPICIOUS de-escalation via _de_escalate_to also emits actor_lost_target.
func test_searching_to_suspicious_de_escalation_fires_actor_lost_target() -> void:
	# Arrange
	var scene: PackedScene = load(_GUARD_SCENE_PATH) as PackedScene
	var guard: Guard = scene.instantiate() as Guard
	add_child(guard)
	auto_free(guard)
	guard.force_alert_state(StealthAI.AlertState.SEARCHING, StealthAI.AlertCause.SAW_PLAYER)

	var lost_target_count: Array[int] = [0]
	var on_lost: Callable = func(_a, _s): lost_target_count[0] += 1
	Events.actor_lost_target.connect(on_lost)

	# Act
	guard._de_escalate_to(StealthAI.AlertState.SUSPICIOUS)

	Events.actor_lost_target.disconnect(on_lost)

	# Assert
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"SEARCHING → SUSPICIOUS de-escalation must arrive at SUSPICIOUS."
	).is_equal(StealthAI.AlertState.SUSPICIOUS)
	assert_int(lost_target_count[0]).override_failure_message(
		"SEARCHING → SUSPICIOUS must emit actor_lost_target."
	).is_equal(1)
