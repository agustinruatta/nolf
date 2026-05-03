# tests/unit/feature/mission_level_scripting/objective_state_machine_test.gd
#
# ObjectiveStateMachineTest — GdUnit4 test suite for Story MLS-002.
#
# PURPOSE
#   Verifies the per-objective state machine (PENDING → ACTIVE → COMPLETED)
#   across activation, prereq-unlock, completion-signal dispatch, idempotency,
#   optional-objective filtering, completion_filter_method, and one-shot
#   unsubscribe behaviour described in AC-MLS-2.1 through AC-MLS-2.5.
#
# COVERED ACCEPTANCE CRITERIA (Story MLS-002)
#   AC-MLS-2.1 — zero-prereq objective activates (PENDING→ACTIVE) on mission start.
#   AC-MLS-2.2 — objective with prereq activates after prereq COMPLETED.
#   AC-MLS-2.3 — ACTIVE objective completes on document_collected; signal fired.
#   AC-MLS-2.4 — idempotency: second document_collected after COMPLETED → no-op.
#   AC-MLS-2.5 — optional PENDING objectives don't block F.1 gate.
#   (bonus) completion_filter_method is called when set.
#   (bonus) document_collected is disconnected after first objective completes
#           (one-shot per-objective unsubscribe).
#
# TEST FRAMEWORK
#   GdUnit4 — extends GdUnitTestSuite.
#
# DESIGN NOTES
#   _TestServiceWithInjectedMission overrides _load_mission_resource for in-memory
#   fixtures. Direct method calls avoid scene-tree add_child where possible.
#   Signal spies connected in before_test, disconnected in after_test.

class_name ObjectiveStateMachineTest
extends GdUnitTestSuite


# ── Inner test double ─────────────────────────────────────────────────────────

class _TestServiceWithInjectedMission extends MissionLevelScriptingService:
	var _injected_resource: MissionResource = null

	func _load_mission_resource(_mission_id: StringName) -> MissionResource:
		return _injected_resource


## Extended double that also exposes a completion_filter_method for testing.
## Returns true when the document_id equals the expected value; false otherwise.
class _TestServiceWithFilter extends _TestServiceWithInjectedMission:
	var filter_call_count: int = 0
	var filter_last_document_id: StringName = &""

	## Returns true unconditionally — acts as a pass-through filter.
	func test_filter_always_pass(document_id: StringName) -> bool:
		filter_call_count += 1
		filter_last_document_id = document_id
		return true


# ── Signal spy state ──────────────────────────────────────────────────────────

var _objective_started_count: int = 0
var _objective_started_ids: Array[StringName] = []
var _objective_completed_count: int = 0
var _objective_completed_ids: Array[StringName] = []
var _mission_completed_count: int = 0


# ── Spy callbacks ─────────────────────────────────────────────────────────────

func _on_spy_objective_started(obj_id: StringName) -> void:
	_objective_started_count += 1
	_objective_started_ids.append(obj_id)


func _on_spy_objective_completed(obj_id: StringName) -> void:
	_objective_completed_count += 1
	_objective_completed_ids.append(obj_id)


func _on_spy_mission_completed(_mission_id: StringName) -> void:
	_mission_completed_count += 1


# ── Setup / teardown ──────────────────────────────────────────────────────────

func before_test() -> void:
	_objective_started_count = 0
	_objective_started_ids = []
	_objective_completed_count = 0
	_objective_completed_ids = []
	_mission_completed_count = 0
	Events.objective_started.connect(_on_spy_objective_started)
	Events.objective_completed.connect(_on_spy_objective_completed)
	Events.mission_completed.connect(_on_spy_mission_completed)


func after_test() -> void:
	if Events.objective_started.is_connected(_on_spy_objective_started):
		Events.objective_started.disconnect(_on_spy_objective_started)
	if Events.objective_completed.is_connected(_on_spy_objective_completed):
		Events.objective_completed.disconnect(_on_spy_objective_completed)
	if Events.mission_completed.is_connected(_on_spy_mission_completed):
		Events.mission_completed.disconnect(_on_spy_mission_completed)


# ── Factory helpers ───────────────────────────────────────────────────────────

## One required objective, no prereqs, document_collected completion.
func _make_single_objective_mission() -> MissionResource:
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


## Two required objectives (A, B where B.prereqs=[A]) for prereq-unlock tests.
func _make_chained_mission() -> MissionResource:
	var obj_a: MissionObjective = MissionObjective.new()
	obj_a.objective_id = &"infiltrate_lobby"
	obj_a.completion_signal = &"document_collected"
	obj_a.required_for_completion = true
	obj_a.prereq_objective_ids = []
	obj_a.supersedes = []

	var obj_b: MissionObjective = MissionObjective.new()
	obj_b.objective_id = &"recover_plaza_document"
	obj_b.completion_signal = &"document_collected"
	obj_b.required_for_completion = true
	obj_b.prereq_objective_ids = [&"infiltrate_lobby"]
	obj_b.supersedes = []

	var mission: MissionResource = MissionResource.new()
	mission.mission_id = &"eiffel_tower"
	mission.objectives = [obj_a, obj_b]
	return mission


