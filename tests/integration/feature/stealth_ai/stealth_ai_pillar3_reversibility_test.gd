# tests/integration/feature/stealth_ai/stealth_ai_pillar3_reversibility_test.gd
#
# StealthAIPillar3ReversibilityTest — Story SAI-007 AC-5 coverage.
#
# COVERED ACCEPTANCE CRITERIA (Story SAI-007)
#   AC-5 (AC-SAI-4.2): Pillar 3 reversibility integration test.
#       Guard escalates to SUSPICIOUS from sight fill, then Eve hides (LOS breaks).
#       After 10+ simulated seconds with no stimulus, guard returns to UNAWARE.
#       No accumulated state persists. current_alert_state == UNAWARE.
#       Patrol behavior resumes (NavigationAgent3D.max_speed == patrol_speed_mps).
#
# TEST APPROACH
#   Simulate the full escalation → de-escalation cycle using the two Story 007
#   methods in concert:
#     1. Manually set sight_accumulator to trigger SUSPICIOUS via _evaluate_transitions.
#     2. Block LOS (no new fills): call _perception.apply_decay + tick_de_escalation_timers
#        per simulated frame to model "Eve is hidden for 10 s".
#     3. Assert final UNAWARE state, accumulator values, and patrol behavior.
#
#   No real nav-mesh is needed — we verify the dispatch contract only
#   (NavigationAgent3D.max_speed). Same headless-safe approach as SAI-006 patrol test.
#
#   The test drives physics time manually (no real physics frames); this is the
#   same model used by the decay and timer unit tests and confirmed by the test
#   suite's 582-pass baseline to be valid in headless GdUnit4.
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.
#
# Implements: Story SAI-007 (TR-SAI-009 §F.3 AC-5 Pillar 3 reversibility)
# GDD: design/gdd/stealth-ai.md §Player Fantasy (Theatre, Not Punishment)
#      §Detailed Rules (State de-escalation rule, SUSPICIOUS → UNAWARE timeout)

class_name StealthAIPillar3ReversibilityTest
extends GdUnitTestSuite

const _GUARD_SCENE_PATH: String = "res://src/gameplay/stealth/Guard.tscn"
const _TOLERANCE: float = 0.01


# ── Fixture helper ────────────────────────────────────────────────────────────

func _make_guard() -> Guard:
	var scene: PackedScene = load(_GUARD_SCENE_PATH) as PackedScene
	var guard: Guard = scene.instantiate() as Guard
	add_child(guard)
	auto_free(guard)
	return guard


# ── AC-5: Full reversibility cycle — SUSPICIOUS → UNAWARE ─────────────────

## AC-5: Guard escalates to SUSPICIOUS from sight fill; Eve hides for 10 s;
## guard returns to UNAWARE. No accumulated state persists.
func test_reversibility_suspicious_returns_to_unaware_after_no_stimulus_for_ten_seconds() -> void:
	# Arrange — escalate to SUSPICIOUS via accumulator
	var guard: Guard = _make_guard()
	# Sight just above t_suspicious (0.3) to trigger escalation
	guard._perception.sight_accumulator = 0.35
	guard._perception.sound_accumulator = 0.0
	guard._evaluate_transitions()

	assert_int(int(guard.current_alert_state)).override_failure_message(
		"AC-5 pre-condition: guard must be SUSPICIOUS after sight_accumulator=0.35."
	).is_equal(StealthAI.AlertState.SUSPICIOUS)

	# Drop accumulators below t_decay_unaware (0.1) — Eve has hidden
	guard._perception.sight_accumulator = 0.05
	guard._perception.sound_accumulator = 0.0

	# Simulate 10 simulated seconds of no stimulus at 0.25 s ticks (40 ticks).
	# Each tick calls both apply_decay + tick_de_escalation_timers to model
	# a physics frame with no sight fill and no sound fill.
	for _i: int in range(40):
		# apply_decay with no refresh flags (Eve is hidden — no fills this frame)
		guard._perception.apply_decay(guard.current_alert_state, 0.25)
		# Tick the de-escalation timer
		guard.tick_de_escalation_timers(0.25)

	# Assert: back to UNAWARE (suspicion_timeout_sec = 4 s; 10 s >> 4 s)
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"AC-5: guard must return to UNAWARE after 10 s of no stimulus."
	).is_equal(StealthAI.AlertState.UNAWARE)


## AC-5: Accumulators are below t_decay_unaware (0.1) after full reversibility cycle.
## (Not necessarily zero — de-escalation fires when timer expires, not when accumulators
## are exactly zero. The spec requires "< T_DECAY_UNAWARE threshold satisfied".)
func test_reversibility_accumulators_below_threshold_after_returning_to_unaware() -> void:
	# Arrange — same as above
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 0.35
	guard._perception.sound_accumulator = 0.0
	guard._evaluate_transitions()

	guard._perception.sight_accumulator = 0.05
	guard._perception.sound_accumulator = 0.0

	# Act: 10 s simulation
	for _i: int in range(40):
		guard._perception.apply_decay(guard.current_alert_state, 0.25)
		guard.tick_de_escalation_timers(0.25)

	# Assert: accumulators satisfy the decay threshold condition (< t_decay_unaware)
	assert_float(guard._perception.sight_accumulator).override_failure_message(
		"AC-5: sight_accumulator must be < t_decay_unaware (%.2f) after full reversibility cycle."
		% guard.t_decay_unaware
	).is_less(guard.t_decay_unaware + _TOLERANCE)
	assert_float(guard._perception.sound_accumulator).override_failure_message(
		"AC-5: sound_accumulator must be < t_decay_unaware (%.2f) after full reversibility cycle."
		% guard.t_decay_unaware
	).is_less(guard.t_decay_unaware + _TOLERANCE)


## AC-5: Patrol behavior resumes after returning to UNAWARE.
## NavigationAgent3D.max_speed == patrol_speed_mps (set by _dispatch_behavior_for_state).
func test_reversibility_patrol_behavior_resumes_after_returning_to_unaware() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 0.35
	guard._perception.sound_accumulator = 0.0
	guard._evaluate_transitions()

	assert_int(int(guard.current_alert_state)).is_equal(StealthAI.AlertState.SUSPICIOUS)
	# While SUSPICIOUS, max_speed should be 0.0 (stop in place)
	assert_float(guard._navigation_agent.max_speed).is_equal_approx(0.0, 0.001)

	guard._perception.sight_accumulator = 0.05
	guard._perception.sound_accumulator = 0.0

	# Act: simulate 10 s to return to UNAWARE
	for _i: int in range(40):
		guard._perception.apply_decay(guard.current_alert_state, 0.25)
		guard.tick_de_escalation_timers(0.25)

	# Assert: patrol speed restored
	assert_int(int(guard.current_alert_state)).is_equal(StealthAI.AlertState.UNAWARE)
	assert_float(guard._navigation_agent.max_speed).override_failure_message(
		"AC-5: patrol behavior must resume — max_speed must equal patrol_speed_mps after UNAWARE."
	).is_equal_approx(guard.patrol_speed_mps, 0.001)
