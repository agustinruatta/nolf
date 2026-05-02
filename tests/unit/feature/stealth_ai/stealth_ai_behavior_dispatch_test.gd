# tests/unit/feature/stealth_ai/stealth_ai_behavior_dispatch_test.gd
#
# StealthAIBehaviorDispatchTest — Story SAI-006 AC-2 / AC-3 / AC-4 / AC-5.
#
# COVERED ACCEPTANCE CRITERIA (Story SAI-006)
#   AC-2: UNAWARE → SUSPICIOUS sets max_speed=0 + target_position=guard.global_position (stop in place)
#   AC-3: SUSPICIOUS → SEARCHING sets max_speed=investigate_speed_mps + target_position=last_sight_position
#   AC-4: SEARCHING → COMBAT sets max_speed=combat_sprint_speed_mps + target_position=last_sight_position
#   AC-5: COMBAT → SEARCHING de-escalation sets max_speed=investigate_speed_mps
#   Initial: UNAWARE state uses patrol_speed_mps after _dispatch_behavior_for_state
#
# TEST APPROACH
#   Direct assertions on NavigationAgent3D.max_speed and target_position after
#   state transitions. No real nav-mesh navigation required — tests verify the
#   dispatch contract, not actual movement.
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name StealthAIBehaviorDispatchTest
extends GdUnitTestSuite

const _GUARD_SCENE_PATH: String = "res://src/gameplay/stealth/Guard.tscn"


# ── Fixture helper ────────────────────────────────────────────────────────────

func _make_guard() -> Guard:
	var scene: PackedScene = load(_GUARD_SCENE_PATH) as PackedScene
	var guard: Guard = scene.instantiate() as Guard
	add_child(guard)
	auto_free(guard)
	return guard


# ── Initial state: UNAWARE patrol speed ──────────────────────────────────────

## After _ready() runs, fresh guard at UNAWARE has NavigationAgent3D.max_speed
## set to patrol_speed_mps via _dispatch_behavior_for_state(UNAWARE).
func test_unaware_initial_state_uses_patrol_speed() -> void:
	var guard: Guard = _make_guard()

	assert_float(guard._navigation_agent.max_speed).override_failure_message(
		"AC-1 initial: fresh guard in UNAWARE must have max_speed == patrol_speed_mps."
	).is_equal_approx(guard.patrol_speed_mps, 0.001)


# ── AC-2: UNAWARE → SUSPICIOUS stops movement ────────────────────────────────

## AC-2: Transitioning to SUSPICIOUS sets max_speed=0 (stop) and target_position
## to the guard's own global_position (stop-in-place semantic).
func test_unaware_to_suspicious_sets_max_speed_to_zero_and_stops_in_place() -> void:
	var guard: Guard = _make_guard()
	# Place guard at a known position so we can assert target_position equality.
	guard.global_position = Vector3(5.0, 0.0, 5.0)

	guard._perception.sight_accumulator = 0.35
	guard._perception.sound_accumulator = 0.0
	guard._evaluate_transitions()

	assert_int(int(guard.current_alert_state)).is_equal(StealthAI.AlertState.SUSPICIOUS)
	assert_float(guard._navigation_agent.max_speed).override_failure_message(
		"AC-2: SUSPICIOUS state must set NavigationAgent3D.max_speed to 0.0 (stop)."
	).is_equal_approx(0.0, 0.001)
	# target_position should be guard.global_position (stop-in-place)
	var target: Vector3 = guard._navigation_agent.target_position
	assert_bool(target.is_equal_approx(guard.global_position)).override_failure_message(
		"AC-2: SUSPICIOUS target_position must equal guard.global_position (stop-in-place)."
	).is_true()


# ── AC-3: SUSPICIOUS → SEARCHING navigates to LKP ────────────────────────────

## AC-3: SEARCHING sets max_speed to investigate_speed_mps and target_position
## to _perception_cache.last_sight_position (LKP).
func test_suspicious_to_searching_navigates_to_last_sight_position() -> void:
	var guard: Guard = _make_guard()
	# Set up a known LKP in the perception cache
	var lkp: Vector3 = Vector3(10.0, 0.0, 20.0)
	guard._perception._perception_cache.initialized = true
	guard._perception._perception_cache.last_sight_position = lkp

	# Force into SEARCHING via lattice escalation
	guard.force_alert_state(StealthAI.AlertState.SUSPICIOUS, StealthAI.AlertCause.SAW_PLAYER)
	guard.force_alert_state(StealthAI.AlertState.SEARCHING, StealthAI.AlertCause.SAW_PLAYER)

	assert_float(guard._navigation_agent.max_speed).override_failure_message(
		"AC-3: SEARCHING max_speed must equal investigate_speed_mps."
	).is_equal_approx(guard.investigate_speed_mps, 0.001)
	assert_bool(guard._navigation_agent.target_position.is_equal_approx(lkp)).override_failure_message(
		"AC-3: SEARCHING target_position must equal _perception_cache.last_sight_position."
	).is_true()


