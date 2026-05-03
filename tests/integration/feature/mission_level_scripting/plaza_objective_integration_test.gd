# tests/integration/feature/mission_level_scripting/plaza_objective_integration_test.gd
#
# PlazaObjectiveIntegrationTest — GdUnit4 integration test for Story MLS-005.
# Verifies the full Plaza VS mission loop: NEW_GAME → mission_started →
# objective_started → document_collected → objective_completed → mission_completed.

class_name PlazaObjectiveIntegrationTest
extends GdUnitTestSuite


# ── Doubles ───────────────────────────────────────────────────────────────────

class _TestServiceWithInjectedMission extends MissionLevelScriptingService:
	var _injected_resource: MissionResource = null
	func _load_mission_resource(_mission_id: StringName) -> MissionResource:
		return _injected_resource


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_plaza_mission() -> MissionResource:
	var obj: MissionObjective = MissionObjective.new()
	obj.objective_id = &"recover_plaza_document"
	obj.completion_signal = &"document_collected"
	obj.required_for_completion = true
	obj.prereq_objective_ids = []
	var mission: MissionResource = MissionResource.new()
	mission.mission_id = &"eiffel_tower"
	mission.objectives = [obj]
	return mission


# ── Tests ──────────────────────────────────────────────────────────────────────

## AC-MLS-9.1 + AC-MLS-9.4: full Plaza mission loop end-to-end.
## NEW_GAME → mission_started → objective_started → document_collected →
## objective_completed → mission_completed.
func test_plaza_full_mission_loop_new_game_to_completed() -> void:
	# Arrange — service with injected Plaza mission.
	var svc: _TestServiceWithInjectedMission = _TestServiceWithInjectedMission.new()
	auto_free(svc)
	svc._injected_resource = _make_plaza_mission()

	var mission_started_log: Array[StringName] = []
	var objective_started_log: Array[StringName] = []
	var objective_completed_log: Array[StringName] = []
	var mission_completed_log: Array[StringName] = []

	var ms_handler: Callable = func(mid: StringName) -> void: mission_started_log.append(mid)
	var os_handler: Callable = func(oid: StringName) -> void: objective_started_log.append(oid)
	var oc_handler: Callable = func(oid: StringName) -> void: objective_completed_log.append(oid)
	var mc_handler: Callable = func(mid: StringName) -> void: mission_completed_log.append(mid)

	Events.mission_started.connect(ms_handler)
	Events.objective_started.connect(os_handler)
	Events.objective_completed.connect(oc_handler)
	Events.mission_completed.connect(mc_handler)

	# Act 1 — NEW_GAME triggers mission lifecycle.
	svc._on_section_entered(&"plaza", LevelStreamingService.TransitionReason.NEW_GAME)

	# Assert phase 1 — mission and objective started.
	assert_int(mission_started_log.size()).override_failure_message(
		"AC-MLS-9.1: mission_started must fire exactly once on NEW_GAME"
	).is_equal(1)
	assert_str(String(mission_started_log[0])).is_equal("eiffel_tower")
	assert_int(objective_started_log.size()).override_failure_message(
		"AC-MLS-9.1: objective_started must fire on NEW_GAME for prereq-empty objectives"
	).is_equal(1)
	assert_str(String(objective_started_log[0])).is_equal("recover_plaza_document")

	# Act 2 — fire document_collected to trigger objective completion.
	Events.document_collected.emit(&"plaza_document")

	# Assert phase 2 — objective and mission completed.
	assert_int(objective_completed_log.size()).override_failure_message(
		"AC-MLS-9.1/9.4: objective_completed must fire on document_collected"
	).is_equal(1)
	assert_str(String(objective_completed_log[0])).is_equal("recover_plaza_document")
	assert_int(mission_completed_log.size()).override_failure_message(
		"AC-MLS-9.1: mission_completed must fire after all required objectives complete"
	).is_equal(1)
	assert_str(String(mission_completed_log[0])).is_equal("eiffel_tower")

	# Cleanup — disconnect handlers.
	if Events.mission_started.is_connected(ms_handler):
		Events.mission_started.disconnect(ms_handler)
	if Events.objective_started.is_connected(os_handler):
		Events.objective_started.disconnect(os_handler)
	if Events.objective_completed.is_connected(oc_handler):
		Events.objective_completed.disconnect(oc_handler)
	if Events.mission_completed.is_connected(mc_handler):
		Events.mission_completed.disconnect(mc_handler)


## AC-MLS-9.3: emits proceed silently when no subscribers connected.
func test_plaza_mission_emits_silently_with_no_subscribers() -> void:
	var svc: _TestServiceWithInjectedMission = _TestServiceWithInjectedMission.new()
	auto_free(svc)
	svc._injected_resource = _make_plaza_mission()

	# No subscribers connected. Should not crash.
	svc._on_section_entered(&"plaza", LevelStreamingService.TransitionReason.NEW_GAME)
	Events.document_collected.emit(&"plaza_document")

	# State should still be COMPLETED.
	assert_int(svc._phase).is_equal(MissionLevelScriptingService.MissionPhase.COMPLETED)


## AC-MLS-9.2: in-engine grep — no direct HUD/Audio/Cutscene/Dialogue refs in MLS source.
func test_mls_no_direct_external_system_references() -> void:
	var src: String = FileAccess.get_file_as_string(
		"res://src/gameplay/mission_level_scripting/mission_level_scripting.gd"
	)
	# Strip comments before grepping.
	var stripped: String = ""
	for line in src.split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("##") or trimmed.begins_with("#"):
			continue
		stripped += line + "\n"
	# Forbidden substrings: HUDCore, AudioManager (direct call, not subscriber), CutsceneSystem, DialogueSystem.
	var forbidden: Array[String] = ["HUDCore", "CutsceneSystem", "DialogueSystem", "HUDState"]
	for pattern in forbidden:
		assert_int(stripped.find(pattern)).override_failure_message(
			"AC-MLS-9.2: forbidden direct reference '%s' found in MLS source" % pattern
		).is_equal(-1)


## AC-MLS-4.2: FP-5 grep — no body_exited subscriptions in src/gameplay/mission_level_scripting.
func test_mls_no_body_exited_subscriptions() -> void:
	var src: String = FileAccess.get_file_as_string(
		"res://src/gameplay/mission_level_scripting/mission_level_scripting.gd"
	)
	# body_exited is FORBIDDEN per CR-6 (Jolt 4.6 non-determinism on mid-overlap despawn).
	# Ignore comment-only mentions.
	var stripped: String = ""
	for line in src.split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("##") or trimmed.begins_with("#"):
			continue
		stripped += line + "\n"
	assert_int(stripped.find("body_exited")).override_failure_message(
		"AC-MLS-4.2 (FP-5): body_exited subscription found in MLS source — forbidden per CR-6"
	).is_equal(-1)
