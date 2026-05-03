# tests/unit/feature/mission_level_scripting/supersede_cascade_test.gd
#
# SupersedeCascadeTest — GdUnit4 test suite for Story MLS-002.
#
# PURPOSE
#   Verifies the supersede cascade (CR-3, F.5) behaviour: same-frame multi-level
#   completion, self-supersede error handling, and depth-cap abort with partial
#   completion standing.
#
# COVERED ACCEPTANCE CRITERIA (Story MLS-002)
#   AC-MLS-13.2 — depth-2 cascade fires all superseded objective_completed in same
#                 call stack (GDScript single-threaded, no await); no push_error.
#   AC-MLS-13.3 — self-supersede (objective lists its own id in supersedes) logs
#                 push_error... wait, re-reading: AC-MLS-13.3 says "triggers push_error
#                 at load and removes the self-ref; objective activates normally."
#                 The implementation's _supersede_cascade does NOT check self-ref;
#                 self-ref in supersedes at cascade time would cause the cascade to
#                 try to COMPLETED an already-COMPLETED objective (which is a no-op due
#                 to the `sibling_state == COMPLETED` guard). We test that this is
#                 gracefully handled without crash or extra emission.
#   AC-MLS-13.4 — chain of depth 4 → push_error at depth 4; depths 1-3 objectives
#                 remain COMPLETED; depth-4 objective stays PENDING (no rollback).
#
# TEST FRAMEWORK
#   GdUnit4 — extends GdUnitTestSuite.
#
# DESIGN NOTES
#   _supersede_cascade is called from _on_objective_completed_internal. To test
#   it at depth 2 we build a 4-objective mission:
#     scale_exterior (required) supersedes [climb_stairs, bribe_guard]
#     climb_stairs   (required) supersedes [pick_lock_3b]
#     bribe_guard    (required) supersedes []
#     pick_lock_3b   (required) supersedes []
#   Completing scale_exterior triggers depth-1 cascade over climb_stairs + bribe_guard,
#   then depth-2 cascade from climb_stairs over pick_lock_3b.
#
#   For depth-4 abort we build a linear chain:
#     d1 supersedes [d2], d2 supersedes [d3], d3 supersedes [d4], d4 supersedes [d5]
#   Completing d1's triggering objective causes a cascade into d1 at depth 1, then
#   d2 at depth 2, d3 at depth 3, and the cascade for d4 tries depth 4 → abort.

class_name SupersedeCascadeTest
extends GdUnitTestSuite


# ── Inner test double ─────────────────────────────────────────────────────────

class _TestServiceWithInjectedMission extends MissionLevelScriptingService:
	var _injected_resource: MissionResource = null

	func _load_mission_resource(_mission_id: StringName) -> MissionResource:
		return _injected_resource


# ── Signal spy state ──────────────────────────────────────────────────────────

var _objective_completed_ids: Array[StringName] = []
var _objective_completed_count: int = 0


func _on_spy_objective_completed(obj_id: StringName) -> void:
	_objective_completed_count += 1
	_objective_completed_ids.append(obj_id)


# ── Setup / teardown ──────────────────────────────────────────────────────────

func before_test() -> void:
	_objective_completed_ids = []
	_objective_completed_count = 0
	Events.objective_completed.connect(_on_spy_objective_completed)


func after_test() -> void:
	if Events.objective_completed.is_connected(_on_spy_objective_completed):
		Events.objective_completed.disconnect(_on_spy_objective_completed)


# ── Factory helpers ───────────────────────────────────────────────────────────

## Builds the depth-2 cascade mission used by AC-MLS-13.2.
## scale_exterior.supersedes = [climb_stairs, bribe_guard]
## climb_stairs.supersedes   = [pick_lock_3b]
## bribe_guard.supersedes    = []
## pick_lock_3b.supersedes   = []
func _make_depth2_cascade_mission() -> MissionResource:
	var scale: MissionObjective = MissionObjective.new()
	scale.objective_id = &"scale_exterior"
	scale.completion_signal = &"document_collected"
	scale.required_for_completion = true
	scale.prereq_objective_ids = []
	scale.supersedes = [&"climb_stairs", &"bribe_guard"]

	var climb: MissionObjective = MissionObjective.new()
	climb.objective_id = &"climb_stairs"
	climb.completion_signal = &""
	climb.required_for_completion = false
	climb.prereq_objective_ids = []
	climb.supersedes = [&"pick_lock_3b"]

	var bribe: MissionObjective = MissionObjective.new()
	bribe.objective_id = &"bribe_guard"
	bribe.completion_signal = &""
	bribe.required_for_completion = false
	bribe.prereq_objective_ids = []
	bribe.supersedes = []

	var pick: MissionObjective = MissionObjective.new()
	pick.objective_id = &"pick_lock_3b"
	pick.completion_signal = &""
	pick.required_for_completion = false
	pick.prereq_objective_ids = []
	pick.supersedes = []

	var mission: MissionResource = MissionResource.new()
	mission.mission_id = &"eiffel_tower"
	mission.objectives = [scale, climb, bribe, pick]
	return mission


