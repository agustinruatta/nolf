# tests/unit/feature/stealth_ai/stealth_ai_decay_test.gd
#
# StealthAIDecayTest — Story SAI-007 AC-1, AC-6, AC-7 coverage.
#
# COVERED ACCEPTANCE CRITERIA (Story SAI-007)
#   AC-1 (AC-SAI-2.4): F.3 decay rate table — 4-state decay verification.
#                      Starting at sight_accumulator = 1.0 with no stimulus,
#                      after 60 physics ticks at delta=1/60 (1 simulated second),
#                      accumulator ≈ 1.0 - SIGHT_DECAY[state] within 0.01 tolerance.
#   AC-2 / AC-7:      SUSPICIOUS → UNAWARE timeout; timer resets when stimulus arrives.
#   AC-6:             Hitch-guard clamp: at delta=1/30 (max clamped frame), 10 seconds
#                      of decay reaches 0.0 cleanly without going negative.
#
# TEST APPROACH
#   Guard.tscn instantiation. Force guard into target state via force_alert_state.
#   Call _perception.apply_decay(state, delta) in a loop. Assert final accumulator
#   within tolerance. No network, no filesystem, no real raycasts — pure arithmetic.
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.
#
# Implements: Story SAI-007 (TR-SAI-009 §F.3)
# GDD: design/gdd/stealth-ai.md §Accumulator decay

class_name StealthAIDecayTest
extends GdUnitTestSuite

const _GUARD_SCENE_PATH: String = "res://src/gameplay/stealth/Guard.tscn"
const _TOLERANCE: float = 0.01
const _TICKS_PER_SEC: int = 60
const _DELTA: float = 1.0 / 60.0


# ── Fixture helper ────────────────────────────────────────────────────────────

func _make_guard() -> Guard:
	var scene: PackedScene = load(_GUARD_SCENE_PATH) as PackedScene
	var guard: Guard = scene.instantiate() as Guard
	add_child(guard)
	auto_free(guard)
	return guard


# ── AC-1: Decay rate table — UNAWARE ─────────────────────────────────────────

## AC-1: UNAWARE state — after 60 ticks (1 s) sight decays by sight_decay_unaware (0.5).
func test_decay_sight_unaware_one_second_reduces_by_expected_rate() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 1.0
	# Guard starts UNAWARE — no state change needed.

	# Act: 60 ticks at 1/60 s each (= 1 simulated second)
	for _i: int in range(_TICKS_PER_SEC):
		guard._perception.apply_decay(StealthAI.AlertState.UNAWARE, _DELTA)

	# Assert: accumulator ≈ 1.0 - sight_decay_unaware * 1.0 = 0.5
	var expected: float = 1.0 - guard._perception.sight_decay_unaware * 1.0
	assert_float(guard._perception.sight_accumulator).override_failure_message(
		"AC-1 UNAWARE: sight_accumulator after 1 s should be ≈ %.3f (got %.6f)."
		% [expected, guard._perception.sight_accumulator]
	).is_equal_approx(expected, _TOLERANCE)
	assert_float(guard._perception.sight_accumulator).override_failure_message(
		"AC-1 UNAWARE: accumulator must not go negative."
	).is_greater_equal(0.0)


## AC-1: UNAWARE state — sound accumulator decays by sound_decay_unaware (0.4) in 1 s.
func test_decay_sound_unaware_one_second_reduces_by_expected_rate() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sound_accumulator = 1.0

	# Act
	for _i: int in range(_TICKS_PER_SEC):
		guard._perception.apply_decay(StealthAI.AlertState.UNAWARE, _DELTA)

	# Assert: ≈ 1.0 - 0.4 = 0.6
	var expected: float = 1.0 - guard._perception.sound_decay_unaware * 1.0
	assert_float(guard._perception.sound_accumulator).override_failure_message(
		"AC-1 UNAWARE sound: should be ≈ %.3f (got %.6f)."
		% [expected, guard._perception.sound_accumulator]
	).is_equal_approx(expected, _TOLERANCE)


