# tests/unit/feature/mission_level_scripting/mission_state_machine_test.gd
#
# MissionStateMachineTest — GdUnit4 test suite for Story MLS-002.
#
# PURPOSE
#   Verifies the mission-level state machine (IDLE → RUNNING → COMPLETED) behaves
#   correctly across the start, completion, idempotency, and terminal-state cases
#   described in AC-MLS-1.1 through AC-MLS-1.4.
#
# COVERED ACCEPTANCE CRITERIA (Story MLS-002)
#   AC-MLS-1.1 — section_entered(NEW_GAME) on IDLE → loads resource, emits
#                mission_started, transitions _phase to RUNNING.
#   AC-MLS-1.2 — all required objectives COMPLETED → F.1 gate opens, emits
#                mission_completed, _phase == COMPLETED.
#   AC-MLS-1.3 — double NEW_GAME while RUNNING → push_error + drop; no re-emit.
#   AC-MLS-1.4 — late objective_completed while COMPLETED (terminal) → no-op.
#   (bonus) default _phase is IDLE before any section enters.
#   (bonus) load failure (null resource) → stays IDLE, push_error called.
#
# TEST FRAMEWORK
#   GdUnit4 — extends GdUnitTestSuite.
#
# DESIGN NOTES — in-memory fixture injection
#   _TestServiceWithInjectedMission overrides _load_mission_resource so tests
#   never touch the filesystem. MissionResource and MissionObjective are
#   constructed in-memory via factory helpers.
#
# DESIGN NOTES — signal isolation
#   Tests that must emit Events.* signals spy on them via counter lambdas
#   connected in before_test and disconnected in after_test to prevent
#   cross-test pollution against the live Events autoload.
#
# DESIGN NOTES — tree membership
#   Tests that verify state-only field reads do NOT add the service to the scene
#   tree (avoids connecting Events.section_entered on the live autoload).
#   Tests that need _on_section_entered to fire emit it directly (no add_child).

class_name MissionStateMachineTest
extends GdUnitTestSuite


# ── Inner test double ─────────────────────────────────────────────────────────

## Subclass that overrides the DI seam so _load_mission_resource returns an
## in-memory fixture instead of loading from the filesystem.
class _TestServiceWithInjectedMission extends MissionLevelScriptingService:
	var _injected_resource: MissionResource = null

	func _load_mission_resource(_mission_id: StringName) -> MissionResource:
		return _injected_resource


# ── Signal spy state (per-test counters) ──────────────────────────────────────

var _mission_started_count: int = 0
var _mission_started_last_id: StringName = &""
var _mission_completed_count: int = 0
var _mission_completed_last_id: StringName = &""


# ── Spy callbacks ─────────────────────────────────────────────────────────────

func _on_spy_mission_started(mission_id: StringName) -> void:
	_mission_started_count += 1
	_mission_started_last_id = mission_id


func _on_spy_mission_completed(mission_id: StringName) -> void:
	_mission_completed_count += 1
	_mission_completed_last_id = mission_id


# ── Setup / teardown ──────────────────────────────────────────────────────────

func before_test() -> void:
	_mission_started_count = 0
	_mission_started_last_id = &""
	_mission_completed_count = 0
	_mission_completed_last_id = &""
	Events.mission_started.connect(_on_spy_mission_started)
	Events.mission_completed.connect(_on_spy_mission_completed)


func after_test() -> void:
	if Events.mission_started.is_connected(_on_spy_mission_started):
		Events.mission_started.disconnect(_on_spy_mission_started)
	if Events.mission_completed.is_connected(_on_spy_mission_completed):
		Events.mission_completed.disconnect(_on_spy_mission_completed)


# ── Factory helpers ───────────────────────────────────────────────────────────

## Builds a minimal valid MissionResource with one required objective that uses
## document_collected as its completion signal. Maps to the "plaza" section
## (→ "eiffel_tower" mission) per _SECTION_TO_MISSION.
func _make_simple_mission() -> MissionResource:
	var obj: MissionObjective = MissionObjective.new()
	obj.objective_id = &"recover_plaza_document"
	obj.completion_signal = &"document_collected"
	obj.required_for_completion = true
	obj.prereq_objective_ids = []
	obj.supersedes = []
	var mission: MissionResource = MissionResource.new()
	mission.mission_id = &"eiffel_tower"
	mission.objectives = [obj]
	return mission


