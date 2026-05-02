# tests/integration/feature/stealth_ai/stealth_ai_full_perception_loop_test.gd
#
# StealthAIFullPerceptionLoopTest — Story SAI-008 AC-4 integration coverage.
#
# COVERED ACCEPTANCE CRITERIA (Story SAI-008)
#   AC-4: End-to-end perception → state → signal → subscriber pipeline.
#         A simulated guard transitioning through UNAWARE → SUSPICIOUS → SEARCHING
#         (which fires MAJOR severity) results in exactly one brass-punch stinger
#         play in the subscriber.
#   AC-6 partial: signal frequency upper bound — across 600 simulated ticks,
#         the subscriber sees no more than 8 alert_state_changed and no more than
#         5 actor_became_alerted total (sanity bound, not a frequency rate).
#
# TEST APPROACH
#   This is a logic-level integration test, not a Plaza-VS playtest. Real F.1
#   raycast simulation requires editor-baked nav meshes; instead this test
#   directly seeds Perception's sight_accumulator across simulated frames to
#   drive the state machine through a realistic escalation sequence.
#
#   The full Plaza-VS E2E playtest (with PC + Eve + nav mesh + visible scene)
#   is deferred to production/qa/evidence/ per the story Test Evidence section.
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name StealthAIFullPerceptionLoopTest
extends GdUnitTestSuite

const _GUARD_SCENE_PATH: String = "res://src/gameplay/stealth/Guard.tscn"


# ── Fixture helpers ───────────────────────────────────────────────────────────

func _make_guard() -> Guard:
	var scene: PackedScene = load(_GUARD_SCENE_PATH) as PackedScene
	var guard: Guard = scene.instantiate() as Guard
	add_child(guard)
	auto_free(guard)
	return guard


func _make_subscriber() -> StealthAlertAudioSubscriber:
	var sub: StealthAlertAudioSubscriber = StealthAlertAudioSubscriber.new()
	add_child(sub)
	auto_free(sub)
	return sub


# ── AC-4: end-to-end MAJOR-severity transition fires stinger ────────────────

## AC-4: Guard escalates UNAWARE → SUSPICIOUS → SEARCHING via accumulator seeding.
## SEARCHING transition is MAJOR severity → subscriber plays stinger exactly once
## per MAJOR transition.
##
## Sequence:
##   tick 0: sight = 0.35 → UNAWARE → SUSPICIOUS (MINOR — no stinger)
##   tick 1: sight = 0.6  → SUSPICIOUS → SEARCHING (MAJOR — 1 stinger)
##   tick 2..N: sight stays high; no more transitions; stinger count stays at 1
func test_full_loop_unaware_to_searching_fires_one_stinger() -> void:
	var sub: StealthAlertAudioSubscriber = _make_subscriber()
	var guard: Guard = _make_guard()

	# tick 0: escalate to SUSPICIOUS (MINOR)
	guard._perception.sight_accumulator = 0.35
	guard._evaluate_transitions()
	assert_int(int(guard.current_alert_state)).is_equal(StealthAI.AlertState.SUSPICIOUS)
	assert_int(sub.stinger_play_count).override_failure_message(
		"Tick 0 SUSPICIOUS = MINOR — no stinger expected."
	).is_equal(0)

	# tick 1: escalate to SEARCHING (MAJOR)
	guard._perception.sight_accumulator = 0.6
	guard._evaluate_transitions()
	assert_int(int(guard.current_alert_state)).is_equal(StealthAI.AlertState.SEARCHING)
	assert_int(sub.stinger_play_count).override_failure_message(
		"Tick 1 SEARCHING = MAJOR — exactly 1 stinger expected."
	).is_equal(1)

	# tick 2..10: sight stays at 0.6; no further transitions; stinger count locked
	for i: int in range(8):
		guard._evaluate_transitions()
	assert_int(sub.stinger_play_count).override_failure_message(
		"Idle ticks at SEARCHING — stinger count must stay at 1."
	).is_equal(1)


