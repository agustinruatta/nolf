# tests/unit/foundation/post_process_stack/sepia_dim_tween_state_machine_test.gd
#
# SepiaDimTweenStateMachineTest — GdUnit4 suite for Story PPS-003.
#
# WHAT IS TESTED
#   AC-1: IDLE → enable → FADING_IN; is_sepia_active = true; tween is_valid.
#   AC-2: ACTIVE → disable → FADING_OUT.
#   AC-3: FADING_IN + dim_intensity=0.35 → disable → FADING_OUT; new tween
#         starts from 0.35, NOT from 1.0 (reverse-tween from live value).
#   AC-4: IDLE → disable → no-op (state IDLE, no tween, intensity unchanged).
#   AC-5: ACTIVE → enable → no-op (state ACTIVE, intensity stays 1.0).
#   AC-6: FADING_OUT + dim_intensity=0.65 → enable → FADING_IN; new tween
#         starts from 0.65, NOT from 0.0 (reverse-tween from live value).
#   AC-7: FADING_IN → enable → no-op (existing tween reference unchanged).
#
# DETERMINISM STRATEGY
#   Tweens are created but their internal tick never runs during synchronous
#   test code — process frames do not advance. This means:
#     • State transitions that happen BEFORE tween progress can be asserted
#       immediately after the call.
#     • _dim_intensity at the moment a new tween is created equals the value
#       that was stored before the call — verifiable by reading get_dim_intensity()
#       immediately after enable/disable.
#     • tween.is_valid() is true immediately after create_tween(), before any
#       process tick.
#   No sleep, no await, no Tween.set_speed_scale needed.
#
# INTERNAL STATE ACCESS
#   get_sepia_state() and get_dim_intensity() are the public introspection
#   methods added by PPS-003 specifically for test verification.
#   Direct field access (_sepia_state, _dim_intensity) is avoided — use
#   the accessor methods per the story spec.
#
# GATE STATUS
#   Story PPS-003 | Logic type → BLOCKING gate (test-evidence requirement).
#
# NAMING CONVENTION (per tests/README.md)
#   File  : [system]_[feature]_test.gd
#   Class : extends GdUnitTestSuite
#   Funcs : test_[system]_[scenario]_[expected_result]
#
# REFERENCES
#   Implements: design/gdd/post-process-stack.md §States and Transitions,
#               §Edge Cases (reverse tween), §Transition Rules
#   ADR-0005: sepia reads post-outline buffer — IDLE must contribute 0 ms.
#   ADR-0008 Slot 3: sepia pass ≤0.5 ms ACTIVE, 0 ms IDLE.

class_name SepiaDimTweenStateMachineTest
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Force the instance into a specific state and dim_intensity without going
## through the tween. Used to set up mid-transition scenarios (AC-2, AC-3,
## AC-5, AC-6) deterministically without waiting for tween progress.
##
## This directly assigns private vars which GDScript permits within the same
## process. It mirrors what the engine would have done after tween progress,
## giving us a known starting condition for each AC.
func _force_state(
	instance: PostProcessStackService,
	state: PostProcessStackService.SepiaState,
	dim: float,
	sepia_active: bool
) -> void:
	instance._sepia_state = state
	instance._dim_intensity = dim
	instance.is_sepia_active = sepia_active


# ---------------------------------------------------------------------------
# AC-1: IDLE → enable_sepia_dim() → FADING_IN
# ---------------------------------------------------------------------------