# ── AC-4: SEARCHING → COMBAT uses combat sprint speed ────────────────────────

## AC-4: COMBAT sets max_speed to combat_sprint_speed_mps and target_position
## to _perception_cache.last_sight_position (direct navigate, no cover eval in VS).
func test_searching_to_combat_uses_combat_sprint_speed() -> void:
	var guard: Guard = _make_guard()
	var lkp: Vector3 = Vector3(15.0, 0.0, 30.0)
	guard._perception._perception_cache.initialized = true
	guard._perception._perception_cache.last_sight_position = lkp

	# Climb the lattice to COMBAT
	guard.force_alert_state(StealthAI.AlertState.SUSPICIOUS, StealthAI.AlertCause.SAW_PLAYER)
	guard.force_alert_state(StealthAI.AlertState.SEARCHING, StealthAI.AlertCause.SAW_PLAYER)
	guard.force_alert_state(StealthAI.AlertState.COMBAT, StealthAI.AlertCause.SAW_PLAYER)

	assert_float(guard._navigation_agent.max_speed).override_failure_message(
		"AC-4: COMBAT max_speed must equal combat_sprint_speed_mps."
	).is_equal_approx(guard.combat_sprint_speed_mps, 0.001)
	assert_bool(guard._navigation_agent.target_position.is_equal_approx(lkp)).override_failure_message(
		"AC-4: COMBAT target_position must equal _perception_cache.last_sight_position (VS scope: direct navigate)."
	).is_true()


# ── AC-5: COMBAT → SEARCHING de-escalation ──────────────────────────────────

## AC-5: COMBAT → SEARCHING de-escalation sets max_speed back to investigate_speed.
## (Trigger via _de_escalate_to since the timer mechanism is Story 007.)
func test_combat_to_searching_de_escalation_uses_investigate_speed() -> void:
	var guard: Guard = _make_guard()
	# Climb to COMBAT first
	guard.force_alert_state(StealthAI.AlertState.SUSPICIOUS, StealthAI.AlertCause.SAW_PLAYER)
	guard.force_alert_state(StealthAI.AlertState.SEARCHING, StealthAI.AlertCause.SAW_PLAYER)
	guard.force_alert_state(StealthAI.AlertState.COMBAT, StealthAI.AlertCause.SAW_PLAYER)
	assert_float(guard._navigation_agent.max_speed).is_equal_approx(guard.combat_sprint_speed_mps, 0.001)

	# De-escalate via _de_escalate_to (Story 007 timer source path)
	guard._de_escalate_to(StealthAI.AlertState.SEARCHING)

	assert_int(int(guard.current_alert_state)).is_equal(StealthAI.AlertState.SEARCHING)
	assert_float(guard._navigation_agent.max_speed).override_failure_message(
		"AC-5: COMBAT → SEARCHING de-escalation must reset max_speed to investigate_speed_mps."
	).is_equal_approx(guard.investigate_speed_mps, 0.001)


## AC-5 / AC-2: SUSPICIOUS → UNAWARE de-escalation restores patrol speed.
func test_suspicious_to_unaware_de_escalation_restores_patrol_speed() -> void:
	var guard: Guard = _make_guard()
	guard.force_alert_state(StealthAI.AlertState.SUSPICIOUS, StealthAI.AlertCause.SAW_PLAYER)
	assert_float(guard._navigation_agent.max_speed).is_equal_approx(0.0, 0.001)

	# De-escalate back to UNAWARE
	guard._de_escalate_to(StealthAI.AlertState.UNAWARE)

	assert_int(int(guard.current_alert_state)).is_equal(StealthAI.AlertState.UNAWARE)
	assert_float(guard._navigation_agent.max_speed).override_failure_message(
		"AC-5: SUSPICIOUS → UNAWARE de-escalation must restore max_speed to patrol_speed_mps."
	).is_equal_approx(guard.patrol_speed_mps, 0.001)