## Two required + two optional objectives for F.1 gate test.
func _make_mixed_mission() -> MissionResource:
	var req_a: MissionObjective = MissionObjective.new()
	req_a.objective_id = &"infiltrate_lobby"
	req_a.completion_signal = &"document_collected"
	req_a.required_for_completion = true
	req_a.prereq_objective_ids = []
	req_a.supersedes = []

	var req_b: MissionObjective = MissionObjective.new()
	req_b.objective_id = &"recover_plaza_document"
	req_b.completion_signal = &"document_collected"
	req_b.required_for_completion = true
	req_b.prereq_objective_ids = []
	req_b.supersedes = []

	var opt_a: MissionObjective = MissionObjective.new()
	opt_a.objective_id = &"read_memo"
	opt_a.completion_signal = &""
	opt_a.required_for_completion = false
	opt_a.prereq_objective_ids = []
	opt_a.supersedes = []

	var opt_b: MissionObjective = MissionObjective.new()
	opt_b.objective_id = &"photograph_lobby"
	opt_b.completion_signal = &""
	opt_b.required_for_completion = false
	opt_b.prereq_objective_ids = []
	opt_b.supersedes = []

	var mission: MissionResource = MissionResource.new()
	mission.mission_id = &"eiffel_tower"
	mission.objectives = [req_a, req_b, opt_a, opt_b]
	return mission


func _make_svc(resource: MissionResource) -> _TestServiceWithInjectedMission:
	var svc: _TestServiceWithInjectedMission = _TestServiceWithInjectedMission.new()
	svc._injected_resource = resource
	auto_free(svc)
	return svc


func _make_filter_svc(resource: MissionResource) -> _TestServiceWithFilter:
	var svc: _TestServiceWithFilter = _TestServiceWithFilter.new()
	svc._injected_resource = resource
	auto_free(svc)
	return svc


# ── Tests ─────────────────────────────────────────────────────────────────────

## AC-MLS-2.1: Zero-prereq objective transitions PENDING → ACTIVE on mission start.
## Events.objective_started(id) must be emitted exactly once.
func test_objective_state_machine_no_prereqs_activates_on_mission_started() -> void:
	# Arrange.
	var svc: _TestServiceWithInjectedMission = _make_svc(_make_single_objective_mission())

	# Act — start the mission.
	svc._on_section_entered(&"plaza", LevelStreamingService.TransitionReason.NEW_GAME)

	# Assert — objective state is ACTIVE.
	var obj_state: int = svc._mission_state.objective_states.get(
		&"recover_plaza_document", MissionLevelScriptingService.ObjectiveState.PENDING
	)
	assert_int(obj_state).override_failure_message(
		"AC-MLS-2.1: 'recover_plaza_document' must be ACTIVE after mission start."
	).is_equal(MissionLevelScriptingService.ObjectiveState.ACTIVE)

	# Assert — objective_started emitted exactly once.
	assert_int(_objective_started_count).override_failure_message(
		"AC-MLS-2.1: Events.objective_started must be emitted once."
	).is_equal(1)

	assert_bool(_objective_started_ids.has(&"recover_plaza_document")).override_failure_message(
		"AC-MLS-2.1: objective_started payload must be 'recover_plaza_document'."
	).is_true()