# ── AC-1: Decay rate table — SUSPICIOUS ──────────────────────────────────────

## AC-1: SUSPICIOUS state — sight decays by sight_decay_suspicious (0.3) in 1 s.
func test_decay_sight_suspicious_one_second_reduces_by_expected_rate() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 1.0
	var _ok: bool = guard.force_alert_state(
			StealthAI.AlertState.SUSPICIOUS, StealthAI.AlertCause.SAW_PLAYER
	)

	# Act
	for _i: int in range(_TICKS_PER_SEC):
		guard._perception.apply_decay(StealthAI.AlertState.SUSPICIOUS, _DELTA)

	# Assert: ≈ 1.0 - 0.3 = 0.7
	var expected: float = 1.0 - guard._perception.sight_decay_suspicious * 1.0
	assert_float(guard._perception.sight_accumulator).override_failure_message(
		"AC-1 SUSPICIOUS: sight should be ≈ %.3f (got %.6f)."
		% [expected, guard._perception.sight_accumulator]
	).is_equal_approx(expected, _TOLERANCE)


## AC-1: SUSPICIOUS state — sound decays by sound_decay_suspicious (0.25) in 1 s.
func test_decay_sound_suspicious_one_second_reduces_by_expected_rate() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sound_accumulator = 1.0
	var _ok: bool = guard.force_alert_state(
			StealthAI.AlertState.SUSPICIOUS, StealthAI.AlertCause.SAW_PLAYER
	)

	# Act
	for _i: int in range(_TICKS_PER_SEC):
		guard._perception.apply_decay(StealthAI.AlertState.SUSPICIOUS, _DELTA)

	# Assert: ≈ 1.0 - 0.25 = 0.75
	var expected: float = 1.0 - guard._perception.sound_decay_suspicious * 1.0
	assert_float(guard._perception.sound_accumulator).override_failure_message(
		"AC-1 SUSPICIOUS sound: should be ≈ %.3f (got %.6f)."
		% [expected, guard._perception.sound_accumulator]
	).is_equal_approx(expected, _TOLERANCE)


# ── AC-1: Decay rate table — SEARCHING ───────────────────────────────────────

## AC-1: SEARCHING state — sight decays by sight_decay_searching (0.15) in 1 s.
func test_decay_sight_searching_one_second_reduces_by_expected_rate() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 1.0
	var _ok1: bool = guard.force_alert_state(
			StealthAI.AlertState.SUSPICIOUS, StealthAI.AlertCause.SAW_PLAYER
	)
	var _ok2: bool = guard.force_alert_state(
			StealthAI.AlertState.SEARCHING, StealthAI.AlertCause.SAW_PLAYER
	)

	# Act
	for _i: int in range(_TICKS_PER_SEC):
		guard._perception.apply_decay(StealthAI.AlertState.SEARCHING, _DELTA)

	# Assert: ≈ 1.0 - 0.15 = 0.85
	var expected: float = 1.0 - guard._perception.sight_decay_searching * 1.0
	assert_float(guard._perception.sight_accumulator).override_failure_message(
		"AC-1 SEARCHING: sight should be ≈ %.3f (got %.6f)."
		% [expected, guard._perception.sight_accumulator]
	).is_equal_approx(expected, _TOLERANCE)


## AC-1: SEARCHING state — sound decays by sound_decay_searching (0.12) in 1 s.
func test_decay_sound_searching_one_second_reduces_by_expected_rate() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sound_accumulator = 1.0
	var _ok1: bool = guard.force_alert_state(
			StealthAI.AlertState.SUSPICIOUS, StealthAI.AlertCause.SAW_PLAYER
	)
	var _ok2: bool = guard.force_alert_state(
			StealthAI.AlertState.SEARCHING, StealthAI.AlertCause.SAW_PLAYER
	)

	# Act
	for _i: int in range(_TICKS_PER_SEC):
		guard._perception.apply_decay(StealthAI.AlertState.SEARCHING, _DELTA)

	# Assert: ≈ 1.0 - 0.12 = 0.88
	var expected: float = 1.0 - guard._perception.sound_decay_searching * 1.0
	assert_float(guard._perception.sound_accumulator).override_failure_message(
		"AC-1 SEARCHING sound: should be ≈ %.3f (got %.6f)."
		% [expected, guard._perception.sound_accumulator]
	).is_equal_approx(expected, _TOLERANCE)