## AC-1: Calling enable_sepia_dim() from IDLE transitions to FADING_IN,
## sets is_sepia_active = true, and starts a valid tween.
##
## GDD §States and Transitions: "IDLE + enable → FADING_IN; dim_intensity
## begins moving 0.0 → 1.0."
func test_post_process_sepia_enable_from_idle_transitions_to_fading_in_with_active_flag() -> void:
	# Arrange
	var pps: PostProcessStackService = auto_free(PostProcessStackService.new())
	# Confirm initial state is IDLE (invariant, not the assertion).
	assert_that(pps.get_sepia_state()).is_equal(PostProcessStackService.SepiaState.IDLE)

	# Act
	pps.enable_sepia_dim()

	# Assert — state machine transitions.
	assert_that(pps.get_sepia_state()).override_failure_message(
		"AC-1: enable_sepia_dim() from IDLE must transition state to FADING_IN."
	).is_equal(PostProcessStackService.SepiaState.FADING_IN)

	assert_bool(pps.is_sepia_active).override_failure_message(
		"AC-1: enable_sepia_dim() from IDLE must set is_sepia_active = true."
	).is_true()

	# Tween must be in-flight (is_valid() is true until the tween completes or
	# is killed — no process frames have run in this sync test).
	assert_bool(pps._dim_tween != null and pps._dim_tween.is_valid()).override_failure_message(
		"AC-1: enable_sepia_dim() from IDLE must start a valid in-flight Tween."
	).is_true()


# ---------------------------------------------------------------------------
# AC-2: ACTIVE → disable_sepia_dim() → FADING_OUT
# ---------------------------------------------------------------------------

## AC-2: Calling disable_sepia_dim() from ACTIVE transitions to FADING_OUT
## and starts a tween heading toward 0.0.
##
## GDD §States and Transitions: "ACTIVE + disable → FADING_OUT; dim_intensity
## begins moving 1.0 → 0.0."
func test_post_process_sepia_disable_from_active_transitions_to_fading_out() -> void:
	# Arrange
	var pps: PostProcessStackService = auto_free(PostProcessStackService.new())
	_force_state(pps, PostProcessStackService.SepiaState.ACTIVE, 1.0, true)

	# Act
	pps.disable_sepia_dim()

	# Assert
	assert_that(pps.get_sepia_state()).override_failure_message(
		"AC-2: disable_sepia_dim() from ACTIVE must transition state to FADING_OUT."
	).is_equal(PostProcessStackService.SepiaState.FADING_OUT)

	assert_bool(pps._dim_tween != null and pps._dim_tween.is_valid()).override_failure_message(
		"AC-2: disable_sepia_dim() from ACTIVE must start a valid in-flight Tween."
	).is_true()

	# is_sepia_active stays true until FADING_OUT tween completes.
	assert_bool(pps.is_sepia_active).override_failure_message(
		"AC-2: is_sepia_active must remain true during FADING_OUT (set false only on completion)."
	).is_true()


# ---------------------------------------------------------------------------
# AC-3: FADING_IN (mid-fade) → disable_sepia_dim() → reverse tween from live value
# ---------------------------------------------------------------------------

## AC-3: Calling disable_sepia_dim() while FADING_IN kills the existing tween
## and starts a new one from the CURRENT dim_intensity, not from 1.0.
##
## GDD §Edge Cases "reverse tween": "No teleport to 1.0 first."
## The starting value of the new tween equals the _dim_intensity at the moment
## of the call — verifiable synchronously because no process frames advance.
func test_post_process_sepia_disable_during_fading_in_starts_reverse_tween_from_current_value() -> void:
	# Arrange — simulate mid-fade state: FADING_IN with intensity at 0.35.
	var pps: PostProcessStackService = auto_free(PostProcessStackService.new())
	_force_state(pps, PostProcessStackService.SepiaState.FADING_IN, 0.35, true)

	# Act
	pps.disable_sepia_dim()

	# Assert state transition.
	assert_that(pps.get_sepia_state()).override_failure_message(
		"AC-3: disable_sepia_dim() during FADING_IN must transition to FADING_OUT."
	).is_equal(PostProcessStackService.SepiaState.FADING_OUT)

	# Assert that dim_intensity was NOT reset to 1.0 before creating the new tween.
	# The new tween starts from whatever _dim_intensity was at call time (0.35).
	# Since no frames advance synchronously, _dim_intensity reflects the start value.
	assert_float(pps.get_dim_intensity()).override_failure_message(
		"AC-3: reverse tween must start from the current dim_intensity (≈0.35), "
		+ "not from 1.0 or 0.0. Got: %.4f" % pps.get_dim_intensity()
	).is_between(0.34, 0.36)

	assert_bool(pps._dim_tween != null and pps._dim_tween.is_valid()).override_failure_message(
		"AC-3: A valid Tween must be active after reverse from FADING_IN."
	).is_true()