## AC-MLS-2.2: B.prereqs=[A]. After A completes, F.2 unlocks B (PENDING → ACTIVE).
## Events.objective_started must fire for B after A is completed.
func test_objective_state_machine_prereq_completed_unlocks_dependent() -> void:
	# Arrange — A and B chained; A has no prereqs, B prereqs A.
	var svc: _TestServiceWithInjectedMission = _make_svc(_make_chained_mission())
	svc._on_section_entered(&"plaza", LevelStreamingService.TransitionReason.NEW_GAME)

	# Pre-condition: A is ACTIVE, B is still PENDING.
	var a_state: int = svc._mission_state.objective_states.get(
		&"infiltrate_lobby", MissionLevelScriptingService.ObjectiveState.PENDING
	)
	assert_int(a_state).override_failure_message(
		"AC-MLS-2.2 pre-condition: 'infiltrate_lobby' must be ACTIVE."
	).is_equal(MissionLevelScriptingService.ObjectiveState.ACTIVE)

	var b_state_before: int = svc._mission_state.objective_states.get(
		&"recover_plaza_document", MissionLevelScriptingService.ObjectiveState.PENDING
	)
	assert_int(b_state_before).override_failure_message(
		"AC-MLS-2.2 pre-condition: 'recover_plaza_document' must be PENDING."
	).is_equal(MissionLevelScriptingService.ObjectiveState.PENDING)

	# Act — emit document_collected to complete A (infiltrate_lobby).
	# Reset spy before the action we care about.
	_objective_started_ids = []
	_objective_started_count = 0
	Events.document_collected.emit(&"lobby_keycard")

	# Assert — A is now COMPLETED.
	var a_state_after: int = svc._mission_state.objective_states.get(
		&"infiltrate_lobby", MissionLevelScriptingService.ObjectiveState.PENDING
	)
	assert_int(a_state_after).override_failure_message(
		"AC-MLS-2.2: 'infiltrate_lobby' must be COMPLETED after document_collected."
	).is_equal(MissionLevelScriptingService.ObjectiveState.COMPLETED)

	# Assert — B is now ACTIVE (prereq satisfied).
	var b_state_after: int = svc._mission_state.objective_states.get(
		&"recover_plaza_document", MissionLevelScriptingService.ObjectiveState.PENDING
	)
	assert_int(b_state_after).override_failure_message(
		"AC-MLS-2.2: 'recover_plaza_document' must be ACTIVE after prereq completed."
	).is_equal(MissionLevelScriptingService.ObjectiveState.ACTIVE)

	# Assert — objective_started(recover_plaza_document) fired.
	assert_bool(_objective_started_ids.has(&"recover_plaza_document")).override_failure_message(
		"AC-MLS-2.2: objective_started must fire for 'recover_plaza_document' after prereq done."
	).is_true()


## AC-MLS-2.3: ACTIVE objective with document_collected → objective_completed emitted.
## Objective_state transitions to COMPLETED.
func test_objective_state_machine_completion_signal_dispatches_to_active() -> void:
	# Arrange — single required objective.
	var svc: _TestServiceWithInjectedMission = _make_svc(_make_single_objective_mission())
	svc._on_section_entered(&"plaza", LevelStreamingService.TransitionReason.NEW_GAME)

	# Act — emit document_collected.
	Events.document_collected.emit(&"plaza_dossier")

	# Assert — objective COMPLETED.
	var obj_state: int = svc._mission_state.objective_states.get(
		&"recover_plaza_document", MissionLevelScriptingService.ObjectiveState.PENDING
	)
	assert_int(obj_state).override_failure_message(
		"AC-MLS-2.3: 'recover_plaza_document' must be COMPLETED after document_collected."
	).is_equal(MissionLevelScriptingService.ObjectiveState.COMPLETED)

	# Assert — objective_completed emitted.
	assert_bool(_objective_completed_ids.has(&"recover_plaza_document")).override_failure_message(
		"AC-MLS-2.3: objective_completed must be emitted for 'recover_plaza_document'."
	).is_true()


## AC-MLS-2.4: Idempotency — once COMPLETED, a second document_collected is ignored.
## No re-emit of objective_completed; objective stays COMPLETED.
func test_objective_state_machine_late_completion_signal_ignored() -> void:
	# Arrange — complete the objective first.
	var svc: _TestServiceWithInjectedMission = _make_svc(_make_single_objective_mission())
	svc._on_section_entered(&"plaza", LevelStreamingService.TransitionReason.NEW_GAME)
	Events.document_collected.emit(&"plaza_dossier")

	var completed_count_after_first: int = _objective_completed_count

	# Act — emit document_collected again.
	# (Because document_collected was disconnected after first completion, we need
	# to force the objective back to ACTIVE to test the guard inside the handler.)
	# Instead, call the internal handler directly with the already-COMPLETED objective.
	svc._on_document_collected_for_objective(&"plaza_dossier_second")

	# Assert — no additional objective_completed emission.
	assert_int(_objective_completed_count).override_failure_message(
		"AC-MLS-2.4: objective_completed must NOT re-emit after objective is COMPLETED."
	).is_equal(completed_count_after_first)