# ── AC-1: Decay rate table — COMBAT ──────────────────────────────────────────

## AC-1: COMBAT state — sight decays by sight_decay_combat (0.05) in 1 s.
func test_decay_sight_combat_one_second_reduces_by_expected_rate() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 1.0
	var _ok1: bool = guard.force_alert_state(
			StealthAI.AlertState.SUSPICIOUS, StealthAI.AlertCause.SAW_PLAYER
	)
	var _ok2: bool = guard.force_alert_state(
			StealthAI.AlertState.SEARCHING, StealthAI.AlertCause.SAW_PLAYER
	)
	var _ok3: bool = guard.force_alert_state(
			StealthAI.AlertState.COMBAT, StealthAI.AlertCause.SAW_PLAYER
	)

	# Act
	for _i: int in range(_TICKS_PER_SEC):
		guard._perception.apply_decay(StealthAI.AlertState.COMBAT, _DELTA)

	# Assert: ≈ 1.0 - 0.05 = 0.95
	var expected: float = 1.0 - guard._perception.sight_decay_combat * 1.0
	assert_float(guard._perception.sight_accumulator).override_failure_message(
		"AC-1 COMBAT: sight should be ≈ %.3f (got %.6f)."
		% [expected, guard._perception.sight_accumulator]
	).is_equal_approx(expected, _TOLERANCE)


## AC-1: COMBAT state — sound decays by sound_decay_combat (0.05) in 1 s.
func test_decay_sound_combat_one_second_reduces_by_expected_rate() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sound_accumulator = 1.0
	var _ok1: bool = guard.force_alert_state(
			StealthAI.AlertState.SUSPICIOUS, StealthAI.AlertCause.SAW_PLAYER
	)
	var _ok2: bool = guard.force_alert_state(
			StealthAI.AlertState.SEARCHING, StealthAI.AlertCause.SAW_PLAYER
	)
	var _ok3: bool = guard.force_alert_state(
			StealthAI.AlertState.COMBAT, StealthAI.AlertCause.SAW_PLAYER
	)

	# Act
	for _i: int in range(_TICKS_PER_SEC):
		guard._perception.apply_decay(StealthAI.AlertState.COMBAT, _DELTA)

	# Assert: ≈ 1.0 - 0.05 = 0.95
	var expected: float = 1.0 - guard._perception.sound_decay_combat * 1.0
	assert_float(guard._perception.sound_accumulator).override_failure_message(
		"AC-1 COMBAT sound: should be ≈ %.3f (got %.6f)."
		% [expected, guard._perception.sound_accumulator]
	).is_equal_approx(expected, _TOLERANCE)


# ── AC-1: Never-negative invariant ───────────────────────────────────────────

## AC-1 invariant: 10 simulated seconds of decay-only (UNAWARE) never goes negative.
func test_decay_never_goes_negative_after_ten_seconds_unaware() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 1.0
	guard._perception.sound_accumulator = 1.0

	# Act: 10 seconds × 60 ticks = 600 ticks
	for _i: int in range(10 * _TICKS_PER_SEC):
		guard._perception.apply_decay(StealthAI.AlertState.UNAWARE, _DELTA)

	# Assert: both accumulators at exactly 0.0 (floored, not negative)
	assert_float(guard._perception.sight_accumulator).override_failure_message(
		"AC-1 invariant: sight_accumulator must be >= 0.0 after 10 s UNAWARE decay."
	).is_greater_equal(0.0)
	assert_float(guard._perception.sound_accumulator).override_failure_message(
		"AC-1 invariant: sound_accumulator must be >= 0.0 after 10 s UNAWARE decay."
	).is_greater_equal(0.0)