## AC-4: Two MAJOR-severity transitions in one sequence yield 2 stinger plays.
func test_full_loop_two_major_transitions_yield_two_stingers() -> void:
	var sub: StealthAlertAudioSubscriber = _make_subscriber()
	var guard: Guard = _make_guard()

	# Climb to SEARCHING
	guard._perception.sight_accumulator = 0.6
	guard._evaluate_transitions()
	assert_int(int(guard.current_alert_state)).is_equal(StealthAI.AlertState.SEARCHING)
	assert_int(sub.stinger_play_count).is_equal(1)

	# Climb to COMBAT (MAJOR)
	guard._perception.sight_accumulator = 0.95
	guard._evaluate_transitions()
	assert_int(int(guard.current_alert_state)).is_equal(StealthAI.AlertState.COMBAT)
	assert_int(sub.stinger_play_count).override_failure_message(
		"Two MAJOR transitions (SEARCHING + COMBAT) = 2 stinger plays."
	).is_equal(2)


## AC-4: De-escalation (SEARCHING → SUSPICIOUS) does NOT play stinger.
## actor_lost_target fires on de-escalation, not actor_became_alerted.
func test_full_loop_de_escalation_does_not_play_stinger() -> void:
	var sub: StealthAlertAudioSubscriber = _make_subscriber()
	var guard: Guard = _make_guard()

	# Escalate to SEARCHING
	guard._perception.sight_accumulator = 0.6
	guard._evaluate_transitions()
	assert_int(sub.stinger_play_count).is_equal(1)

	# De-escalate to SUSPICIOUS — this fires actor_lost_target, not actor_became_alerted
	guard._de_escalate_to(StealthAI.AlertState.SUSPICIOUS)
	assert_int(int(guard.current_alert_state)).is_equal(StealthAI.AlertState.SUSPICIOUS)
	assert_int(sub.stinger_play_count).override_failure_message(
		"De-escalation does NOT fire actor_became_alerted; stinger count must stay at 1."
	).is_equal(1)


# ── AC-6 partial: signal frequency sanity bound ─────────────────────────────

## AC-6 normal-play sanity (AC-SAI-3.8): in a 10-second sequence (600 ticks at
## delta=1/60), total alert_state_changed ≤ 8 and actor_became_alerted ≤ 5.
##
## Test approach: simulate a realistic escalate → linger → de-escalate sequence
## and count signal emissions via a side-channel collector.
func test_signal_frequency_normal_play_sanity_bound() -> void:
	var guard: Guard = _make_guard()

	var alert_changed_count: Array[int] = [0]
	var became_alerted_count: Array[int] = [0]

	var on_changed: Callable = func(_a, _o, _n, _s):
		alert_changed_count[0] += 1
	var on_alerted: Callable = func(_a, _c, _p, _s):
		became_alerted_count[0] += 1

	Events.alert_state_changed.connect(on_changed)
	Events.actor_became_alerted.connect(on_alerted)

	# Realistic sequence: spend ~3s at each major waypoint.
	# tick 0: sight 0.35 → SUSPICIOUS
	guard._perception.sight_accumulator = 0.35
	guard._evaluate_transitions()
	# ticks 1-180 (3s @ 60Hz): linger at SUSPICIOUS
	for i: int in range(180):
		guard._evaluate_transitions()
	# tick 181: sight 0.6 → SEARCHING
	guard._perception.sight_accumulator = 0.6
	guard._evaluate_transitions()
	# ticks 182-360: linger at SEARCHING
	for i: int in range(180):
		guard._evaluate_transitions()
	# tick 361: sight 0.95 → COMBAT
	guard._perception.sight_accumulator = 0.95
	guard._evaluate_transitions()
	# ticks 362-600: linger at COMBAT
	for i: int in range(240):
		guard._evaluate_transitions()

	Events.alert_state_changed.disconnect(on_changed)
	Events.actor_became_alerted.disconnect(on_alerted)

	# AC-6 sanity: ≤ 8 alert_state_changed, ≤ 5 actor_became_alerted
	assert_int(alert_changed_count[0]).override_failure_message(
		"AC-6 sanity: alert_state_changed must be ≤ 8 in 10s. Got %d." % alert_changed_count[0]
	).is_less_equal(8)
	assert_int(became_alerted_count[0]).override_failure_message(
		"AC-6 sanity: actor_became_alerted must be ≤ 5 in 10s. Got %d." % became_alerted_count[0]
	).is_less_equal(5)