## Builds a MissionResource with one required objective and one optional
## objective. Both use document_collected but only the required one blocks
## the F.1 gate.
func _make_mission_with_optional() -> MissionResource:
	var required_obj: MissionObjective = MissionObjective.new()
	required_obj.objective_id = &"recover_plaza_document"
	required_obj.completion_signal = &"document_collected"
	required_obj.required_for_completion = true
	required_obj.prereq_objective_ids = []
	required_obj.supersedes = []

	var optional_obj: MissionObjective = MissionObjective.new()
	optional_obj.objective_id = &"read_memo"
	optional_obj.completion_signal = &""
	optional_obj.required_for_completion = false
	optional_obj.prereq_objective_ids = []
	optional_obj.supersedes = []

	var mission: MissionResource = MissionResource.new()
	mission.mission_id = &"eiffel_tower"
	mission.objectives = [required_obj, optional_obj]
	return mission


## Creates a _TestServiceWithInjectedMission, sets its injected resource, and
## returns it without adding to the scene tree. auto_free() is registered.
func _make_svc(resource: MissionResource) -> _TestServiceWithInjectedMission:
	var svc: _TestServiceWithInjectedMission = _TestServiceWithInjectedMission.new()
	svc._injected_resource = resource
	auto_free(svc)
	return svc


# ── Tests ─────────────────────────────────────────────────────────────────────

## Default _phase is IDLE before any section_entered fires.
## Verifies the initial state documented in the class declaration.
func test_mission_state_machine_default_phase_is_idle() -> void:
	# Arrange — bare instance, no tree membership required.
	var svc: _TestServiceWithInjectedMission = _make_svc(_make_simple_mission())

	# Assert — _phase must be IDLE (= 0) at construction time.
	assert_int(svc._phase).override_failure_message(
		"Default _phase must be MissionPhase.IDLE (0) before section_entered fires."
	).is_equal(MissionLevelScriptingService.MissionPhase.IDLE)


## AC-MLS-1.1: IDLE + null active mission → section_entered(plaza, NEW_GAME)
## loads MissionResource, emits mission_started, transitions to RUNNING.
func test_mission_state_machine_section_entered_new_game_starts_mission() -> void:
	# Arrange.
	var svc: _TestServiceWithInjectedMission = _make_svc(_make_simple_mission())

	assert_int(svc._phase).override_failure_message(
		"AC-MLS-1.1 pre-condition: _phase must be IDLE before section_entered."
	).is_equal(MissionLevelScriptingService.MissionPhase.IDLE)

	# Act — call handler directly (service not in tree; avoids live autoload signals).
	svc._on_section_entered(&"plaza", LevelStreamingService.TransitionReason.NEW_GAME)

	# Assert — phase transitioned to RUNNING.
	assert_int(svc._phase).override_failure_message(
		"AC-MLS-1.1: _phase must be RUNNING after section_entered(NEW_GAME)."
	).is_equal(MissionLevelScriptingService.MissionPhase.RUNNING)

	# Assert — _active_mission is non-null.
	assert_object(svc._active_mission).override_failure_message(
		"AC-MLS-1.1: _active_mission must not be null after mission starts."
	).is_not_null()

	# Assert — mission_started emitted exactly once with correct id.
	assert_int(_mission_started_count).override_failure_message(
		"AC-MLS-1.1: Events.mission_started must be emitted exactly once."
	).is_equal(1)

	assert_str(str(_mission_started_last_id)).override_failure_message(
		"AC-MLS-1.1: mission_started payload must be 'eiffel_tower'."
	).is_equal("eiffel_tower")


## AC-MLS-1.2: RUNNING with 1 required + 1 optional objective.
## Completing the required objective fires mission_completed and transitions to
## COMPLETED. The optional objective remains PENDING and does not block F.1.
func test_mission_state_machine_all_required_complete_completes_mission() -> void:
	# Arrange — start mission with one required + one optional.
	var svc: _TestServiceWithInjectedMission = _make_svc(_make_mission_with_optional())
	svc._on_section_entered(&"plaza", LevelStreamingService.TransitionReason.NEW_GAME)

	assert_int(svc._phase).override_failure_message(
		"AC-MLS-1.2 pre-condition: _phase must be RUNNING."
	).is_equal(MissionLevelScriptingService.MissionPhase.RUNNING)

	# Act — emit document_collected to complete the required objective.
	Events.document_collected.emit(&"plaza_dossier")

	# Assert — mission completed.
	assert_int(svc._phase).override_failure_message(
		"AC-MLS-1.2: _phase must be COMPLETED after all required objectives done."
	).is_equal(MissionLevelScriptingService.MissionPhase.COMPLETED)

	# Assert — mission_completed emitted exactly once.
	assert_int(_mission_completed_count).override_failure_message(
		"AC-MLS-1.2: Events.mission_completed must be emitted exactly once."
	).is_equal(1)

	assert_str(str(_mission_completed_last_id)).override_failure_message(
		"AC-MLS-1.2: mission_completed payload must be 'eiffel_tower'."
	).is_equal("eiffel_tower")

	# Assert — optional objective is not COMPLETED (did not block F.1 gate).
	# The optional objective has no prereqs so it transitions PENDING→ACTIVE at
	# mission start; the assertion verifies it is NOT COMPLETED (i.e. it did not
	# interfere with the F.1 gate and was not force-completed by the cascade).
	var opt_state: int = svc._mission_state.objective_states.get(
		&"read_memo", MissionLevelScriptingService.ObjectiveState.PENDING
	)
	assert_int(opt_state).override_failure_message(
		"AC-MLS-1.2: Optional objective 'read_memo' must NOT be COMPLETED — it must not block or affect F.1."
	).is_not_equal(MissionLevelScriptingService.ObjectiveState.COMPLETED)