# ── AC-6: Hitch-guard clamp ───────────────────────────────────────────────────

## AC-6: At delta=1/30 (max clamped frame), 10 seconds of decay does not
## undershoot — accumulator reaches 0.0 cleanly and stays there.
func test_decay_hitch_guard_clamped_delta_never_negative_over_ten_seconds() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 1.0
	guard._perception.sound_accumulator = 1.0
	# Max clamped delta: the hitch guard clamps to 1/30 s per frame.
	var hitch_delta: float = 1.0 / 30.0

	# Act: 10 simulated seconds at 30 fps (300 ticks)
	for _i: int in range(300):
		guard._perception.apply_decay(StealthAI.AlertState.UNAWARE, hitch_delta)

	# Assert: both accumulators >= 0.0 (no undershoot)
	assert_float(guard._perception.sight_accumulator).override_failure_message(
		"AC-6 hitch: sight must be >= 0.0 with max clamped delta over 10 s."
	).is_greater_equal(0.0)
	assert_float(guard._perception.sound_accumulator).override_failure_message(
		"AC-6 hitch: sound must be >= 0.0 with max clamped delta over 10 s."
	).is_greater_equal(0.0)


## AC-6: A frame spike of delta=0.5 s (far above 1/30 cap) is clamped and does
## not produce a negative accumulator even in a single tick.
func test_decay_frame_spike_beyond_cap_is_clamped_no_negative() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 0.01  # near-zero accumulator

	# Act: one tick with 500 ms frame (far beyond 1/30 cap)
	guard._perception.apply_decay(StealthAI.AlertState.UNAWARE, 0.5)

	# Assert: hitch guard kicked in; accumulator at 0.0, not negative
	assert_float(guard._perception.sight_accumulator).override_failure_message(
		"AC-6 spike: sight must be >= 0.0 after delta=0.5 frame spike."
	).is_greater_equal(0.0)


# ── AC-7: Refresh flag prevents same-frame fill+decay ────────────────────────

## AC-7 (via refresh flag): when _sight_refreshed_this_frame is true,
## apply_decay skips sight decay for that call.
func test_decay_sight_refresh_flag_prevents_sight_decay_in_same_frame() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 0.5
	# Simulate a fill having happened this frame:
	guard._perception._sight_refreshed_this_frame = true

	# Act
	guard._perception.apply_decay(StealthAI.AlertState.UNAWARE, _DELTA)

	# Assert: sight NOT decayed because refresh flag was set
	assert_float(guard._perception.sight_accumulator).override_failure_message(
		"AC-7 refresh: sight_accumulator must remain 0.5 when _sight_refreshed_this_frame=true."
	).is_equal_approx(0.5, 0.0001)


## AC-7: After apply_decay runs with refresh flag true, the flag is reset to false.
func test_decay_refresh_flag_is_reset_to_false_after_apply_decay() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception._sight_refreshed_this_frame = true
	guard._perception._sound_refreshed_this_poll = true

	# Act
	guard._perception.apply_decay(StealthAI.AlertState.UNAWARE, _DELTA)

	# Assert: flags reset
	assert_bool(guard._perception._sight_refreshed_this_frame).override_failure_message(
		"AC-7: _sight_refreshed_this_frame must be false after apply_decay."
	).is_false()
	assert_bool(guard._perception._sound_refreshed_this_poll).override_failure_message(
		"AC-7: _sound_refreshed_this_poll must be false after apply_decay."
	).is_false()


# ── AC-2: SUSPICIOUS → UNAWARE timeout ───────────────────────────────────────