# ---------------------------------------------------------------------------
# AC-4: IDLE → disable_sepia_dim() → no-op
# ---------------------------------------------------------------------------

## AC-4: Calling disable_sepia_dim() from IDLE is a no-op — state stays IDLE,
## dim_intensity stays 0.0, no Tween is created, no error logged.
##
## GDD §Transition Rules: "IDLE + disable → IDLE (idempotent)."
func test_post_process_sepia_disable_from_idle_is_noop() -> void:
	# Arrange
	var pps: PostProcessStackService = auto_free(PostProcessStackService.new())
	# Record tween ref before call (should be null initially).
	var tween_before: Tween = pps._dim_tween

	# Act
	pps.disable_sepia_dim()

	# Assert — nothing changed.
	assert_that(pps.get_sepia_state()).override_failure_message(
		"AC-4: disable_sepia_dim() from IDLE must leave state as IDLE."
	).is_equal(PostProcessStackService.SepiaState.IDLE)

	assert_float(pps.get_dim_intensity()).override_failure_message(
		"AC-4: disable_sepia_dim() from IDLE must not change dim_intensity (expected 0.0)."
	).is_equal(0.0)

	assert_bool(pps.is_sepia_active).override_failure_message(
		"AC-4: disable_sepia_dim() from IDLE must not set is_sepia_active."
	).is_false()

	# No new tween was created — the ref must still be the same null value.
	assert_object(pps._dim_tween).override_failure_message(
		"AC-4: disable_sepia_dim() from IDLE must not create a Tween."
	).is_equal(tween_before)


# ---------------------------------------------------------------------------
# AC-5: ACTIVE → enable_sepia_dim() → no-op
# ---------------------------------------------------------------------------

## AC-5: Calling enable_sepia_dim() from ACTIVE is a no-op — state stays
## ACTIVE, dim_intensity stays 1.0, no new Tween is created.
##
## GDD §Transition Rules: "ACTIVE + enable → ACTIVE (idempotent)."
func test_post_process_sepia_enable_from_active_is_noop() -> void:
	# Arrange — set ACTIVE state manually.
	var pps: PostProcessStackService = auto_free(PostProcessStackService.new())
	_force_state(pps, PostProcessStackService.SepiaState.ACTIVE, 1.0, true)
	var tween_before: Tween = pps._dim_tween  # null (no tween active in ACTIVE state).

	# Act
	pps.enable_sepia_dim()

	# Assert — nothing changed.
	assert_that(pps.get_sepia_state()).override_failure_message(
		"AC-5: enable_sepia_dim() from ACTIVE must leave state as ACTIVE."
	).is_equal(PostProcessStackService.SepiaState.ACTIVE)

	assert_float(pps.get_dim_intensity()).override_failure_message(
		"AC-5: enable_sepia_dim() from ACTIVE must not change dim_intensity (expected 1.0)."
	).is_equal(1.0)

	assert_object(pps._dim_tween).override_failure_message(
		"AC-5: enable_sepia_dim() from ACTIVE must not create a new Tween."
	).is_equal(tween_before)


# ---------------------------------------------------------------------------
# AC-6: FADING_OUT (mid-fade) → enable_sepia_dim() → reverse tween from live value
# ---------------------------------------------------------------------------