## AC-MLS-2.5: 2 required + 2 optional objectives. Completing only the 2 required
## is sufficient — F.1 gate opens; optional PENDING objectives don't block it.
func test_objective_state_machine_optional_pending_does_not_block_completion() -> void:
	# Arrange — mixed mission (2 required, 2 optional).
	var svc: _TestServiceWithInjectedMission = _make_svc(_make_mixed_mission())
	svc._on_section_entered(&"plaza", LevelStreamingService.TransitionReason.NEW_GAME)

	# Both required objectives are now ACTIVE; complete them both.
	# First document_collected → completes 'infiltrate_lobby'.
	Events.document_collected.emit(&"keycard")
	# Second document_collected → completes 'recover_plaza_document' and
	# triggers F.1 gate (both required done).
	Events.document_collected.emit(&"dossier")

	# Assert — mission completed (F.1 gate opened).
	assert_int(svc._phase).override_failure_message(
		"AC-MLS-2.5: _phase must be COMPLETED once all required objectives done."
	).is_equal(MissionLevelScriptingService.MissionPhase.COMPLETED)

	# Assert — optional objectives are NOT COMPLETED (they don't block F.1).
	# Both optional objectives have no prereqs so they transition PENDING→ACTIVE at
	# mission start. The assertion verifies they are NOT COMPLETED — confirming they
	# neither contributed to nor blocked the F.1 gate.
	var opt_a_state: int = svc._mission_state.objective_states.get(
		&"read_memo", MissionLevelScriptingService.ObjectiveState.PENDING
	)
	var opt_b_state: int = svc._mission_state.objective_states.get(
		&"photograph_lobby", MissionLevelScriptingService.ObjectiveState.PENDING
	)
	assert_int(opt_a_state).override_failure_message(
		"AC-MLS-2.5: Optional 'read_memo' must NOT be COMPLETED — must not affect F.1."
	).is_not_equal(MissionLevelScriptingService.ObjectiveState.COMPLETED)

	assert_int(opt_b_state).override_failure_message(
		"AC-MLS-2.5: Optional 'photograph_lobby' must NOT be COMPLETED — must not affect F.1."
	).is_not_equal(MissionLevelScriptingService.ObjectiveState.COMPLETED)


## completion_filter_method: method on the service is invoked when set.
## Verifies call() resolves the method by StringName and passes the document_id.
func test_objective_state_machine_completion_filter_method_called() -> void:
	# Arrange — build a mission whose objective uses a filter method.
	var obj: MissionObjective = MissionObjective.new()
	obj.objective_id = &"recover_plaza_document"
	obj.completion_signal = &"document_collected"
	obj.completion_filter_method = &"test_filter_always_pass"
	obj.required_for_completion = true
	obj.prereq_objective_ids = []
	obj.supersedes = []
	var mission: MissionResource = MissionResource.new()
	mission.mission_id = &"eiffel_tower"
	mission.objectives = [obj]

	var svc: _TestServiceWithFilter = _make_filter_svc(mission)
	svc._on_section_entered(&"plaza", LevelStreamingService.TransitionReason.NEW_GAME)

	# Act — emit document_collected.
	Events.document_collected.emit(&"filtered_doc")

	# Assert — filter was called exactly once.
	assert_int(svc.filter_call_count).override_failure_message(
		"completion_filter_method must be called exactly once via call()."
	).is_equal(1)

	# Assert — filter received the correct document_id.
	assert_str(str(svc.filter_last_document_id)).override_failure_message(
		"completion_filter_method must receive the document_id payload."
	).is_equal("filtered_doc")

	# Assert — objective completed (filter returned true).
	var obj_state: int = svc._mission_state.objective_states.get(
		&"recover_plaza_document", MissionLevelScriptingService.ObjectiveState.PENDING
	)
	assert_int(obj_state).override_failure_message(
		"Objective must be COMPLETED when filter returns true."
	).is_equal(MissionLevelScriptingService.ObjectiveState.COMPLETED)


## One-shot unsubscribe: after first document_collected completes an objective,
## a second document_collected emission does not trigger a second completion.
## Verifies the disconnect-before-complete pattern in _on_document_collected_for_objective.
func test_objective_state_machine_disconnects_signal_after_completion() -> void:
	# Arrange — start mission with a single required objective.
	var svc: _TestServiceWithInjectedMission = _make_svc(_make_single_objective_mission())
	svc._on_section_entered(&"plaza", LevelStreamingService.TransitionReason.NEW_GAME)

	# Act — first document_collected (completes the objective + disconnects).
	Events.document_collected.emit(&"first_doc")

	var completed_count_after_first: int = _objective_completed_count
	assert_int(completed_count_after_first).override_failure_message(
		"One-shot pre-condition: objective_completed must have fired once."
	).is_equal(1)

	# Assert — _document_collected_connected flag reset to false.
	assert_bool(svc._document_collected_connected).override_failure_message(
		"After objective completes, _document_collected_connected must be false."
	).is_false()

	# Act — second document_collected (service is disconnected; should be ignored).
	Events.document_collected.emit(&"second_doc")

	# Assert — no additional objective_completed emission.
	assert_int(_objective_completed_count).override_failure_message(
		"Second document_collected must not trigger a second objective_completed (one-shot)."
	).is_equal(completed_count_after_first)