## AC-2: Guard in SUSPICIOUS with both accumulators below t_decay_unaware (0.1),
## after suspicion_timeout_sec (4.0 s) elapses, transitions to UNAWARE.
func test_suspicious_to_unaware_timeout_fires_after_suspicion_timeout_sec() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	var _ok: bool = guard.force_alert_state(
			StealthAI.AlertState.SUSPICIOUS, StealthAI.AlertCause.SAW_PLAYER
	)
	# Both accumulators below t_decay_unaware
	guard._perception.sight_accumulator = 0.05
	guard._perception.sound_accumulator = 0.05

	var changed_calls: Array[Dictionary] = []
	var on_changed: Callable = func(actor, old_s, new_s, sev):
		changed_calls.append({"old": old_s, "new": new_s, "sev": sev})
	var lost_calls: Array[int] = [0]
	var on_lost: Callable = func(_a, _s): lost_calls[0] += 1
	Events.alert_state_changed.connect(on_changed)
	Events.actor_lost_target.connect(on_lost)

	# Act: 4.1 simulated seconds (just past 4.0 s timeout)
	# Use 0.5 s ticks — 9 ticks = 4.5 s > 4.0 s
	for _i: int in range(9):
		guard.tick_de_escalation_timers(0.5)

	Events.alert_state_changed.disconnect(on_changed)
	Events.actor_lost_target.disconnect(on_lost)

	# Assert: transitioned to UNAWARE
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"AC-2: guard must be UNAWARE after 4.5 simulated seconds below t_decay_unaware."
	).is_equal(StealthAI.AlertState.UNAWARE)

	# Assert: alert_state_changed(_, SUSPICIOUS, UNAWARE, MINOR) emitted once
	assert_int(changed_calls.size()).override_failure_message(
		"AC-2: alert_state_changed must emit exactly once on SUSPICIOUS → UNAWARE."
	).is_equal(1)
	assert_int(int(changed_calls[0]["old"])).is_equal(StealthAI.AlertState.SUSPICIOUS)
	assert_int(int(changed_calls[0]["new"])).is_equal(StealthAI.AlertState.UNAWARE)
	assert_int(int(changed_calls[0]["sev"])).override_failure_message(
		"AC-2: SUSPICIOUS → UNAWARE is MINOR (no brass-punch stinger per Pillar 1)."
	).is_equal(StealthAI.Severity.MINOR)

	# Assert: actor_lost_target emitted once
	assert_int(lost_calls[0]).override_failure_message(
		"AC-2: actor_lost_target must emit once on de-escalation."
	).is_equal(1)


## AC-7 (timer cancel): if stimulus arrives while SUSPICIOUS countdown is active
## (combined bumps above t_decay_unaware), timer resets — guard does NOT transition
## to UNAWARE in this tick.
func test_suspicious_timer_resets_when_stimulus_arrives_above_threshold() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	var _ok: bool = guard.force_alert_state(
			StealthAI.AlertState.SUSPICIOUS, StealthAI.AlertCause.SAW_PLAYER
	)
	guard._perception.sight_accumulator = 0.05
	guard._perception.sound_accumulator = 0.05

	# Tick down close to timeout (e.g. 3.5 s of 4.0 s)
	for _i: int in range(7):
		guard.tick_de_escalation_timers(0.5)  # 3.5 s elapsed

	# Guard is still SUSPICIOUS, timer at 0.5 s remaining
	assert_int(int(guard.current_alert_state)).is_equal(StealthAI.AlertState.SUSPICIOUS)

	# New stimulus: bump accumulator above t_decay_unaware
	guard._perception.sight_accumulator = 0.2  # above t_decay_unaware (0.1)

	# One more tick — timer should reset, not fire de-escalation
	guard.tick_de_escalation_timers(0.5)

	# Assert: still SUSPICIOUS (timer was reset, not fired)
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"AC-7: guard must remain SUSPICIOUS when stimulus arrives and resets the countdown."
	).is_equal(StealthAI.AlertState.SUSPICIOUS)