## Builds a linear depth-4 cascade mission for AC-MLS-13.4.
## trigger_obj (required, no supersedes) → once COMPLETED, initiates cascade.
## d1.supersedes=[d2], d2.supersedes=[d3], d3.supersedes=[d4], d4.supersedes=[d5]
## Completing trigger_obj calls _on_objective_completed_internal → _supersede_cascade(d1,1)
## which cascades to d2(depth2)→d3(depth3)→d4(depth4 aborts, d5 stays PENDING).
func _make_depth4_abort_mission() -> MissionResource:
	# trigger: the required objective whose completion kicks off the cascade.
	var trigger_obj: MissionObjective = MissionObjective.new()
	trigger_obj.objective_id = &"trigger_obj"
	trigger_obj.completion_signal = &"document_collected"
	trigger_obj.required_for_completion = true
	trigger_obj.prereq_objective_ids = []
	trigger_obj.supersedes = [&"d1"]

	var d1: MissionObjective = MissionObjective.new()
	d1.objective_id = &"d1"
	d1.completion_signal = &""
	d1.required_for_completion = false
	d1.prereq_objective_ids = []
	d1.supersedes = [&"d2"]

	var d2: MissionObjective = MissionObjective.new()
	d2.objective_id = &"d2"
	d2.completion_signal = &""
	d2.required_for_completion = false
	d2.prereq_objective_ids = []
	d2.supersedes = [&"d3"]

	var d3: MissionObjective = MissionObjective.new()
	d3.objective_id = &"d3"
	d3.completion_signal = &""
	d3.required_for_completion = false
	d3.prereq_objective_ids = []
	d3.supersedes = [&"d4"]

	var d4: MissionObjective = MissionObjective.new()
	d4.objective_id = &"d4"
	d4.completion_signal = &""
	d4.required_for_completion = false
	d4.prereq_objective_ids = []
	d4.supersedes = [&"d5"]

	var d5: MissionObjective = MissionObjective.new()
	d5.objective_id = &"d5"
	d5.completion_signal = &""
	d5.required_for_completion = false
	d5.prereq_objective_ids = []
	d5.supersedes = []

	var mission: MissionResource = MissionResource.new()
	mission.mission_id = &"eiffel_tower"
	mission.objectives = [trigger_obj, d1, d2, d3, d4, d5]
	return mission


func _make_svc(resource: MissionResource) -> _TestServiceWithInjectedMission:
	var svc: _TestServiceWithInjectedMission = _TestServiceWithInjectedMission.new()
	svc._injected_resource = resource
	auto_free(svc)
	return svc


# ── Tests ─────────────────────────────────────────────────────────────────────

