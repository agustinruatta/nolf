# tests/unit/feature/stealth_ai/stealth_ai_combined_score_test.gd
#
# StealthAICombinedScoreTest — Story SAI-005 AC-4 coverage.
#
# COVERED ACCEPTANCE CRITERIA (Story SAI-005)
#   AC-4 (AC-SAI-2.7): Combined score formula verified over 5 ordered pairs.
#   Formula: combined = max(sight, sound) + 0.5 × min(sight, sound).
#   Threshold comparison: >= (AT threshold triggers transition).
#
# FORMULA DERIVATION (test oracle, independent of implementation)
#   (0.25, 0.25) → max=0.25, min=0.25 → 0.25 + 0.5×0.25 = 0.375 → SUSPICIOUS
#   (0.3,  0.0)  → max=0.3,  min=0.0  → 0.3  + 0.5×0.0  = 0.3   → SUSPICIOUS (AT)
#   (0.0,  0.3)  → max=0.3,  min=0.0  → 0.3  + 0.5×0.0  = 0.3   → SUSPICIOUS (AT)
#   (0.15, 0.3)  → max=0.3,  min=0.15 → 0.3  + 0.5×0.15 = 0.375 → SUSPICIOUS
#   (0.6,  0.0)  → max=0.6,  min=0.0  → 0.6  + 0.5×0.0  = 0.6   → SEARCHING (AT)
#   Edge (1.0, 1.0) → combined = 1.5 (intentional over-1.0 — decisive cross-channel)
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name StealthAICombinedScoreTest
extends GdUnitTestSuite

const _GUARD_SCENE_PATH: String = "res://src/gameplay/stealth/Guard.tscn"
const _TOLERANCE: float = 0.001


# ── Fixture helper ────────────────────────────────────────────────────────────

func _make_guard() -> Guard:
	var scene: PackedScene = load(_GUARD_SCENE_PATH) as PackedScene
	var guard: Guard = scene.instantiate() as Guard
	add_child(guard)
	auto_free(guard)
	return guard


## Oracle: independent derivation of the combined score formula.
## Formula: max(sight, sound) + 0.5 × min(sight, sound).
func _oracle_combined(sight: float, sound: float) -> float:
	return maxf(sight, sound) + 0.5 * minf(sight, sound)


# ── AC-4: 5 ordered pairs from the story spec ────────────────────────────────

## AC-4 row 1: (0.25, 0.25) → combined = 0.375 → crosses T_SUSPICIOUS, UNAWARE→SUSPICIOUS.
func test_combined_score_pair_0_25_0_25_crosses_suspicious() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 0.25
	guard._perception.sound_accumulator = 0.25

	var expected_combined: float = _oracle_combined(0.25, 0.25)

	# Assert formula
	assert_float(expected_combined).override_failure_message(
		"AC-4 row 1: oracle combined(0.25,0.25) must equal 0.375."
	).is_equal_approx(0.375, _TOLERANCE)

	# Assert transition
	guard._evaluate_transitions()
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"AC-4 row 1: (0.25,0.25) combined=0.375 > T_SUSPICIOUS=0.3 → must be SUSPICIOUS."
	).is_equal(StealthAI.AlertState.SUSPICIOUS)


## AC-4 row 2: (0.3, 0.0) → combined = 0.3 → AT T_SUSPICIOUS threshold → SUSPICIOUS.
func test_combined_score_pair_0_3_0_at_suspicious_threshold() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 0.3
	guard._perception.sound_accumulator = 0.0

	var expected_combined: float = _oracle_combined(0.3, 0.0)
	assert_float(expected_combined).override_failure_message(
		"AC-4 row 2: oracle combined(0.3,0.0) must equal 0.3."
	).is_equal_approx(0.3, _TOLERANCE)

	# Act
	guard._evaluate_transitions()

	# Assert — AT threshold (>=) transitions
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"AC-4 row 2: (0.3,0.0) combined=0.3 AT T_SUSPICIOUS → must transition (>= check)."
	).is_equal(StealthAI.AlertState.SUSPICIOUS)


## AC-4 row 3: (0.0, 0.3) → combined = 0.3 → AT T_SUSPICIOUS threshold → SUSPICIOUS.
func test_combined_score_pair_0_0_3_at_suspicious_threshold() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 0.0
	guard._perception.sound_accumulator = 0.3

	var expected_combined: float = _oracle_combined(0.0, 0.3)
	assert_float(expected_combined).override_failure_message(
		"AC-4 row 3: oracle combined(0.0,0.3) must equal 0.3."
	).is_equal_approx(0.3, _TOLERANCE)

	# Act
	guard._evaluate_transitions()

	# Assert
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"AC-4 row 3: (0.0,0.3) combined=0.3 AT T_SUSPICIOUS → must transition."
	).is_equal(StealthAI.AlertState.SUSPICIOUS)


