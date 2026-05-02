# tests/integration/feature/stealth_ai/stealth_ai_patrol_behavior_test.gd
#
# StealthAIPatrolBehaviorTest — Story SAI-006 AC-1 (logic-level integration).
#
# COVERED ACCEPTANCE CRITERIA (Story SAI-006)
#   AC-1: PatrolController dispatches successive Path3D waypoints to
#         NavigationAgent3D.target_position on navigation_finished signal.
#         Wraps to first waypoint at path end.
#
# NAV-MESH NOTE
#   Real nav-mesh navigation requires editor-baked NavigationMesh resources.
#   Headless GdUnit4 cannot fully simulate movement frames against a nav mesh.
#   This file tests the LOGIC layer: waypoint advancement on signal emit, path
#   wrapping, signal connect/disconnect lifecycle. Full real-movement playtest
#   evidence is deferred to production/qa/evidence/ (when SAI-006 reaches
#   playtest sign-off in a later sprint).
#
# FRAMEWORK
#   GdUnit4 v6.0.0 — extends GdUnitTestSuite. Headless-safe.

class_name StealthAIPatrolBehaviorTest
extends GdUnitTestSuite

const _GUARD_SCENE_PATH: String = "res://src/gameplay/stealth/Guard.tscn"


# ── Fixture helpers ───────────────────────────────────────────────────────────

func _make_guard() -> Guard:
	var scene: PackedScene = load(_GUARD_SCENE_PATH) as PackedScene
	var guard: Guard = scene.instantiate() as Guard
	add_child(guard)
	auto_free(guard)
	return guard


## Builds a Path3D with a Curve3D containing 4 evenly-spaced points along the
## X-axis (separated by 5m each). Returns the Path3D node, parented for cleanup.
func _make_test_path3d() -> Path3D:
	var path: Path3D = Path3D.new()
	var curve: Curve3D = Curve3D.new()
	curve.add_point(Vector3(0.0, 0.0, 0.0))
	curve.add_point(Vector3(5.0, 0.0, 0.0))
	curve.add_point(Vector3(10.0, 0.0, 0.0))
	curve.add_point(Vector3(15.0, 0.0, 0.0))
	path.curve = curve
	add_child(path)
	auto_free(path)
	return path


## Creates a PatrolController as a child of the given parent with a 4-waypoint
## test path and offsets at exactly the curve point positions (0, 5, 10, 15).
func _make_patrol_controller_on(parent: Node) -> PatrolController:
	var controller: PatrolController = PatrolController.new()
	parent.add_child(controller)
	auto_free(controller)

	var path: Path3D = _make_test_path3d()
	controller.path = path
	controller.waypoint_offsets_m = [0.0, 5.0, 10.0, 15.0]
	# Re-trigger _ready logic since add_child happened before path was set.
	# In Godot, _ready already fired; we must run controller's "post-init" manually.
	# For test purposes, the controller's _ready already auto-populates if offsets
	# are empty — by setting offsets explicitly AFTER _ready, we override that.
	return controller


# ── AC-1: First waypoint dispatch on start_patrol ────────────────────────────

## AC-1: start_patrol() dispatches the first waypoint to NavigationAgent3D.
func test_start_patrol_dispatches_first_waypoint() -> void:
	var guard: Guard = _make_guard()
	var path: Path3D = _make_test_path3d()
	guard._patrol_controller.path = path
	guard._patrol_controller.waypoint_offsets_m = [0.0, 5.0, 10.0, 15.0]

	# Act
	guard._patrol_controller.start_patrol()

	# Assert — target_position is at waypoint 0 (first dispatch)
	var expected: Vector3 = path.curve.sample_baked(0.0, false)
	expected = path.global_transform * expected
	assert_bool(
		guard._navigation_agent.target_position.is_equal_approx(expected)
	).override_failure_message(
		"AC-1: start_patrol() must dispatch waypoint[0] to NavigationAgent3D.target_position."
	).is_true()


# ── AC-1: Waypoint advancement on navigation_finished ────────────────────────

## AC-1: navigation_finished signal advances to the next waypoint.
func test_waypoint_advances_on_navigation_finished_signal() -> void:
	var guard: Guard = _make_guard()
	var path: Path3D = _make_test_path3d()
	guard._patrol_controller.path = path
	guard._patrol_controller.waypoint_offsets_m = [0.0, 5.0, 10.0, 15.0]
	guard._patrol_controller.start_patrol()

	# Capture position after first dispatch
	var first_target: Vector3 = guard._navigation_agent.target_position

	# Act — manually fire navigation_finished
	guard._navigation_agent.navigation_finished.emit()

	# Assert — target_position advanced
	var second_target: Vector3 = guard._navigation_agent.target_position
	assert_bool(second_target.is_equal_approx(first_target)).override_failure_message(
		"AC-1: target_position must change after navigation_finished fires."
	).is_false()
	# And specifically — second_target should be waypoint[1]
	var expected: Vector3 = path.curve.sample_baked(5.0, false)
	expected = path.global_transform * expected
	assert_bool(second_target.is_equal_approx(expected)).override_failure_message(
		"AC-1: second waypoint dispatched must be at offset 5.0m on the curve."
	).is_true()


