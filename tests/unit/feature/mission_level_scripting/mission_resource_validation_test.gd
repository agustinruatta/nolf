# tests/unit/feature/mission_level_scripting/mission_resource_validation_test.gd
#
# MissionResourceValidationTest — GdUnit4 test suite for Story MLS-002.
#
# PURPOSE
#   Verifies that MissionLevelScriptingService._validate_mission_resource() rejects
#   ill-formed MissionResources before the mission starts, and accepts well-formed ones.
#   Tests the CR-18 load-time validation rules.
#
# COVERED ACCEPTANCE CRITERIA (Story MLS-002)
#   AC-MLS-2.6 — self-prereq and A→B→A cycle both fail validation, push_error called,
#                _phase stays IDLE.
#   AC-MLS-2.7 — empty objectives array fails; all required_for_completion=false fails.
#   (bonus) linear prereq chain A→B→C (no cycle) passes validation.
#
# TEST FRAMEWORK
#   GdUnit4 — extends GdUnitTestSuite.
#
# DESIGN NOTES
#   Validation is tested by calling _on_section_entered() and observing _phase.
#   A null → IDLE result confirms rejection. No Events spy needed here
#   because we only care that the state machine stays IDLE on bad input.

class_name MissionResourceValidationTest
extends GdUnitTestSuite


# ── Inner test double ─────────────────────────────────────────────────────────

class _TestServiceWithInjectedMission extends MissionLevelScriptingService:
	var _injected_resource: MissionResource = null

	func _load_mission_resource(_mission_id: StringName) -> MissionResource:
		return _injected_resource


# ── Signal spy state ──────────────────────────────────────────────────────────

var _mission_started_count: int = 0


func _on_spy_mission_started(_mission_id: StringName) -> void:
	_mission_started_count += 1


# ── Setup / teardown ──────────────────────────────────────────────────────────

func before_test() -> void:
	_mission_started_count = 0
	Events.mission_started.connect(_on_spy_mission_started)


func after_test() -> void:
	if Events.mission_started.is_connected(_on_spy_mission_started):
		Events.mission_started.disconnect(_on_spy_mission_started)


# ── Helpers ───────────────────────────────────────────────────────────────────

## Attempts to start a mission with the given resource; returns the service for
## phase inspection. Resource may be intentionally malformed.
func _attempt_start(resource: MissionResource) -> _TestServiceWithInjectedMission:
	var svc: _TestServiceWithInjectedMission = _TestServiceWithInjectedMission.new()
	svc._injected_resource = resource
	auto_free(svc)
	svc._on_section_entered(&"plaza", LevelStreamingService.TransitionReason.NEW_GAME)
	return svc


# ── Tests ─────────────────────────────────────────────────────────────────────

## AC-MLS-2.7 (empty objectives): MissionResource with zero objectives fails
## validation; MLS stays IDLE and emits no mission_started.
func test_mission_resource_validation_empty_objectives_array_fails() -> void:
	# Arrange — empty objectives array.
	var mission: MissionResource = MissionResource.new()
	mission.mission_id = &"eiffel_tower"
	mission.objectives = []

	# Act.
	var svc: _TestServiceWithInjectedMission = _attempt_start(mission)

	# Assert — IDLE.
	assert_int(svc._phase).override_failure_message(
		"AC-MLS-2.7: _phase must remain IDLE when objectives array is empty."
	).is_equal(MissionLevelScriptingService.MissionPhase.IDLE)

	# Assert — no mission_started.
	assert_int(_mission_started_count).override_failure_message(
		"AC-MLS-2.7: mission_started must NOT be emitted when objectives array is empty."
	).is_equal(0)


## AC-MLS-2.7 (no required objectives): MissionResource where all objectives have
## required_for_completion=false fails validation; MLS stays IDLE.
func test_mission_resource_validation_no_required_objectives_fails() -> void:
	# Arrange — one objective, but required_for_completion = false.
	var obj: MissionObjective = MissionObjective.new()
	obj.objective_id = &"optional_objective"
	obj.completion_signal = &"document_collected"
	obj.required_for_completion = false
	obj.prereq_objective_ids = []
	obj.supersedes = []

	var mission: MissionResource = MissionResource.new()
	mission.mission_id = &"eiffel_tower"
	mission.objectives = [obj]

	# Act.
	var svc: _TestServiceWithInjectedMission = _attempt_start(mission)

	# Assert — IDLE.
	assert_int(svc._phase).override_failure_message(
		"AC-MLS-2.7: _phase must remain IDLE when no required objectives exist."
	).is_equal(MissionLevelScriptingService.MissionPhase.IDLE)

	# Assert — no mission_started.
	assert_int(_mission_started_count).override_failure_message(
		"AC-MLS-2.7: mission_started must NOT be emitted when no required objectives exist."
	).is_equal(0)