## AC-6: Calling enable_sepia_dim() while FADING_OUT kills the existing tween
## and starts a new one from the CURRENT dim_intensity (≈0.65), not from 0.0.
## is_sepia_active must remain true throughout — never flipped false during
## a FADING_OUT→FADING_IN reversal.
##
## GDD §Transition Rules: "Symmetric reverse — no teleport at any intermediate."
func test_post_process_sepia_enable_during_fading_out_starts_reverse_tween_from_current_value() -> void:
	# Arrange — simulate mid-fade-out state: FADING_OUT with intensity at 0.65.
	var pps: PostProcessStackService = auto_free(PostProcessStackService.new())
	_force_state(pps, PostProcessStackService.SepiaState.FADING_OUT, 0.65, true)

	# Act
	pps.enable_sepia_dim()

	# Assert state transition.
	assert_that(pps.get_sepia_state()).override_failure_message(
		"AC-6: enable_sepia_dim() during FADING_OUT must transition to FADING_IN."
	).is_equal(PostProcessStackService.SepiaState.FADING_IN)

	# Assert reverse tween starts from current value (0.65), not from 0.0.
	assert_float(pps.get_dim_intensity()).override_failure_message(
		"AC-6: reverse tween must start from the current dim_intensity (≈0.65), "
		+ "not from 0.0 or 1.0. Got: %.4f" % pps.get_dim_intensity()
	).is_between(0.64, 0.66)

	# is_sepia_active must remain true — never false during a mid-fade reversal.
	assert_bool(pps.is_sepia_active).override_failure_message(
		"AC-6: is_sepia_active must remain true during FADING_OUT→FADING_IN reversal."
	).is_true()

	assert_bool(pps._dim_tween != null and pps._dim_tween.is_valid()).override_failure_message(
		"AC-6: A valid Tween must be active after reverse from FADING_OUT."
	).is_true()


# ---------------------------------------------------------------------------
# AC-7: FADING_IN → enable_sepia_dim() → no-op (existing tween uninterrupted)
# ---------------------------------------------------------------------------

## AC-7: Calling enable_sepia_dim() while already FADING_IN is a no-op —
## the in-flight Tween continues uninterrupted toward 1.0. The tween
## reference must be the same object (no kill-and-restart).
##
## GDD §Transition Rules: "Only one Tween instance manages dim_intensity at
## a time." / "FADING_IN + enable → FADING_IN (no-op)."
func test_post_process_sepia_enable_during_fading_in_is_noop_tween_unchanged() -> void:
	# Arrange — start a real fade from IDLE to get an in-flight tween.
	var pps: PostProcessStackService = auto_free(PostProcessStackService.new())
	pps.enable_sepia_dim()
	assert_that(pps.get_sepia_state()).is_equal(PostProcessStackService.SepiaState.FADING_IN)

	# Capture the tween reference created by the first call.
	var tween_after_first_call: Tween = pps._dim_tween
	assert_bool(tween_after_first_call != null and tween_after_first_call.is_valid()).override_failure_message(
		"AC-7 setup: first enable_sepia_dim() must create a valid tween."
	).is_true()

	# Act — second call while still FADING_IN.
	pps.enable_sepia_dim()

	# Assert — state stays FADING_IN.
	assert_that(pps.get_sepia_state()).override_failure_message(
		"AC-7: enable_sepia_dim() during FADING_IN must leave state as FADING_IN."
	).is_equal(PostProcessStackService.SepiaState.FADING_IN)

	# Assert — the tween reference is the SAME object (no kill-and-restart).
	assert_object(pps._dim_tween).override_failure_message(
		"AC-7: enable_sepia_dim() during FADING_IN must NOT replace the existing Tween. "
		+ "Only one Tween instance manages dim_intensity at a time."
	).is_equal(tween_after_first_call)

	# The original tween must still be valid (not killed).
	assert_bool(pps._dim_tween.is_valid()).override_failure_message(
		"AC-7: The existing in-flight Tween must remain valid and uninterrupted."
	).is_true()