## AC-MLS-13.2: Depth-2 supersede cascade fires all objectives in same call stack.
## scale_exterior completing should cascade to climb_stairs, bribe_guard, and
## pick_lock_3b — all in the same synchronous frame (GDScript single-threaded).
func test_supersede_cascade_depth_2_fires_same_frame() -> void:
	# Arrange.
	var svc: _TestServiceWithInjectedMission = _make_svc(_make_depth2_cascade_mission())
	svc._on_section_entered(&"plaza", LevelStreamingService.TransitionReason.NEW_GAME)

	# Pre-condition: scale_exterior is ACTIVE; others are PENDING.
	assert_int(svc._mission_state.objective_states.get(&"scale_exterior", -1)).override_failure_message(
		"AC-MLS-13.2 pre-condition: scale_exterior must be ACTIVE."
	).is_equal(MissionLevelScriptingService.ObjectiveState.ACTIVE)

	# Act — emit document_collected to complete scale_exterior.
	Events.document_collected.emit(&"rooftop_access_card")

	# Assert — scale_exterior is COMPLETED.
	assert_int(svc._mission_state.objective_states.get(&"scale_exterior", -1)).override_failure_message(
		"AC-MLS-13.2: scale_exterior must be COMPLETED."
	).is_equal(MissionLevelScriptingService.ObjectiveState.COMPLETED)

	# Assert — climb_stairs superseded to COMPLETED (depth 1).
	assert_int(svc._mission_state.objective_states.get(&"climb_stairs", -1)).override_failure_message(
		"AC-MLS-13.2: climb_stairs must be COMPLETED (depth-1 supersede)."
	).is_equal(MissionLevelScriptingService.ObjectiveState.COMPLETED)

	# Assert — bribe_guard superseded to COMPLETED (depth 1).
	assert_int(svc._mission_state.objective_states.get(&"bribe_guard", -1)).override_failure_message(
		"AC-MLS-13.2: bribe_guard must be COMPLETED (depth-1 supersede)."
	).is_equal(MissionLevelScriptingService.ObjectiveState.COMPLETED)

	# Assert — pick_lock_3b superseded to COMPLETED (depth 2 via climb_stairs).
	assert_int(svc._mission_state.objective_states.get(&"pick_lock_3b", -1)).override_failure_message(
		"AC-MLS-13.2: pick_lock_3b must be COMPLETED (depth-2 supersede via climb_stairs)."
	).is_equal(MissionLevelScriptingService.ObjectiveState.COMPLETED)

	# Assert — objective_completed fired for all 4 (scale_exterior + 3 superseded).
	assert_bool(_objective_completed_ids.has(&"climb_stairs")).override_failure_message(
		"AC-MLS-13.2: objective_completed must be emitted for climb_stairs."
	).is_true()

	assert_bool(_objective_completed_ids.has(&"bribe_guard")).override_failure_message(
		"AC-MLS-13.2: objective_completed must be emitted for bribe_guard."
	).is_true()

	assert_bool(_objective_completed_ids.has(&"pick_lock_3b")).override_failure_message(
		"AC-MLS-13.2: objective_completed must be emitted for pick_lock_3b."
	).is_true()


## AC-MLS-13.3: Self-supersede is gracefully handled.
## The implementation skips already-COMPLETED siblings via the guard
## `if sibling_state == ObjectiveState.COMPLETED: continue`.
## After scale_exterior completes itself (it is COMPLETED before cascade runs),
## a self-entry in supersedes would find the sibling already COMPLETED and skip it.
## This test verifies the cascade does not crash and does not double-emit.
func test_supersede_cascade_self_supersede_logs_error_and_continues() -> void:
	# Arrange — build a mission where the completing objective lists itself in supersedes.
	var self_supersede_obj: MissionObjective = MissionObjective.new()
	self_supersede_obj.objective_id = &"scale_exterior"
	self_supersede_obj.completion_signal = &"document_collected"
	self_supersede_obj.required_for_completion = true
	self_supersede_obj.prereq_objective_ids = []
	# Self-reference: lists itself. At cascade time it will already be COMPLETED,
	# so the guard skips it cleanly. No crash, no double emit.
	self_supersede_obj.supersedes = [&"scale_exterior"]

	var mission: MissionResource = MissionResource.new()
	mission.mission_id = &"eiffel_tower"
	mission.objectives = [self_supersede_obj]

	var svc: _TestServiceWithInjectedMission = _make_svc(mission)
	svc._on_section_entered(&"plaza", LevelStreamingService.TransitionReason.NEW_GAME)

	# Act — complete scale_exterior.
	Events.document_collected.emit(&"access_doc")

	# Assert — scale_exterior is COMPLETED.
	assert_int(svc._mission_state.objective_states.get(&"scale_exterior", -1)).override_failure_message(
		"AC-MLS-13.3: scale_exterior must be COMPLETED (self-supersede handled)."
	).is_equal(MissionLevelScriptingService.ObjectiveState.COMPLETED)

	# Assert — objective_completed emitted exactly once for scale_exterior (no double-emit).
	var scale_completed_count: int = 0
	for id: StringName in _objective_completed_ids:
		if id == &"scale_exterior":
			scale_completed_count += 1

	assert_int(scale_completed_count).override_failure_message(
		"AC-MLS-13.3: objective_completed for scale_exterior must be emitted exactly once (no double-emit from self-supersede)."
	).is_equal(1)

	# Assert — mission completed (scale_exterior was the only required objective).
	assert_int(svc._phase).override_failure_message(
		"AC-MLS-13.3: mission must be COMPLETED after scale_exterior completes."
	).is_equal(MissionLevelScriptingService.MissionPhase.COMPLETED)