## AC-4 row 4: (0.15, 0.3) → combined = 0.3 + 0.5×0.15 = 0.375 → SUSPICIOUS.
func test_combined_score_pair_0_15_0_3_crosses_suspicious() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 0.15
	guard._perception.sound_accumulator = 0.3

	var expected_combined: float = _oracle_combined(0.15, 0.3)
	assert_float(expected_combined).override_failure_message(
		"AC-4 row 4: oracle combined(0.15,0.3) must equal 0.375."
	).is_equal_approx(0.375, _TOLERANCE)

	# Act
	guard._evaluate_transitions()

	# Assert
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"AC-4 row 4: (0.15,0.3) combined=0.375 → must be SUSPICIOUS."
	).is_equal(StealthAI.AlertState.SUSPICIOUS)


## AC-4 row 5: (0.6, 0.0) → combined = 0.6 → AT T_SEARCHING threshold → SEARCHING.
func test_combined_score_pair_0_6_0_at_searching_threshold() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 0.6
	guard._perception.sound_accumulator = 0.0

	var expected_combined: float = _oracle_combined(0.6, 0.0)
	assert_float(expected_combined).override_failure_message(
		"AC-4 row 5: oracle combined(0.6,0.0) must equal 0.6."
	).is_equal_approx(0.6, _TOLERANCE)

	# Act
	guard._evaluate_transitions()

	# Assert — T_SEARCHING is 0.6 by default; AT threshold transitions
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"AC-4 row 5: (0.6,0.0) combined=0.6 AT T_SEARCHING=0.6 → must be SEARCHING."
	).is_equal(StealthAI.AlertState.SEARCHING)


# ── Additional formula edge cases ─────────────────────────────────────────────

## Edge: both accumulators at 1.0 → combined = 1.5 (intentional over-1.0 ceiling
## for decisive cross-channel confirmation per GDD note).
func test_combined_score_both_full_exceeds_one() -> void:
	# Arrange
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 1.0
	guard._perception.sound_accumulator = 1.0

	var expected_combined: float = _oracle_combined(1.0, 1.0)
	assert_float(expected_combined).override_failure_message(
		"AC-4 edge: oracle combined(1.0,1.0) must equal 1.5."
	).is_equal_approx(1.5, _TOLERANCE)

	# Internal _compute_combined should return 1.5
	var actual: float = guard._compute_combined()
	assert_float(actual).override_failure_message(
		"AC-4 edge: _compute_combined() with both=1.0 must return 1.5."
	).is_equal_approx(1.5, _TOLERANCE)


## Edge: both zero → combined = 0.0 → no transition.
func test_combined_score_both_zero_no_transition() -> void:
	var guard: Guard = _make_guard()
	guard._perception.sight_accumulator = 0.0
	guard._perception.sound_accumulator = 0.0

	var actual: float = guard._compute_combined()
	assert_float(actual).override_failure_message(
		"AC-4 edge: combined(0.0,0.0) must equal 0.0."
	).is_equal_approx(0.0, _TOLERANCE)

	guard._evaluate_transitions()
	assert_int(int(guard.current_alert_state)).override_failure_message(
		"AC-4 edge: combined=0.0 → must remain UNAWARE."
	).is_equal(StealthAI.AlertState.UNAWARE)


## Formula: _compute_combined() does NOT store the result (derived per-frame).
## Verify calling it twice with different accumulator values produces different results.
func test_combined_score_not_cached_varies_with_accumulators() -> void:
	var guard: Guard = _make_guard()

	guard._perception.sight_accumulator = 0.4
	guard._perception.sound_accumulator = 0.0
	var first: float = guard._compute_combined()

	guard._perception.sight_accumulator = 0.8
	guard._perception.sound_accumulator = 0.0
	var second: float = guard._compute_combined()

	assert_bool(absf(second - first) > _TOLERANCE).override_failure_message(
		"AC-4: _compute_combined must re-derive from accumulators each call (not cached). "
		+ "first=%.4f second=%.4f" % [first, second]
	).is_true()


## Formula symmetry: combined(a, b) == combined(b, a) since max/min are symmetric.
func test_combined_score_formula_is_symmetric() -> void:
	var guard: Guard = _make_guard()

	guard._perception.sight_accumulator = 0.3
	guard._perception.sound_accumulator = 0.6
	var ab: float = guard._compute_combined()

	guard._perception.sight_accumulator = 0.6
	guard._perception.sound_accumulator = 0.3
	var ba: float = guard._compute_combined()

	assert_float(ab).override_failure_message(
		"AC-4 symmetry: combined(0.3,0.6) must equal combined(0.6,0.3)."
	).is_equal_approx(ba, _TOLERANCE)