# ── AC-1: Wrap to first waypoint at path end ─────────────────────────────────

## AC-1: After all 4 waypoints visited (4 navigation_finished emits since we
## start with waypoint 0 dispatched), the controller wraps back to waypoint 0.
func test_patrol_wraps_to_first_waypoint_at_path_end() -> void:
	var guard: Guard = _make_guard()
	var path: Path3D = _make_test_path3d()
	guard._patrol_controller.path = path
	guard._patrol_controller.waypoint_offsets_m = [0.0, 5.0, 10.0, 15.0]
	guard._patrol_controller.start_patrol()

	# Cycle through all 4 waypoints (waypoint[0] dispatched on start; need 4 emits
	# to see wraparound to waypoint[0] again)
	for i: int in range(4):
		guard._navigation_agent.navigation_finished.emit()

	# Act — current target should now be waypoint[0] again (wrapped)
	var expected: Vector3 = path.curve.sample_baked(0.0, false)
	expected = path.global_transform * expected
	assert_bool(
		guard._navigation_agent.target_position.is_equal_approx(expected)
	).override_failure_message(
		"AC-1: after cycling through all 4 waypoints, target_position must wrap to waypoint[0]."
	).is_true()


# ── AC-1: stop_patrol disconnects signal ─────────────────────────────────────

## AC-1: stop_patrol() disconnects from navigation_finished — subsequent emits
## do not advance waypoints.
func test_stop_patrol_disconnects_signal_and_freezes_waypoint_advancement() -> void:
	var guard: Guard = _make_guard()
	var path: Path3D = _make_test_path3d()
	guard._patrol_controller.path = path
	guard._patrol_controller.waypoint_offsets_m = [0.0, 5.0, 10.0, 15.0]
	guard._patrol_controller.start_patrol()
	var target_before_stop: Vector3 = guard._navigation_agent.target_position

	# Act — stop and emit a fake nav_finished
	guard._patrol_controller.stop_patrol()
	guard._navigation_agent.navigation_finished.emit()

	# Assert — signal disconnected, target_position unchanged
	assert_bool(guard._patrol_controller.is_patrolling()).override_failure_message(
		"AC-1: is_patrolling() must return false after stop_patrol()."
	).is_false()
	assert_bool(
		guard._navigation_agent.target_position.is_equal_approx(target_before_stop)
	).override_failure_message(
		"AC-1: target_position must NOT change after stop_patrol() + navigation_finished emit."
	).is_true()


# ── AC-1 / E.12: Null path graceful no-op ────────────────────────────────────

## AC-1 + E.12: start_patrol with null path is a graceful no-op (no crash).
func test_start_patrol_with_null_path_does_not_crash_or_patrol() -> void:
	var guard: Guard = _make_guard()
	guard._patrol_controller.path = null
	guard._patrol_controller.waypoint_offsets_m = []

	# Act — should not crash
	guard._patrol_controller.start_patrol()

	# Assert — _is_patrolling stays false (graceful no-op)
	assert_bool(guard._patrol_controller.is_patrolling()).override_failure_message(
		"AC-1 / E.12: null path → start_patrol must be no-op (is_patrolling stays false)."
	).is_false()


# ── State integration: UNAWARE entry triggers start_patrol ────────────────────

## Integration: Guard's _dispatch_behavior_for_state(UNAWARE) calls start_patrol
## on the PatrolController. Verified via the controller's is_patrolling() flag
## after a fresh guard's _ready() runs.
##
## NOTE: A fresh guard has no Path3D assigned, so start_patrol is a graceful
## no-op (is_patrolling stays false). This test verifies the dispatch invocation
## by setting up a path BEFORE the transition.
func test_unaware_state_entry_invokes_patrol_controller_start_patrol() -> void:
	var guard: Guard = _make_guard()
	var path: Path3D = _make_test_path3d()
	guard._patrol_controller.path = path
	guard._patrol_controller.waypoint_offsets_m = [0.0, 5.0, 10.0, 15.0]

	# Force a transition out and back to UNAWARE to re-trigger start_patrol
	guard.force_alert_state(StealthAI.AlertState.SUSPICIOUS, StealthAI.AlertCause.SAW_PLAYER)
	assert_bool(guard._patrol_controller.is_patrolling()).override_failure_message(
		"SUSPICIOUS state must call stop_patrol — is_patrolling false."
	).is_false()
	guard._de_escalate_to(StealthAI.AlertState.UNAWARE)

	# After re-entering UNAWARE, patrol should be active
	assert_bool(guard._patrol_controller.is_patrolling()).override_failure_message(
		"UNAWARE state entry must invoke PatrolController.start_patrol()."
	).is_true()