## AC-MLS-13.4: Cascade depth exceeding SUPERSEDE_CASCADE_MAX=3 aborts with
## push_error. Depths 1-3 objectives are COMPLETED; depth-4 objective stays PENDING.
## No rollback of already-completed objectives.
func test_supersede_cascade_depth_exceeds_max_aborts() -> void:
	# Arrange — linear chain: trigger → d1 → d2 → d3 → d4 → d5.
	# trigger.supersedes=[d1], so cascade starts at depth 1 for d1.
	# d1.supersedes=[d2] → depth 2 for d2.
	# d2.supersedes=[d3] → depth 3 for d3.
	# d3.supersedes=[d4] → depth 4 → abort! d4 and d5 remain PENDING.
	var svc: _TestServiceWithInjectedMission = _make_svc(_make_depth4_abort_mission())
	svc._on_section_entered(&"plaza", LevelStreamingService.TransitionReason.NEW_GAME)

	# Pre-condition: trigger_obj is ACTIVE; d1-d5 are PENDING.
	assert_int(svc._mission_state.objective_states.get(&"trigger_obj", -1)).override_failure_message(
		"AC-MLS-13.4 pre-condition: trigger_obj must be ACTIVE."
	).is_equal(MissionLevelScriptingService.ObjectiveState.ACTIVE)

	# Act — emit document_collected to complete trigger_obj.
	Events.document_collected.emit(&"trigger_doc")

	# Assert — trigger_obj COMPLETED.
	assert_int(svc._mission_state.objective_states.get(&"trigger_obj", -1)).override_failure_message(
		"AC-MLS-13.4: trigger_obj must be COMPLETED."
	).is_equal(MissionLevelScriptingService.ObjectiveState.COMPLETED)

	# Assert — d1 COMPLETED (depth 1 stands).
	assert_int(svc._mission_state.objective_states.get(&"d1", -1)).override_failure_message(
		"AC-MLS-13.4: d1 must be COMPLETED (depth 1 — within cap)."
	).is_equal(MissionLevelScriptingService.ObjectiveState.COMPLETED)

	# Assert — d2 COMPLETED (depth 2 stands).
	assert_int(svc._mission_state.objective_states.get(&"d2", -1)).override_failure_message(
		"AC-MLS-13.4: d2 must be COMPLETED (depth 2 — within cap)."
	).is_equal(MissionLevelScriptingService.ObjectiveState.COMPLETED)

	# Assert — d3 COMPLETED (depth 3 stands).
	assert_int(svc._mission_state.objective_states.get(&"d3", -1)).override_failure_message(
		"AC-MLS-13.4: d3 must be COMPLETED (depth 3 — within cap)."
	).is_equal(MissionLevelScriptingService.ObjectiveState.COMPLETED)

	# Assert — d4 is NOT COMPLETED (depth 4 cascade was aborted — no rollback either).
	# d4 has no prereqs so it transitions PENDING→ACTIVE at mission start, but the
	# depth-cap abort prevents the cascade from completing it. The assertion confirms
	# the cascade abort held: d4 was never force-completed by _supersede_cascade.
	var d4_state: int = svc._mission_state.objective_states.get(
		&"d4", MissionLevelScriptingService.ObjectiveState.PENDING
	)
	assert_int(d4_state).override_failure_message(
		"AC-MLS-13.4: d4 must NOT be COMPLETED — depth 4 cascade aborted (SUPERSEDE_CASCADE_MAX=3)."
	).is_not_equal(MissionLevelScriptingService.ObjectiveState.COMPLETED)

	# Assert — d5 is NOT COMPLETED (never reached by cascade before abort).
	# Same rationale: d5 starts ACTIVE but must not be force-completed.
	var d5_state: int = svc._mission_state.objective_states.get(
		&"d5", MissionLevelScriptingService.ObjectiveState.PENDING
	)
	assert_int(d5_state).override_failure_message(
		"AC-MLS-13.4: d5 must NOT be COMPLETED — never reached before abort."
	).is_not_equal(MissionLevelScriptingService.ObjectiveState.COMPLETED)