## AC-MLS-2.6 (self-prereq): MissionResource where objA.prereq_objective_ids=[objA]
## triggers push_error and stays IDLE.
func test_mission_resource_validation_self_prereq_fails() -> void:
	# Arrange — objective lists itself as its own prerequisite.
	var obj: MissionObjective = MissionObjective.new()
	obj.objective_id = &"obj_a"
	obj.completion_signal = &"document_collected"
	obj.required_for_completion = true
	obj.prereq_objective_ids = [&"obj_a"]  # self-prereq
	obj.supersedes = []

	var mission: MissionResource = MissionResource.new()
	mission.mission_id = &"eiffel_tower"
	mission.objectives = [obj]

	# Act.
	var svc: _TestServiceWithInjectedMission = _attempt_start(mission)

	# Assert — IDLE.
	assert_int(svc._phase).override_failure_message(
		"AC-MLS-2.6: _phase must remain IDLE when self-prereq detected."
	).is_equal(MissionLevelScriptingService.MissionPhase.IDLE)

	# Assert — no mission_started.
	assert_int(_mission_started_count).override_failure_message(
		"AC-MLS-2.6: mission_started must NOT be emitted when self-prereq detected."
	).is_equal(0)


## AC-MLS-2.6 (mutual cycle): A.prereqs=[B], B.prereqs=[A] triggers push_error,
## stays IDLE, and emits no mission_started.
func test_mission_resource_validation_prereq_cycle_fails() -> void:
	# Arrange — mutual prereq cycle.
	var obj_a: MissionObjective = MissionObjective.new()
	obj_a.objective_id = &"obj_a"
	obj_a.completion_signal = &"document_collected"
	obj_a.required_for_completion = true
	obj_a.prereq_objective_ids = [&"obj_b"]
	obj_a.supersedes = []

	var obj_b: MissionObjective = MissionObjective.new()
	obj_b.objective_id = &"obj_b"
	obj_b.completion_signal = &"document_collected"
	obj_b.required_for_completion = true
	obj_b.prereq_objective_ids = [&"obj_a"]
	obj_b.supersedes = []

	var mission: MissionResource = MissionResource.new()
	mission.mission_id = &"eiffel_tower"
	mission.objectives = [obj_a, obj_b]

	# Act.
	var svc: _TestServiceWithInjectedMission = _attempt_start(mission)

	# Assert — IDLE.
	assert_int(svc._phase).override_failure_message(
		"AC-MLS-2.6: _phase must remain IDLE when prereq cycle A→B→A detected."
	).is_equal(MissionLevelScriptingService.MissionPhase.IDLE)

	# Assert — no mission_started.
	assert_int(_mission_started_count).override_failure_message(
		"AC-MLS-2.6: mission_started must NOT be emitted when prereq cycle detected."
	).is_equal(0)


## Sanity check: linear chain A → B → C (no cycle) passes validation and starts.
## This is the positive case to confirm the DFS doesn't produce false positives.
func test_mission_resource_validation_linear_prereq_chain_passes() -> void:
	# Arrange — A has no prereqs, B prereqs A, C prereqs B.
	var obj_a: MissionObjective = MissionObjective.new()
	obj_a.objective_id = &"obj_a"
	obj_a.completion_signal = &"document_collected"
	obj_a.required_for_completion = true
	obj_a.prereq_objective_ids = []
	obj_a.supersedes = []

	var obj_b: MissionObjective = MissionObjective.new()
	obj_b.objective_id = &"obj_b"
	obj_b.completion_signal = &"document_collected"
	obj_b.required_for_completion = true
	obj_b.prereq_objective_ids = [&"obj_a"]
	obj_b.supersedes = []

	var obj_c: MissionObjective = MissionObjective.new()
	obj_c.objective_id = &"obj_c"
	obj_c.completion_signal = &"document_collected"
	obj_c.required_for_completion = true
	obj_c.prereq_objective_ids = [&"obj_b"]
	obj_c.supersedes = []

	var mission: MissionResource = MissionResource.new()
	mission.mission_id = &"eiffel_tower"
	mission.objectives = [obj_a, obj_b, obj_c]

	# Act.
	var svc: _TestServiceWithInjectedMission = _attempt_start(mission)

	# Assert — RUNNING (validation passed; mission started).
	assert_int(svc._phase).override_failure_message(
		"Linear A→B→C prereq chain must pass validation (_phase == RUNNING)."
	).is_equal(MissionLevelScriptingService.MissionPhase.RUNNING)

	# Assert — mission_started emitted once.
	assert_int(_mission_started_count).override_failure_message(
		"Linear A→B→C prereq chain must result in mission_started being emitted once."
	).is_equal(1)