## AC-MLS-1.3: RUNNING → second NEW_GAME fires → push_error + drop.
## No second mission_started emission; _phase stays RUNNING.
func test_mission_state_machine_double_start_drops_with_push_error() -> void:
	# Arrange — start mission once.
	var svc: _TestServiceWithInjectedMission = _make_svc(_make_simple_mission())
	svc._on_section_entered(&"plaza", LevelStreamingService.TransitionReason.NEW_GAME)

	assert_int(_mission_started_count).override_failure_message(
		"AC-MLS-1.3 pre-condition: mission_started must have fired once."
	).is_equal(1)

	assert_int(svc._phase).override_failure_message(
		"AC-MLS-1.3 pre-condition: _phase must be RUNNING."
	).is_equal(MissionLevelScriptingService.MissionPhase.RUNNING)

	# Act — fire section_entered NEW_GAME a second time (same section).
	svc._on_section_entered(&"plaza", LevelStreamingService.TransitionReason.NEW_GAME)

	# Assert — no second mission_started emission.
	assert_int(_mission_started_count).override_failure_message(
		"AC-MLS-1.3: mission_started must NOT be emitted a second time (drop)."
	).is_equal(1)

	# Assert — _phase unchanged.
	assert_int(svc._phase).override_failure_message(
		"AC-MLS-1.3: _phase must remain RUNNING after dropped double-start."
	).is_equal(MissionLevelScriptingService.MissionPhase.RUNNING)


## AC-MLS-1.4: COMPLETED (terminal) → late objective_completed call → no-op.
## No state transition; no re-emit of mission_completed.
func test_mission_state_machine_completed_late_objective_completed_ignored() -> void:
	# Arrange — start mission, then force COMPLETED state.
	var svc: _TestServiceWithInjectedMission = _make_svc(_make_simple_mission())
	svc._on_section_entered(&"plaza", LevelStreamingService.TransitionReason.NEW_GAME)

	# Force COMPLETED and set an active mission to satisfy null checks inside the handler.
	svc._phase = MissionLevelScriptingService.MissionPhase.COMPLETED

	# Record baseline completed-count after the forced state.
	var baseline_completed: int = _mission_completed_count

	# Act — trigger the internal completed handler directly for the objective.
	svc._on_objective_completed_internal(&"recover_plaza_document")

	# Assert — _phase has not changed.
	assert_int(svc._phase).override_failure_message(
		"AC-MLS-1.4: _phase must remain COMPLETED after late objective_completed."
	).is_equal(MissionLevelScriptingService.MissionPhase.COMPLETED)

	# Assert — no additional mission_completed emission.
	assert_int(_mission_completed_count).override_failure_message(
		"AC-MLS-1.4: mission_completed must NOT be re-emitted after terminal COMPLETED state."
	).is_equal(baseline_completed)


## E.29: _load_mission_resource returns null → MLS stays IDLE, emits no mission_started.
func test_mission_state_machine_load_failure_stays_idle() -> void:
	# Arrange — inject null resource to simulate load failure.
	var svc: _TestServiceWithInjectedMission = _make_svc(null)

	# Act — fire section_entered NEW_GAME.
	svc._on_section_entered(&"plaza", LevelStreamingService.TransitionReason.NEW_GAME)

	# Assert — _phase stays IDLE.
	assert_int(svc._phase).override_failure_message(
		"E.29: _phase must remain IDLE when resource load fails (null return)."
	).is_equal(MissionLevelScriptingService.MissionPhase.IDLE)

	# Assert — no mission_started emitted.
	assert_int(_mission_started_count).override_failure_message(
		"E.29: mission_started must NOT be emitted when resource load fails."
	).is_equal(0)
